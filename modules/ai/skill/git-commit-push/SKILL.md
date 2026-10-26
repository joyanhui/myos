---
name: git-commit-push
description: 按功能整理当前仓库的未提交改动，生成不超过 4 个英文 Git commit 并推送。
disable-model-invocation: true
---

# Git 提交并推送

将当前仓库中本次要提交的改动按功能拆分为 commit，并推送到当前分支。

- 先检查工作区状态、完整改动和近期提交记录。保留与任务无关的用户改动，不得覆盖或擅自提交。
- 按功能分组提交；同一功能合并为一个 commit。总数不超过 4 个。
- 提交信息使用英文，格式为 `<type>(<scope>): <description>`；scope 可省略。type 使用常见前缀，如 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`chore`、`build`、`ci`、`revert`。
- 每次只暂存该组明确相关的文件，不使用 `git add .` 或 `git add -A`。提交后确认结果。
- 全部完成后执行普通 `git push`。推送失败时停止并报告，不得强制推送。
- 不使用 `git commit --amend` 或 `--no-verify`。
- 无改动时报告工作区干净；无 remote 时说明未推送。
- 最后简要列出 commit 和推送结果。

## 安全边界

- 若改动包含冲突标记，停止并报告。
- 不得提交任务范围外的改动、覆盖用户更改或改写既有提交。
- 遇到提交钩子失败，报告失败原因；不得擅自绕过钩子。
