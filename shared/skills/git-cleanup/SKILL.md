---
name: git-cleanup
description: Clean up a local git workspace after heavy agent use by updating the default branch, removing finished worktrees, and deleting merged, backup, and temporary branches.
disable-model-invocation: true
---

Clean up this repository's local workspace. Agents leave behind worktrees, backup branches, temporary branches, and branches whose work already landed in the default branch. Remove what is finished, keep anything that still holds unique work, and bring the default branch up to date.

Treat any arguments as extra constraints. `dry-run` means report the plan and change nothing. Other arguments might name a base branch, a remote, or branches to keep.

## Ground rules

- Never lose unique work without explicit approval. A branch or worktree is safe to remove only when every change it holds is already in the default branch, or when the user approves its removal after seeing what it holds.
- Never discard uncommitted changes, untracked files, or stashes. Never run `git worktree remove --force`, `git reset --hard`, `git clean`, or `git stash drop` without the user's explicit approval for that specific target.
- Never touch the default branch, the current branch, or the worktree this session runs in.
- Never delete remote branches. This cleanup is local only. `git fetch --prune` removing stale remote-tracking refs is fine.
- Run `gh` outside the sandbox on Windows. When the repo has an `upstream` remote, pass `--repo <owner>/<repo>` for the remote that the default branch tracks.

## 1. Survey

Gather the state before changing anything:

```sh
git fetch --all --prune
git worktree list --porcelain
git for-each-ref refs/heads --format='%(refname:short) %(objectname:short) %(upstream:short) %(upstream:track) %(committerdate:relative)'
git stash list
```

Determine the default branch from `git symbolic-ref --short refs/remotes/origin/HEAD`. If that ref is missing, run `git remote set-head origin --auto` and retry, or ask `gh repo view --json defaultBranchRef`. Use the remote branch that the local default branch tracks, `<default>@{upstream}`, as the comparison target `<base>`. Fall back to the local default branch when it has no upstream.

## 2. Update the default branch

Fast-forward only:

- If the default branch is checked out in a clean worktree, run `git -C <that-worktree> merge --ff-only <base>`.
- If it is not checked out anywhere, run `git fetch <remote> <default>:<default>`.
- If it is checked out in a dirty worktree, or the local branch has diverged from `<base>`, leave it alone and report it. A diverged default branch often means the remote was force-pushed. Show the local-only commits with `git log --oneline <base>..<default>` and ask before resetting it. If the user approves a reset, create a recovery ref such as `backup/<default>-<date>` first, then delete that ref once it has been confirmed redundant.

Use `<base>` for every comparison below, so a stale local default branch never makes merged work look unmerged.

## 3. Classify every local branch

For each branch other than the default and current branch, decide whether its work has landed. Check in this order and stop at the first match:

1. **Ancestor.** `git merge-base --is-ancestor <branch> <base>` succeeds. This covers merge commits and fast-forwards.
2. **Content already present.** Merging the branch into `<base>` would change nothing. This covers squash merges, rebase merges, cherry-picks, and backup branches whose content was later merged in rewritten form:

   ```sh
   git merge-tree --write-tree <base> <branch>
   git rev-parse <base>^{tree}
   ```

   The branch has landed when `merge-tree` exits 0 and the first line of its output equals the tree of `<base>`.
3. **Merged pull request.** `gh pr list --state merged --head <branch> --json number,headRefOid,mergedAt` returns a PR, and the local tip is that PR's `headRefOid` or an ancestor of it. Commits added locally after the merge mean the branch still holds unique work.

Everything that matches is **landed**. Everything else is **unlanded**. For each unlanded branch, record:

- whether it is checked out in a worktree
- its upstream state: tracking a live remote branch, `[gone]`, or never pushed
- any open PR: `gh pr list --state open --head <branch>`
- the commits it holds beyond `<base>`: `git log --oneline <base>..<branch>`
- its last commit date
- whether its name looks like backup or scratch work, such as `backup/*`, `*-backup*`, `*-bak`, `tmp/*`, `temp/*`, `wip*`, `*-old`, `pre-rebase*`, or agent prefixes like `claude/*`, `codex/*`, and `worktree-*`

For a backup branch, also find the branch it backs up and check whether that branch, or `<base>`, contains equivalent changes. `git range-diff <base>...<backup> <base>...<original>` or `git diff <original> <backup>` shows how the two differ.

## 4. Classify every linked worktree

Skip the main worktree and the worktree this session runs in. For each other worktree, record:

- its path, branch or detached commit, and whether it is locked
- whether it is clean: `git -C <path> status --porcelain --untracked-files=all` prints nothing
- whether its branch, or its detached commit, has landed under the rules in step 3
- whether its directory still exists; a missing directory means `git worktree prune` can drop it

A worktree is **finished** when it is clean, unlocked, and its branch or commit has landed. Agent worktrees usually live under `.claude/worktrees/`, `.codex/worktrees/`, or `.grok/worktrees/`. Also list directories under those paths that `git worktree list` does not know about. They are leftovers from a removal that failed partway through.

## 5. Present the plan

Show a compact plan before making changes, grouped as:

- **Remove automatically:** finished worktrees, landed branches, and stale worktree registrations. Give each branch its tip SHA and the rule that matched it.
- **Needs a decision:** unlanded branches with no open PR, dirty or locked worktrees, worktrees on unlanded branches, leftover directories, and a diverged default branch. Give each one the evidence from steps 3 and 4 and a recommendation. Backup and scratch branches whose originals landed are usually safe to delete; say so when the evidence supports it.
- **Keeping:** branches with open PRs, branches tracking a live remote branch with unpushed or unmerged commits, and anything the arguments said to keep.
- **Report only:** stashes, with their age and the branch they came from.

Ask about the "Needs a decision" items in one batch. Group similar items so the user can approve them together. For a `dry-run`, stop after presenting the plan.

## 6. Apply

Carry out the automatic removals and the approved decisions in this order:

1. `git worktree prune`
2. `git worktree remove <path>` for each finished or approved worktree. On Windows, removal can fail because a process holds files open. Report the failure and move on instead of forcing it.
3. `git branch -d <branch>` for ancestor branches. Use `git branch -D <branch>` for branches that landed by content or PR and for approved unlanded branches. `-D` is required there because git only checks ancestry.
4. Delete approved leftover directories only after confirming that no registered worktree uses them.

## 7. Report

Finish with:

- the default branch's old and new SHA
- every removed worktree path
- every deleted branch with its tip SHA, plus how to restore it: `git branch <name> <sha>`
- everything kept or skipped, and why
- anything that failed

Deleting a branch also deletes its reflog. The SHAs in the report are the recovery path.
