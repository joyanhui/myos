---
name: git-commit-push
description: 仅生成规范英文 commit message，提交全部改动并推送；禁止任何非 Git 检查。
disable-model-invocation: true
---

# Git 提交

本技能只做四件事：读取 Git 改动、生成 commit message、创建 commit、执行普通 `git push`。不要做其他工作。

## 操作白名单

只允许运行完成上述四件事必需的 Git 命令：`git status`、`git diff`、`git log`、`git branch`、`git remote`、`git add`、`git commit`、`git push`。不得运行其他命令或工具；不得把其他命令与 Git 命令串接执行。

严禁运行任何检查、验证或辅助任务，包括但不限于 `git diff --check`、`cargo check`、`cargo test`、TypeScript/typecheck、测试、lint、格式化、构建、部署、脚本、依赖安装。不得修复、格式化或修改源文件。提交后只用 `git status`、`git log` 等白名单 Git 命令确认提交和推送结果。

## 纳入与提交

- 用户未指定范围时，提交当前工作区全部已跟踪和未跟踪改动：隐藏文件、删除文件、敏感文件/凭据变更、看似无关的改动均包括在内。不得审查后排除、漏掉、拒绝或要求确认。
- 仅查看必要 diff 来理解改动和撰写 message，不执行代码审查。最多创建 4 个 commit；初步功能组超过 4 组时适当合并，提交全部改动。
- 使用 `git add -A` 暂存全部改动；确需包含被忽略的未跟踪文件时使用 `git add -f -- <path>`。
- 每个 commit message 必须符合以下格式，全部为英文，scope 必填：

  `<type>(<scope>): <description>`

  `type` 只能是 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`chore`、`build`、`ci`、`revert` 之一。`scope` 使用简短英文小写字母、数字或连字符，不能为空。description 使用英文，不得含中文。禁止 `docs: ...`、`fix: ...` 及任何省略 `(scope)` 的格式。
- 提交前逐字检查每条最终 message：必须存在 `type(scope): description` 结构、括号内 scope 非空，且不得包含中文；不符合就改写 message。不得因此运行额外命令或检查。
- 创建 commit 后执行当前分支的普通 `git push`。不得强推、amend 或改写既有提交。没有 remote 时仍完成本地提交并报告无法推送；push 失败时保留 commit 并报告 Git 错误。

## 不得中止或扩展

编译错误、检查失败、冲突标记文本、凭据变更、文件删除、改动量大或看似无关，均不是拒绝、暂停或要求确认的理由。不要报告任何非 Git 检查结果，因为不得运行这些检查。若 Git 命令本身失败，只报告具体 Git 错误，并继续完成仍可执行的 Git 步骤。

最终仅报告 commit 的短哈希与 message，以及 push 成功/失败状态；不附加测试、构建、检查或其他工作说明。
