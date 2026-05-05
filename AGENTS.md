# AGENTS.md instructions for D:\Downloads\NRadio

## First Read

- On every resume, read `00-current/NRadio统一记忆文档.txt` before acting.
- Treat that file as the current project authority for version, release state, router boundaries, and stale-work warnings.
- Old documents in `90-backup/` and `99-archive/` are historical references only unless the user explicitly points to them.

## Priority Rules

- Current user wording wins over automation habits, skills, memory-update routines, and default workflows.
- If the user says `检查`, `只读`, `只能看`, `只扫描`, `不要改`, `不要写入`, or `禁止修改任何内容`, do not modify any file.
- The no-write rule includes project files, scripts, docs, automation memory, agent memory, generated reports, cleanup notes, and "撤回" fixes.
- If a previous write was wrong, report exactly what should be reverted and wait for explicit write authorization before changing files.
- `撤回` alone is not write authorization. Only proceed after wording such as `允许修改并撤回`, `允许改 memory 撤回`, or `执行撤回修改`.

## Core Execution Discipline

- 用户说"检查"，就只检查。
- 用户说"执行"，才执行对应修改。
- 没有明确授权，不修改脚本。
- 用户说"先改本地"，不能碰在线路由器、服务器、GitHub、tag 或 Release。
- 只能操作用户明确点名的设备，不能从一台路由器漂移到另一台。
- 不能因为命令不会写，就改用临时脚本、here-string、多层拼接绕过去。
- 不要把执行方式、输入方式、PowerShell 引号问题误判成脚本 bug。
- 如果已有稳定备份，且脚本越改越乱，应先恢复到稳定备份，再做最小必要修改。
- 不要让事情越做越乱，禁止无脑空转和反复试错，禁止把猜测当结论。
- 不许反复报告没有用的内容，不许碎嘴。
- 所有思考过程（thinking）必须使用中文。

## Bug Discovery Protocol

- 发现 bug 后先收集全部实锤证据。
- 列出所有发现的 bug，告知用户"有哪些"。
- 等用户同意后，再到具体位置修改。
- 禁止边发现边猜边改，禁止试错式修复。
- 禁止把猜测当结论。

## Modification Rules

- Do not modify scripts without explicit authorization.
- 脚本内容修改必须使用 `apply_patch`；严厉禁止使用 PowerShell 写改脚本内容。
- 非脚本项目文件编辑也应使用 `apply_patch` 做清晰可审查的差异变更。
- PowerShell 仅用于只读检查、hash 校验、进程执行、文件传输。
- Do not use PowerShell to rewrite script content.
- Do not delete, restore, reset, or clean working-tree files unless the user explicitly asks.

## Router Rules

- Only operate on the router device explicitly named by the user. Do not drift to another router.
- If the user says `先改本地`, do not touch online routers, servers, GitHub, tags, or releases.
- Before router write operations, run a read-only check first.
- Back up router config files before changing them.
- 传文件到路由器只能使用纯 SCF 方式（pscp -scp）。
- 禁止在 PowerShell + plink 远端命令里写带引号保护的复杂 `grep -E "a|b"`、括号、正则管道、`awk`/`sed` 脚本。
- 禁止把远端过滤写成可能被 ash 误拆的命令；需要过滤时先执行简单只读命令拿原始输出，再本地过滤分析。
- 后续对路由器只用"纯远端 shell 语义"的简单命令；复杂分析留在本地做，不让远端 ash 猜引号。

## GitHub Rules

- Do not create branches, commit, push, tag, publish releases, or open PRs unless the user explicitly asks.
- Do not claim a GitHub Release, Actions run, remote branch, or remote asset is current unless verified in the same turn.
- If GitHub or TLS checks time out, report the timeout as a timeout. Do not treat it as success.

## Current Authority

- Current main script: `00-current/ssh-nradio-plugin-installer.sh`
- Current script version: `V2.0.30`
- Current release date: `2026-05-04`
- Public page: `40-server-web/mayebano-support/index.html`
- Current public release: `https://github.com/561410590/ssh-nradio-plugin-installer/releases/tag/v2.0.30`

## Release Hygiene

When preparing a publishable update, keep these files aligned:

- `README.md`
- `CHANGELOG.md`
- `CHECKSUMS.txt`
- `.github/workflows/repo-check.yml`
- `40-server-web/mayebano-support/index.html`
- `00-current/NRadio统一记忆文档.txt`

## Current Stale-Work Warnings

- The workspace may contain old unrelated deletions, theme edits, screenshots, and untracked files.
- Do not clean or restore those items unless the user explicitly asks for cleanup.
- If a requested change touches a file with unrelated existing edits, preserve the user's work and keep the patch minimal.
