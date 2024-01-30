from common.validate import validated
from common.llm import get_chat_llm
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
import os
import logging

import assistants.db.mysql_db as mysql_db
import assistants.db.local_db as local_db

# Logging configuration
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

"""
Make sure that the following environment variables are set:
DB_MODE= local or mysql
DEFAULT_MODEL="gpt-35-turbo"
LLM_ENDPOINTS_SECRETS_NAME= the name of the AWS secrets manager secret with a list of endpoints / keys

# If using the mysql database, set the following environment variables:
MYSQL_DB_HOST=
MYSQL_DB_USERNAME=
MYSQL_DB_NAME=
MYSQL_DB_PASSWORD=

# If using the local database, set the following environment variables:
LOCAL_DB_DIRECTORY=
"""

# Set the DB_MODE environment variable to "local" or "mysql" to choose the database mode
db_mode = os.environ.get("DB_MODE", "local")


# @validate will check the incoming JWT, determine the current user, and
# make sure that the incoming request body has the format {data:{task:"what to do"}}
@validated(op="execute_sql")
def execute_sql_query(event, context, current_user, name, data):
    """
    This is entry point to the lambda function.

    Execute an SQL query based on the user's prompt and the database schema.

    :param event: AWS lambda event
    :param context: AWS lambda context
    :param current_user: string name of the current user as obtained from JWT token
    :param name: name of the operation to be performed, execute_sql
    :param data: data passed by the client in the foramt {data:{...}}
    :return:
    """
    data = data['data']
    model = data.get("model",None)
    user_prompt = data.get("task")
    return query_db(model, current_user, user_prompt)


def get_connection():
    """
    Get a connection to the database.
    db_mode: The mode of the database. Either "local" or "mysql". This is
    determined by the DB_MODE environment variable.

    :return: A connection to the database.
    """
    if db_mode == "local":
        return local_db.get_connection()
    elif db_mode == "mysql":
        return mysql_db.get_connection()
    else:
        raise ValueError(f"Invalid DB_MODE: {db_mode}")


def query_db(model, current_user, user_prompt):
    """
    Use the LLM to come up with a plan to perform the task indicated by the
    user_prompt, and then execute the plan on the database.

    :param current_user: the name of the current user
    :param user_prompt: the task to be performed
    :return:
    """
    print(f"current_user: {current_user}")

    max_retries = 3
    try:

        print(f"User Prompt: {user_prompt}")

        with get_connection() as db_connection:
            schema_info = db_connection.fetch_schema_info()

            for attempt in range(max_retries):
                try:
                    print(f"Attempt {attempt + 1} of {max_retries} to generate SQL query.")
                    sql_query = generate_sql_query(model, user_prompt, schema_info, current_user)
                    print(f"Generated SQL query: {sql_query}")

                    cleaned_sql_query = clean_sql_query(sql_query)
                    print(f"Cleaned SQL query: {cleaned_sql_query}")

                    result = db_connection.execute_query(cleaned_sql_query)
                    print(f"The result had {len(result)} rows.")

                    return {"result": result}
                except Exception as e:
                    logging.error(f"Attempt {attempt + 1} failed: {e}")
                    if attempt == max_retries - 1:
                        raise e  # Reraise the last exception after all retries have failed

        return {"result": result}

    except Exception as e:
        logging.error(f"Error executing query. Exception: {e}")
        return {"result": "Error generating and executing query."}


def generate_sql_query(model, user_prompt, schema_info, current_user):
    """
    Generate a SQL query based on a user-provided prompt and a given database schema information,
    tailored for the current user.

    This function utilizes a Language Learning Model (LLM) to translate the natural language user
    prompt into a SQL query that is consistent with the provided schema. The function processes
    the schema information to remove any characters that could cause errors in the LLM and provides
    context that assists the LLM in generating the query.

    :param user_prompt: A string representing the user's request in natural language. The user prompt
    is what the user wants to query from the database.
    :param schema_info: A dictionary containing the database schema information. The schema details the
    structure of the database, including table names and column information.
    :param current_user: An object representing the current user. This object could contain user-specific
    preferences or authorization details that may influence query generation.

    :return: A string containing the SQL query generated by the LLM in response to the user's prompt, or
    an error message if query generation fails.

    The function may raise an exception if any part of the process fails, including errors during LLM
    interaction or issues with forming the prompt.
    """
    try:
        # Use LLM to generate SQL query based on user prompt and schema information
        # Check if model is not None or use the os.environ.get("DEFAULT_MODEL", "gpt-3.5-turbo")
        model = model if model else os.environ.get("DEFAULT_MODEL", "gpt-35-turbo")
        print(f"Using model: {model}")
        llm = get_chat_llm(model)

        # Braces cause the input to the LLM to return an error, remove braces from schema_info
        clean_schema_info = (
            str(schema_info)
            .replace("[", "")
            .replace("]", "")
            .replace("{", "")
            .replace("}", "")
        )

        # if needed, add example rows from each table
        formatted_prompt = f"Given the database schema:\n\n{clean_schema_info}\n\nGenerate a SQL query for:\n\n{user_prompt}"

        prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    "You are an AI skilled in SQL. Generate a query based on the given schema and user request. Provide all SQL queries in markdown.",
                ),
                ("user", formatted_prompt),
            ]
        )

        output_parser = StrOutputParser()

        # Chain the components together
        chain = prompt | llm | output_parser

        # Log the prompt
        # logging.info(f"Sending prompt to LLM:\n{formatted_prompt}")

        # Invoke the chain with an empty input since the prompt already contains all necessary information
        return chain.invoke({"input": ""})

    except Exception as e:
        logging.error(f"Error in generate_sql_query: {e}")
        raise


def clean_sql_query(sql_query):
    """
    Clean the SQL query generated by the LLM, which may have surrounding explanation, by extracting
    the query from the '```sql' and '```' tags and removing any leading or trailing whitespace.
    :param sql_query: The SQL query to be cleaned.
    :return: The cleaned SQL query.
    """

    # Step 1: Extract text after '```sql'
    start_index = sql_query.find("```sql")
    if start_index == -1:
        raise ValueError("The string '```sql' was not found in sql_query.")
    else:
        # Move past the '```sql'
        start_index += len("```sql")

        # Update sql_query to the substring after '```sql'
        sql_query = sql_query[start_index:]

    # Step 2: Extract text before the next '```'
    end_index = sql_query.find("```")
    if end_index == -1:
        raise ValueError("The closing '```' was not found in sql_query.")
    else:
        # Update sql_query to the substring before '```'
        sql_query = sql_query[:end_index]

    # logging.info(f"Cleaned SQL Query:\n{sql_query}")

    # Final cleaned SQL query
    return sql_query.strip()