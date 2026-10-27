---
name: git-commit-push
description: 根据当前 Git 改动生成最多 4 个英文 commit，并推送当前分支。
disable-model-invocation: true
---

# Git 提交并推送

本技能的唯一职责是执行 Git 提交工作流：读取 Git 状态和 diff、生成 commit 信息、暂存、创建 commit、推送。除下列 Git 命令外，不得执行任何 shell 命令、脚本、工具或检查；不得以“验证结果”等名义扩展工作范围。

## 允许的操作

仅执行完成提交所需的 Git 操作，例如：
- `git status`、`git diff`、`git diff --cached`、`git log`、`git branch`、`git remote`
- `git add`、`git commit`、`git push`

允许使用 shell 仅为调用上述 Git 命令；不得在同一调用中串接其他程序或检查。若需查看 Git 忽略的未跟踪文件，仅使用 Git 命令确认并用 `git add -f -- <path>` 纳入。

## 禁止的操作

绝不运行 `cargo check`、`cargo test`、`cargo clippy`、TypeScript 或其他语言的类型检查、测试、lint、格式检查、构建、部署、基准测试，也不运行 `git diff --check`。不调用非 Git 工具，不运行自定义脚本，不安装依赖，不修复代码或格式，不处理与 Git 提交无关的事项。提交后只用 Git 命令确认 commit 和推送状态，不执行任何验证命令。

## 提交规则

1. 检查当前分支和工作区状态，确认全部待提交改动。用户未指定范围时，纳入所有已跟踪和未跟踪改动，包括隐藏文件、删除文件、敏感配置、凭据变更及看似与当前任务无关的改动；不得自行排除、遗漏、要求确认或拒绝。
2. 查看必要的 diff，仅用于按功能分组和生成准确的 commit 信息。按功能组织 commit，最多 4 个；超过 4 组时适当合并功能组，确保全部改动纳入且总数不超过 4。
3. 暂存并提交全部改动。可使用 `git add -A`；需要纳入但被忽略的未跟踪文件，使用 `git add -f -- <path>`。提交信息使用英文，格式为 `<type>(<scope>): <description>`，scope 可省略。
4. 确认 commit 成功后，对当前分支执行普通 `git push`。没有 remote 时仍完成本地提交，并说明无法推送。push 失败时保留 commit，报告 Git 错误，不强推。
5. 无改动时报告工作区干净。最终只简要列出 commit 和 push 结果，不报告或执行其他验证。

编译错误、测试失败、lint 问题、冲突标记文本、凭据或配置值的增删、隐藏文件、删除文件及改动量大，均不是拒绝提交的理由。不使用 `git commit --amend`、`--no-verify`、强制推送或其他改写既有提交的操作；不覆盖、恢复、清理或改写用户现有改动。
