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
