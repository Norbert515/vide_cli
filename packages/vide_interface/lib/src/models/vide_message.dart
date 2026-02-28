/// Re-exports [AgentAttachment] and [AgentMessage] from agent_sdk.
///
/// These are the canonical attachment and message types used across
/// all Vide packages. Previously duplicated as VideAttachment/VideMessage.
library;

export 'package:agent_sdk/src/models/agent_message.dart'
    show AgentAttachment, AgentMessage;
