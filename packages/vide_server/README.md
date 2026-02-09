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

All JSON uses **kebab-case** for property names (e.g., `session-id`, `initial-message`).

### Health Check

```
GET /health
```

Returns `OK` if the server is running.

### Create Session

```
POST /api/v1/sessions
Content-Type: application/json

{
  "initial-message": "Your prompt here",
  "working-directory": "/path/to/project",
  "model": "sonnet",           // optional: "sonnet" (default), "opus", "haiku"
  "permission-mode": "ask"     // optional: "accept-edits" (default), "plan", "ask", "deny"
}
```

Returns:

```json
{
  "session-id": "uuid",
  "main-agent-id": "uuid",
  "created-at": "2024-01-01T12:00:00.000Z"
}
```

### Stream Session Events (WebSocket)

```
ws://host:port/api/v1/sessions/{session-id}/stream
```

Streams JSON events in real-time from **all agents** in the session (multiplexed).

**Server → Client Event Types:**

- `connected` - WebSocket connection established with session metadata
- `history` - All previous events (for reconnection/catch-up)
- `status` - Agent status update (working, waiting-for-agent, waiting-for-user, idle)
- `message` - Streaming message chunk with `is-partial` flag and `event-id`
- `tool-use` - Agent is invoking a tool
- `tool-result` - Tool execution completed
- `permission-request` - Tool needs user approval (when `permission-mode: "ask"`)
- `permission-timeout` - Permission request timed out (auto-denied)
- `agent-spawned` - New sub-agent created
- `agent-terminated` - Sub-agent finished and removed
- `aborted` - Confirms abort request was processed
- `done` - Agent turn complete
- `error` - Error occurred

**Client → Server Message Types:**

Send JSON messages to the WebSocket to interact:

```json
{"type": "user-message", "content": "Your message here", "model": "opus", "permission-mode": "ask"}
```

```json
{"type": "permission-response", "request-id": "uuid", "allow": true}
```

```json
{"type": "abort"}
```

**Streaming Behavior:**

Messages are streamed in real-time as Claude generates them:
1. `message` event with `is-partial: true` for each chunk
2. All chunks share the same `event-id` for correlation
3. Final `message` event has `is-partial: false`
4. Each event has a `seq` number for ordering/deduplication

## How It Works

1. **Create a session** via `POST /api/v1/sessions` - returns IDs immediately
2. **Connect to WebSocket** at `/api/v1/sessions/{session-id}/stream`
3. **Receive `connected` event** with session metadata
4. **Receive `history` event** with all previous events (if any)
5. **Send messages** via WebSocket `user-message` type
6. **Process responses** - handle messages, tool use, permissions, and completion events

Session creation is lazy - the agent network starts when the WebSocket connects, ensuring no events are missed. The WebSocket is bidirectional - send messages and receive events on the same connection.

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
  Session ID: 584b6e68-6bc3-4656-995c-d01e669413a6
  Main Agent ID: ae6f24bd-f9a4-4c80-953d-2329d1385e4f

→ Connecting to WebSocket stream...

╔════════════════════════════════════════════════════════════════╗
║                    Interactive Session                         ║
╚════════════════════════════════════════════════════════════════╝

Session ready! Type your messages below:

You: What is 2+2?

[Main] Status: working

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
