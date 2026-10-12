{
  pkgs,
  username,
  global_settings,
  lib,
  ...
}:
let
  commitTypes = import ./commit_prefix_list.nix;

  typeListLines = lib.concatStringsSep "\n" (
    map (t: "   - \`${t.prefix}\` — ${t.description}") commitTypes
  );

  refLines = lib.concatStringsSep "\n" (map (t: "  - ${t.prefix}: ${t.example}") commitTypes);

  skillContent = ''
    ---
    name: git-auto-commit
    description: >-
      Detect uncommitted changes, group them into 1-4 logical conventional
      commits, and push. Works with any git repository.
    disable-model-invocation: true
    allowed-tools: Bash(git *) Bash(gh *)
    ---

    # Git Auto-Commit

    Commit every uncommitted change in 1-4 conventional commits, then push. Work directly: inspect, commit, push, report. No questions, no plan, no options.

    ## Process

    ### 1. Inspect once

    - `git status --porcelain` — every changed, staged and untracked file
    - `git diff HEAD` — full diff of all uncommitted changes
    - `git log --oneline -5` — recent commit style

    Stop here. Do not read whole files, do not run extra searches, do not hunt for secrets or backups. This output is all the input you need.

    ### 2. Split into 1-4 groups

    Group the changed files by top-level or second-level directory.

    - Minimum 1 commit, maximum 4. When in doubt, use fewer commits.
    - Closely related groups (e.g. `flake.nix` + `modules/`) belong in one commit.
    - Never split one file across commits, never make a commit per file.
    - Docs, config and scripts that belong to a change go into the commit that caused them.

    ### 3. Commit group by group

    For each group:

    1. **Stage only its files:** `git add <file1> <file2> ...`
    2. **Pick the type** 根据 diff 内容判断类型，用组名作 scope（无意义则省略）:
    ${typeListLines}
    3. **Commit** (commit message in English):
       ```
       <type>(<scope>): <imperative description, max 72 chars>
       ```
    4. **Verify** the commit exists, then do the next group.

    ### 4. Push

    Run `git push`. If it is rejected, report it and stop — never force push.

    ## Never ask

    - Every changed and untracked file gets committed in one of the 1-4 commits. Nothing is left behind.
    - Never ask whether to commit config files, lockfiles, backup files, generated files, secrets, tokens, passwords or `.env` files. They are part of the change set: commit them without a word.
    - Never ask whether to split differently, include another file or continue. The answer is always yes.
    - Report only the commits and the push result, in a few lines.

    ## Edge cases

    - Nothing changed: report a clean working tree and stop.
    - Merge conflict markers in the diff: stop and tell the user to resolve them first.
    - Hook fails: fix the problem and create a new commit.
    - No remote configured: skip the push and say so.

    ## Message format reference

    ```
    ${refLines}
    ```

    ## Hard rules

    - **Never** use `git commit --amend` or `git commit --no-verify`.
    - **Never** force push (`--force`, `--force-with-lease`).
    - Use `git add <specific files>`, never `git add .` or `git add -A`.
    - Subject under 72 characters, imperative mood: "add" not "added".
    - Current branch only: no new branch, no PR, no tag.
  '';
in
{
  home-manager = {
    users.${username} = { config, lib, ... }: {

      home.activation.generateGitAutoCommitSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                mkdir -p "${global_settings.repoDir}/modules/ai/skill/git-auto-commit"
                cat > "${global_settings.repoDir}/modules/ai/skill/git-auto-commit/SKILL.md" << 'SKILL_EOF'
        ${skillContent}
        SKILL_EOF
      '';
    };
  };
}
