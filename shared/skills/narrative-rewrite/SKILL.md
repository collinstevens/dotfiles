---
name: narrative-rewrite
description: Rewrite the current branch's git history as a narrative of small, digestible commits that arrive at the same final tree.
disable-model-invocation: true
---

Rewrite this branch's history as a narrative. Produce the sequence of commits a careful engineer would have made if they had known the final design from the start.

Treat any arguments as extra constraints, such as a base branch or a target commit count.

## Scope

- Rewrite only the commits between the merge-base with the base branch and HEAD. Take the base branch from the open PR, or use the repo's default branch if there's no PR.
- The final tree must be identical to the current HEAD. Your job is to change how the code arrives, not what arrives. If you spot a bug, tell the user about it and leave it unfixed.

## What a good narrative looks like

- Each commit makes one logical change. A reviewer should understand each commit in a couple of minutes from its diff and message alone.
- Make the diffs themselves clean, compact, and easy to read. Prefer focused hunks with enough surrounding context to make the change obvious. Avoid massive, chunky diffs that bury the meaningful edits in unrelated churn.
- Review each proposed commit's actual diff before finalizing it. If a reviewer must untangle several ideas or scan a large wall of changes to see what happened, restructure the commit into smaller, coherent steps. A good message does not compensate for a confusing diff.
- Keep related edits together and avoid touching unrelated lines. Extract preparatory moves, renames, and formatting so behavioral diffs clearly show the behavior that changed. Use synthesized intermediate states when they make the progression easier to follow.
- Order commits by dependency: enabling refactors and contracts first, then the core feature, then wiring, configuration, and feature flags, then docs.
- Tests land in the same commit as the behavior they cover.
- Leave out fix-ups, reverts, "address feedback" commits, and back-and-forth. Fold every correction into the commit that introduces the code it corrects.
- Keep mechanical changes apart from behavioral ones. Renames, moves, and formatting get their own commits. Regenerated code gets its own commit when it builds without the change that prompted it. Lock files travel with the manifest change that requires them.
- You may synthesize intermediate states. A commit can contain code that never existed in the original history, as long as it's a coherent step toward the final tree.
- Intermediate commits may fail builds or tests. Build and test the final state; it must build and pass tests.
- Small means digestible, not atomized. Don't split a change so finely that a commit means nothing on its own.
