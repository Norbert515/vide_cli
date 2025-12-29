# Vide Server

REST API server for Vide CLI, exposing agent network functionality via WebSocket streaming.

## Quick Start

### Start the Server

```bash
cd packages/vide_server
dart run bin/vide_server.dart
```

Note the port number from the server output (e.g., `http://127.0.0.1:63139`).

You can also specify a port:

```bash
dart run bin/vide_server.dart --port 8080
```

### Run the Example Client

In another terminal, use the port number from the server:

```bash
dart run example/client.dart --port 63139
```

Or use the short form `-p`:

```bash
dart run example/client.dart -p 63139
```

This starts an interactive REPL where you can have multi-turn conversations with the agent. Type `exit` or `quit` to end the session.

## API Endpoints

### Health Check

```
GET /health
```

Returns `OK` if the server is running.

### Create Network

```
POST /api/v1/networks
Content-Type: application/json

{
  "initialMessage": "Your prompt here",
  "workingDirectory": "/path/to/project"
}
```

Returns:

```json
{
  "networkId": "uuid",
  "mainAgentId": "uuid",
  "createdAt": "2024-01-01T12:00:00.000Z"
}
```

### Send Message to Agent

```
POST /api/v1/networks/{networkId}/messages
Content-Type: application/json

{
  "content": "Your message here"
}
```

Sends a message to the main agent in an existing network, continuing the conversation.

### Stream Agent Events (WebSocket)

```
ws://host:port/api/v1/networks/{networkId}/agents/{agentId}/stream
```

Streams JSON events in real-time as Claude processes the request.

**Event Types:**

- `connected` - WebSocket connection established
- `status` - Agent status update (e.g., "connected")
- `message` - Full user or assistant message (start of new message)
- `message_delta` - Streaming chunk of assistant message (only the new text)
- `tool_use` - Agent is using a tool
- `tool_result` - Tool execution result
- `done` - Turn complete
- `error` - Error occurred

**Streaming Behavior:**

Messages are streamed in real-time as Claude generates them:
1. `message` event with initial content when message starts
2. Multiple `message_delta` events with incremental chunks as text is generated
3. Client should append deltas to display streaming text effect

## How It Works

1. **Create a network** via `POST /api/v1/networks` - returns IDs immediately
2. **Connect to WebSocket** - this triggers the actual network creation (lazy initialization)
3. **Receive events** - all conversation events stream in real-time
4. **Send messages** - use `POST /api/v1/networks/{networkId}/messages` to continue the conversation
5. **Process responses** - handle messages, tool use, and completion events

Network creation is lazy - it happens when the WebSocket stream connects, ensuring no events are missed. Once the network is created, you can send multiple messages to continue the conversation across multiple turns.

## Example Output

```
╔════════════════════════════════════════════════════════════════╗
║              Vide Interactive REPL Client                      ║
╚════════════════════════════════════════════════════════════════╝

Server: http://127.0.0.1:63139
Working Directory: /Users/you/project

Type "exit" or "quit" to end the session.

→ Connecting to server...
✓ Connected to http://127.0.0.1:63139

→ Creating session...
✓ Session created
  Network ID: 584b6e68-6bc3-4656-995c-d01e669413a6
  Agent ID: ae6f24bd-f9a4-4c80-953d-2329d1385e4f

→ Connecting to WebSocket stream...

╔════════════════════════════════════════════════════════════════╗
║                    Interactive Session                         ║
╚════════════════════════════════════════════════════════════════╝

Session ready! Type your messages below:

You: What is 2+2?

[Main] Status: connected

┌─ User
│ What is 2+2?
└─

┌─ Assistant
│ 2+2 equals 4.
└─

✓ Turn complete

You: Can you write a hello world in Dart?

┌─ User
│ Can you write a hello world in Dart?
└─

┌─ Assistant
│ Here's a simple hello world program in Dart:
│
│ void main() {
│   print('Hello, World!');
│ }
└─

✓ Turn complete

You: exit

Ending session...

╔════════════════════════════════════════════════════════════════╗
║                    Session Complete                            ║
╚════════════════════════════════════════════════════════════════╝
```

## Running Tests

```bash
cd packages/vide_server
dart test
```

The integration tests start the server automatically and verify end-to-end functionality with Claude.

## Security

**WARNING:** This server has no authentication and is intended for localhost use only. Do NOT expose it to the internet.
