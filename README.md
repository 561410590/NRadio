# NRadio Plugin Assistant

NRadio 插件助手脚本与公开支持页归档。

本仓库面向带 NRadio 应用商店的官方 NROS 固件环境，集中保存当前公开脚本、V2 beta 脚本、支持页 HTML，以及应用商店相关页面/图标参考素材。

## 当前脚本

- 稳定闭环脚本：`00-current/ssh-nradio-plugin-installer.sh`
- V2 beta 脚本：`00-current/ssh-nradio-plugin-installer-2.0.0beta.sh`
- 风扇控制独立脚本：`00-current/nradio-fanctrl-plugin.sh`
- 奇游联机宝临时脚本：`00-current/qiyou-nradio-temp-installer.sh`
- 雷神加速器临时脚本：`00-current/leigod-nradio-temp-installer.sh`

## 支持页

- 页面文件：`40-server-web/mayebano-support/index.html`
- 微信支持图片：`40-server-web/mayebano-support/wechat-donate.png`

Vercel 部署时，仓库根目录的 `vercel.json` 会把 `/` 重写到支持页，并把两个公开脚本映射为根路径下载入口。

## 应用商店素材

`10-router-pages/` 目录保存应用商店、OpenVPN、Web SSH 相关 Lua/HTM/SVG 参考文件，用于追踪脚本写入内容和页面美化来源。

## 安全边界

本仓库不包含内部记忆文档、现场账号密码、Cookie、历史备份包、路由器坏状态文件和压缩归档。

执行脚本前请先确认设备型号、固件环境和当前网络位置。脚本适用于带 NRadio 应用商店的官方固件，并非标准 OpenWrt 通用脚本。

