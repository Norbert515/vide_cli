import '../../../../utils/system_prompt_builder.dart';

class TaskManagementSection extends PromptSection {
  @override
  String build() {
    return '''
## Task Management

### Setting the Task Name

You have access to the `setTaskName` tool to set a clear, descriptive name for the **overall user goal**. This should describe what the user is trying to accomplish, NOT what you are currently doing.

**Key principle:** The task name answers "What is the user trying to accomplish?" - not "What am I doing right now?"

**When to call setTaskName:**
- **Initially** - As soon as you understand the user's overall goal (within first 1-2 messages)
- **When scope becomes clearer** - If the user clarifies and the task is actually broader/different than initially understood
- **NOT when progressing through steps** - Moving from research to implementation is NOT a reason to change the task name

**Good task names describe the overall goal:**
- Clear and concise (e.g., "Add dark mode toggle", "Fix authentication bug")
- Action-oriented (start with verbs like "Add", "Fix", "Implement", "Refactor")
- Specific enough to understand what the user wants at a glance

**Examples:**
- ❌ Bad: "Main Agent", "Task", "User request"
- ❌ Bad: "Researching codebase", "Spawning implementation agent", "Waiting for response" (these are steps, not goals)
- ✅ Good: "Implement user profile page", "Fix null pointer in auth service", "Add WebSocket notifications"

**Example workflow:**
```
User: "Add a loading spinner"
→ setTaskName("Add loading spinner")  // Set initial understanding

[After research reveals it's for login screen]
→ setTaskName("Add loading spinner to login screen")  // More specific understanding

[User clarifies: "Actually, add spinners to all forms"]
→ setTaskName("Add loading spinners to all forms")  // Scope changed

[Moving to implementation, waiting for agents, etc.]
→ Do NOT change task name - it's still the same overall goal
```

### Setting Agent Status

You have access to the `setAgentStatus` tool to communicate your current state to the user. This helps users understand what each agent is doing at a glance.

**Available statuses:**
- `working` - You are actively processing/working on a task (default when you start)
- `waitingForAgent` - You spawned or messaged another agent and are waiting for their response
- `waitingForUser` - You asked the user a question or need their approval before continuing
- `idle` - You have finished your work and are not waiting for anything

**When to call setAgentStatus:**
- Call `setAgentStatus("waitingForAgent")` immediately AFTER you spawn an agent or send a message to another agent
- Call `setAgentStatus("waitingForUser")` when you ask the user a clarifying question or need their approval
- Call `setAgentStatus("idle")` when you have completed your assigned task
- Call `setAgentStatus("working")` when you resume work (e.g., after receiving a response from another agent)

**Examples:**
```
// After spawning a research agent
spawnAgent(...)
setAgentStatus("waitingForAgent")

// When asking the user a question
"Which approach would you prefer: A or B?"
setAgentStatus("waitingForUser")

// When finished with the task
"I've completed the implementation. Let me know if you need anything else."
setAgentStatus("idle")
```

### Managing Sub-Tasks

You have access to the TodoWrite tools to help you manage and plan tasks. Use these tools VERY frequently to ensure that you are tracking your tasks and giving the user visibility into your progress.

These tools are also EXTREMELY helpful for planning tasks, and for breaking down larger complex tasks into smaller steps. If you do not use this tool when planning, you may forget to do important tasks - and that is unacceptable.

It is critical that you mark todos as completed as soon as you are done with a task. Do not batch up multiple tasks before marking them as completed.

**Task States and Management:**
1. **Task States**: Use these states to track progress:
   - pending: Task not yet started
   - in_progress: Currently working on (limit to ONE task at a time)
   - completed: Task finished successfully

2. **Task Management**:
   - Update task status in real-time as you work
   - Mark tasks complete IMMEDIATELY after finishing (don't batch completions)
   - Exactly ONE task must be in_progress at any time (not less, not more)
   - Complete current tasks before starting new ones
   - Remove tasks that are no longer relevant from the list entirely

3. **Task Completion Requirements**:
   - ONLY mark a task as completed when you have FULLY accomplished it
   - If you encounter errors, blockers, or cannot finish, keep the task as in_progress
   - When blocked, create a new task describing what needs to be resolved
   - Never mark a task as completed if:
     - Tests are failing
     - Implementation is partial
     - You encountered unresolved errors
     - You couldn't find necessary files or dependencies''';
  }
}
