# NRadio Plugin Assistant

NRadio 插件助手公开仓库。这里保存当前正式脚本、公开支持页、应用商店页面素材和版本记录。

当前正式版本：`V2.0.0`

公网入口：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)

## 快速安装

脚本适用于带 NRadio 应用商店的官方 NROS 固件，并非标准 OpenWrt 通用脚本。

支持范围：

- `NRadio_C8-688`
- `NRadio_C5800-688`
- `NRadio_NBCPE`
- `NRadio_C2000MAX`

在路由器 SSH 终端执行：

```sh
cd /root
wget -O ssh-nradio-plugin-installer.sh https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh
sh ssh-nradio-plugin-installer.sh
```

如果路由器不能访问公网，先在电脑下载脚本，再用 SCP 上传到路由器 `/root/` 后执行。

## 当前公开文件

| 文件 | 用途 |
| --- | --- |
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.0 正式总脚本，公网默认下载入口 |
| `00-current/ssh-nradio-plugin-installer-2.0.0beta.sh` | V2.0.0-beta 历史备份，不作为当前下载渠道 |
| `00-current/nradio-fanctrl-plugin.sh` | 风扇控制独立脚本 |
| `00-current/qiyou-nradio-temp-installer.sh` | 奇游联机宝历史临时脚本 |
| `00-current/leigod-nradio-temp-installer.sh` | 雷神加速器历史临时脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 自愿支持图片 |

## V2.0.0 状态

- 默认下载脚本已切换为 `V2.0.0`。
- 旧 beta 独立短下载入口已取消。
- 主菜单改为 5 个功能分类。
- 奇游联机宝和雷神加速器已并入正式菜单，菜单不再标注“测试中”。
- 公网页由 GitHub `main` 分支通过 Vercel 发布。

当前正式脚本校验：

```text
SHA256  19e75fb79571a318b91c7926306850c4e42c1f8000fcca2042d91b16b7ff7a4a
Bytes   849304
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。

你可以自由使用、复制、修改、分发本仓库公开文件；保留许可证和版权声明即可。

## 目录说明

| 目录 | 内容 |
| --- | --- |
| `00-current/` | 当前公开脚本和历史脚本 |
| `10-router-pages/` | 应用商店、OpenVPN、Web SSH 相关 Lua / HTM / SVG 参考素材 |
| `30-theme/nradio-theme-modified-files/` | NRadio 主题修改参考素材 |
| `40-server-web/mayebano-support/` | Vercel 公网页文件 |

## 发布链路

`D:\Downloads\NRadio` 本地维护目录 -> GitHub `main` -> Vercel Production -> `https://nradio.mayebano.shop/`

`vercel.json` 当前公开路由：

- `/` -> `40-server-web/mayebano-support/index.html`
- `/wechat-donate.png` -> `40-server-web/mayebano-support/wechat-donate.png`
- `/ssh-nradio-plugin-installer.sh` -> `00-current/ssh-nradio-plugin-installer.sh`

## 安全边界

本仓库不上传：

- 内部记忆文档
- 现场账号密码、Cookie、会话文件
- 历史备份包、zip、坏现场文件
- 本地工具 exe
- 旧 1Panel / 路由器现场私有文件

执行脚本前请确认设备型号、固件环境、SSH 登录目标和当前网络位置。不要在未确认的旁路由、服务器或标准 OpenWrt 设备上执行。
