# NRadio Plugin Assistant

NRadio 插件助手公开仓库。这里保存当前正式脚本、公开支持页、应用商店页面素材和版本记录。

当前正式版本：`V2.0.7`

公网入口：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)

## 快速安装

脚本适用于带 NRadio 应用商店的官方 NROS 固件，并非标准 OpenWrt 通用脚本。

支持范围：

- `NRadio_C8-688`
- `NRadio_C8-668`
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
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.7 正式总脚本，公网默认下载入口 |
| `00-current/ssh-nradio-plugin-installer-2.0.0beta.sh` | V2.0.0-beta 历史备份，不作为当前下载渠道 |
| `00-current/nradio-fanctrl-plugin.sh` | 风扇控制独立脚本 |
| `00-current/qiyou-nradio-temp-installer.sh` | 奇游联机宝历史临时脚本 |
| `00-current/leigod-nradio-temp-installer.sh` | 雷神加速器历史临时脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 自愿支持图片 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈边界 |

## V2.0.7 状态

- 默认下载脚本已切换为 `V2.0.7`。
- 旧 beta 独立短下载入口已取消。
- 主菜单改为 5 个功能分类。
- 设备识别新增 `NRadio_C8-668`，对应硬件型号 `HC-WT9108`。
- 奇游联机宝和雷神加速器已并入正式菜单，菜单不再标注“测试中”。
- 设备维护与检测中的风扇控制已扩展到 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 应用商店 FanControl 打开路由统一为 `nradioadv/system/fanctrl`，并保留旧路由迁移逻辑。
- 奇游/雷神安装阶段号、官方脚本 SHA256 日志和雷神依赖失败提示已补齐。
- 风扇控制保留 V2.0.3 的温度来源、Smart 阈值、最低风速、过热保护和检测间隔增强，并写入 `NRadio_C8-688` / `NRadio_C2000MAX` 分机型默认策略。
- OpenVPN 连接中枢 Mk2 美化层已回写总脚本，首次状态读取改为快速模式，完整诊断随后自动补齐。
- 奇游联机宝状态查看在未安装场景下不再因 `set -e` 异常退出。
- 应用商店美化用户可见口径统一为“哈基米”。
- 公网页已同步 V2.0.7 版本口径和 `NRadio_C8-668` 支持说明。
- 公网页由 GitHub `main` 分支通过 Vercel 发布。

当前正式脚本校验：

```text
SHA256  7e6874a402d915f6c310355b047b09d2ba3f9ca46e320a9e7b6378bb705bac46
Bytes   883008
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。

你可以自由使用、复制、修改、分发本仓库公开文件；保留许可证和版权声明即可。

## 反馈与安全

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

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
