import {newStatus} from "../common/status.js";
import {csvAssistant} from "./csv.js";
import {ModelID, Models} from "../models/models.js";
import {getLogger} from "../common/logging.js";

const logger = getLogger("assistants");


const defaultAssistant = {
    name: "default",
    displayName: "Amplify Assistant",
    handlesDataSources: (ds) => {
        return true;
    },
    handlesModel: (model) => {
        return true;
    },
    description: "Default assistant that can handle arbitrary requests with any data type but may " +
        "not be as good as a specialized assistant.",
    handler: async (llm, params, body, dataSources, responseStream) => {
        return llm.prompt(body, dataSources);
    }
};

export const defaultAssistants = [
    defaultAssistant,
    csvAssistant,
];

export const buildDataSourceDescriptionMessages = (dataSources) => {
    if (!dataSources || dataSources.length === 0) {
        return "";
    }

    const descriptions = dataSources.map((ds) => {
        return `${ds.id}: (${ds.type})`;
    }).join("\n");

    return `
    The following data sources are available for the task:
    ---------------
    ${descriptions}
    --------------- 
    `;
}

export const buildAssistantDescriptionMessages = (assistants) => {
    if (!assistants || assistants.length === 0) {
        return [];
    }

    const descriptions = assistants.map((assistant) => {
        return `name: ${assistant.name} - ${assistant.description}`;
    }).join("\n");

    return `
    The following assistants are available to work on the task:
    ---------------
    ${descriptions}
    --------------- 
    `;
}

export const chooseAssistantForRequestWithLLM = async (llm, body, dataSources, assistants = defaultAssistants) => {

    const messages = [
        {
            "role": "system",
            "content": `
            Help the user choose the best assistant for the task.
            You only need to output the name of the assistant. YOU MUST
            honor the user's choice if they request a specific assistant.
            `
        },
        {
            "role": "user",
            "content": `
            Think step by step how to perform the task. What are the steps? 
            Which assistant is the best fit to solve the given task based on the
            steps? Is the user asking for a specific assistant?
            
            If you are not sure, please choose the default assistant.
            
            ${buildAssistantDescriptionMessages(assistants)}
            ${buildDataSourceDescriptionMessages(dataSources)}
            
            Please choose the best assistant to help with the task:
            ---------------
            ${body.messages.slice(-1)[0].content}
            ---------------
            `
        },

    ];

    const model =
        //Models[ModelID.GPT_3_5_AZ];
        Models["gpt-4-1106-Preview"];

    const names = assistants.map((a) => a.name);

    return await llm.promptForChoice({messages, options:{model}}, names, []);
}

export const getAvailableAssistantsForDataSources = (model, dataSources, assistants = defaultAssistants) => {

    if (!dataSources || dataSources.length === 0) {
        return [defaultAssistant];
    }

    return assistants.filter((assistant) => {
        return assistant.handlesDataSources(dataSources) && assistant.handlesModel(model);
    });
}

export const chooseAssistantForRequest = async (llm, model, body, dataSources, assistants = defaultAssistants) => {

    let selected = defaultAssistant;


    const status = newStatus({inProgress: true, message: "Choosing an assistant to help"});
    llm.sendStatus(status);
    llm.forceFlush();

    // Hack to make AWS lambda send the status update and not buffer
    const availableAssistants = getAvailableAssistantsForDataSources(model, dataSources, assistants);

    const start = new Date().getTime();
    const selectedAssistantName = (availableAssistants.length > 1) ?
        await chooseAssistantForRequestWithLLM(llm, body, dataSources,
            availableAssistants) : availableAssistants[0].name;
    const timeToChoose = new Date().getTime() - start;
    logger.info(`Selected assistant ${selectedAssistantName}`);
    logger.info(`Time to choose assistant: ${timeToChoose}ms`);

    const selectedAssistant = assistants.find((a) => a.name === selectedAssistantName);
    selected = selectedAssistant || defaultAssistant;

    status.inProgress = false;
    llm.sendStatus(status);

    llm.sendStatus(newStatus(
        {
            inProgress: false,
            message: "The \"" + selected.displayName + "\" is responding.",
            icon: "assistant",
            sticky: true
        }));

    return selected;
}