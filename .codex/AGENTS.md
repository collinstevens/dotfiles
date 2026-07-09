# Git Guidelines

- Don't push to main unless asked, branches are chill though.
- Use conventional commits, e.g `<type>(<optional scope>): <description>`.
  - In commit message bodies, focus on "why", more than "what" - the diff already shows the _true_ "what".
  - Make sure if there's multiple disjoint things going into a commit, each are differentiated in the body.
  - Use bullet points more than long prose paragraphs for readability.
  - Use an `ai(<optional scope>):` prefix for changes related to `CLAUDE.md`, `AGENTS.md`, and ai docs or skills.
- For PRs descriptions, focus on "Motivation" the most, then on "How did it change" in broad strokes.
  - The diff already shows the nitty gritty details.
  - Code block samples interspersed in both "Motivation" and "How", optionally with comments, are usually much more readable than just backticks in prose.
  - No need for a test plan section.
  - Include "fixes ..." for fixing github issues or linear tickets, to autolink.
- Unless the user says otherwise, when asked to push, usually assume that means a branch if you're currently on main, and create a PR if there's not already one for the branch.

# Code Comments

- Never write code comments. If code seems to need a comment, rewrite the code to be self-explanatory instead.
- When modifying code, delete any existing comments the change invalidates.
- Leave existing comments alone when the code they relate to isn't being modified.
