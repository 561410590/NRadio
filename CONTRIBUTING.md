# Contributing

感谢关注 NRadio Plugin Assistant。这个仓库公开保存当前正式脚本、支持页和公开素材，内部记忆文档、现场备份和私有运维文件不进入 GitHub。

## 反馈问题前

- 确认设备是 NRadio 官方 NROS 固件，不是标准 OpenWrt。
- 说明机型和固件版本，例如 `NRadio_C2000MAX NROS2.1.8.n0.c1`。
- 说明脚本版本，例如 `V2.0.35`。
- 贴出菜单路径、执行命令和关键输出。
- 不要提交 root 密码、Cookie、公网 SSH 地址、内网穿透地址或完整私有配置。

## 修改建议

- 脚本改动应尽量保持最小范围，不改无关菜单和下载链。
- 涉及安装、卸载、应用商店入口和页面美化时，需要说明验证范围。
- Windows 本地不要用 WSL/bash 结果代替路由器现场验证。
- 路由器传文件应使用 SCP / pscp。

## 发布边界

公开发布链为：

```text
D:\Downloads\NRadio -> GitHub main -> Vercel Production -> https://nradio.mayebano.shop/
```

更新正式脚本时，同步检查：

- `README.md`
- `CHANGELOG.md`
- `CHECKSUMS.txt`
- `.github/workflows/repo-check.yml`
- `40-server-web/mayebano-support/index.html`
