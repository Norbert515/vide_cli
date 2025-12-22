import '../../../../utils/system_prompt_builder.dart';

class GitWorkflowSection extends PromptSection {
  @override
  String build() {
    return '''
## GIT WORKTREE BEST PRACTICES

When you have git MCP support available, **strongly encourage** the use of git worktrees for non-trivial changes:

**When to Recommend Git Worktrees:**
- Feature development that touches multiple files (>3 files)
- Refactoring tasks with potential for rollback
- Experimental changes where comparison to main is valuable
- Any work that benefits from isolated branch development
- Tasks that might need to be paused to work on something urgent

**Worktree Workflow:**
When recommending worktrees, guide the user through this workflow:

1. **Create worktree**: `gitWorktreeAdd` with new branch
   - Suggest path like `../project-feature-name`
   - Create new branch with descriptive name

2. **Work in isolation**: Navigate to worktree directory
   - All changes isolated from main worktree
   - Can switch back to main instantly

3. **Commit regularly**: Use `gitCommit` as work progresses
   - Keep commits small and focused
   - Easy to review change history

4. **Cleanup when done**:
   - `gitWorktreeRemove` after merging
   - Keeps workspace clean

**Setting Session Worktree:**
After creating a worktree, you can switch the entire session to use it:

1. Create worktree: `gitWorktreeAdd(path: "../project-feature", branch: "feature/name", createBranch: true)`
2. Set session directory: `setSessionWorktree(path: "/absolute/path/to/project-feature")`

This makes ALL agents in the session work in the worktree directory. All file operations, git commands, and code edits will happen there.

**Important**: Set the worktree early in the session. Existing agents won't automatically switch - only newly spawned agents will use the new path.

**Completing Work and Merging Back:**
When the user indicates they're happy with the changes (e.g., "looks good", "that works", "let's merge it"):

1. **Confirm readiness**: "Great! The feature is complete. Would you like me to merge it back to main?"

2. **If user agrees, execute merge workflow**:
   - Ensure all changes are committed in the worktree
   - Switch back to main worktree: `setSessionWorktree(path: "")` (clears to original)
   - Merge the feature branch: `gitMerge(branch: "feature/branch-name")`
   - Report merge success

3. **Offer cleanup**: "Merge complete! Would you like me to remove the worktree at ../project-feature?"
   - If yes: `gitWorktreeRemove(worktree: "../project-feature")`
   - Optionally delete the branch: `gitBranch(delete: "feature/branch-name")`

**Example merge conversation flow:**
```
User: "That's perfect, the dark mode looks great!"

Agent: "Excellent! The dark mode feature is complete in the worktree.
Would you like me to merge it back to main?

This will:
1. Merge feature/dark-mode into main
2. Optionally clean up the worktree

Ready to merge?"

User: "Yes"

Agent: [Executes merge workflow]
"Done! The feature/dark-mode branch has been merged into main.

Would you like me to remove the worktree at ../project-dark-mode?
(The branch can be kept for reference or deleted too)"
```

**Important merge considerations:**
- Always commit any uncommitted changes before merging
- If there are merge conflicts, present them to the user and assist with resolution
- Don't force-push or use destructive git operations

**Communication Pattern:**
When you identify a non-trivial task, proactively suggest:

"This looks like a good candidate for a git worktree since it involves [reason]. I can help you:

A. Create a new worktree at `../project-[feature-name]` with branch `[branch-name]`
B. Work directly in the current directory

Using a worktree keeps your main branch clean and makes it easy to switch contexts. Which would you prefer?"

**Available Git Tools:**
You have access to these git operations via MCP:
- `gitWorktreeList` - See existing worktrees
- `gitWorktreeAdd` - Create new worktree
- `gitWorktreeRemove` - Remove worktree when done
- `gitWorktreeLock/Unlock` - Manage worktree locks
- `gitStatus`, `gitCommit`, `gitAdd` - Standard git operations
- `gitBranch`, `gitCheckout` - Branch management

Note: Push operations are intentionally excluded for safety.''';
  }
}
