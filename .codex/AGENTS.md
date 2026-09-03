# Git Guidelines

- Don't push to main/master unless asked, branches are chill though.
- Unless the user says otherwise, when asked to push, usually assume that means a branch if you're currently on main/master, and create a PR if there's not already one for the branch.
- Use conventional commits https://www.conventionalcommits.org/en/v1.0.0
- For PR titles, the title should be a single conventional commit message assuming the commits on the branch will be squash committed
- For PR descriptions, focus on "Motivation" the most, then on "How did it change" in broad strokes.
  - The diff shows the details.
  - Code block samples interspersed in both "Motivation" and "How", optionally with comments, are usually much more readable than just backticks in prose.
  - No need for a test plan section.
  - Include "fixes ..." for fixing github issues or linear tickets, to autolink.

# GitHub CLI Authentication

- On Windows, run `gh` commands outside the sandbox from the first attempt because the sandbox cannot access credentials stored in the Windows keyring.
- Treat a sandboxed `gh auth status` failure as inconclusive. Before reporting expired authentication or asking the user to log in, rerun it with escalated sandbox permissions.
- Only ask the user to run `gh auth login` when `gh auth status` also fails outside the sandbox.

# Code Comments

- Never write code comments. If code seems to need a comment, rewrite the code to be self-explanatory instead.
- When modifying code, delete any existing comments the change invalidates.
- Leave existing comments alone when the code they relate to isn't being modified.

# Tests

- Never write or commit a new test unless the user explicitly asks for one.
- If a code change breaks an existing test, fix that existing test.
- Temporary tests are allowed to confirm behavior or validate an assumption, but remove them before committing so they are never left in the tree.
