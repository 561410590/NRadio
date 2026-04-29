# NRadio Plugin Assistant

NRadio 插件助手公开仓库。这里保存当前正式脚本、公开支持页、应用商店页面素材和版本记录。

当前正式版本：`V2.0.3`

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

## 功能总览

脚本主菜单按 5 个功能分类组织；旧的 `1` 到 `15` 命令行参数仍保留兼容，方便从 SSH 直接执行指定功能。

### 常用插件安装

- 扩容 swap 虚拟内存：检测可用存储，创建并启用 swap 文件，写入 `/etc/config/fstab`，用于缓解小内存设备安装大插件时的压力。
- 哈基米 / OpenClash：安装 LuCI 应用和依赖，下载 Smart 内核、核心版本文件和 ASN 数据库，修正 OpenClash 页面兼容项，写入图标并接入 NRadio 应用商店。
- ttyd / Web SSH：安装 ttyd 二进制、LuCI 配置页和 NRadio 内嵌 Web SSH 页面，支持端口、监听地址、重连、最大连接数和调试级别设置，并提供状态刷新、重启、复制地址和卸载入口。
- AdGuardHome：安装 AdGuardHome LuCI 包和核心，清理占位配置，修复登录会话、启动顺序和应用商店入口，保留官方首次设置与管理页面。
- OpenList：下载 OpenList 官方 `linux-musl-arm64` 包，安装到 `/mnt/app_data/openlist`，写入 init 服务、配置页、日志页、数据目录和应用商店入口。

### VPN / 组网 / 路由向导

- ZeroTier：安装 ZeroTier 软件包，写入 NRadio 专用控制器和 CBI 页面，接入应用商店，方便在 LuCI 内加入和管理虚拟网络。
- EasyTier：下载 EasyTier 官方发布包，安装核心、LuCI 和中文语言包，修正 OEM 环境下的控制器和默认配置，并接入应用商店。
- OpenVPN：安装 `openvpn-openssl`、LuCI 页面和 NRadio OpenVPN 连接中枢，支持启动、停止、接管现有 `client.ovpn`、复制配置、查看认证材料、隧道状态、路由健康和关键日志。
- OpenVPN 向导配置并运行：引导写入服务器、端口、协议、账号、证书、TLS、加密和额外配置，生成 `/etc/openvpn/client.ovpn` 与认证文件，并接入 `custom_config` 启动。
- OpenVPN 路由表向导：按远端主机或网段写入路由、策略规则、NAT、Proxy ARP、本机映射和域名 DNS 上游规则，便于指定流量走 OpenVPN。
- EasyTier 路由表向导：为 EasyTier 写入远端网段、虚拟 IP、LAN/TUN 接口、路由应用脚本和启动恢复逻辑。
- OpenVPN 自检：检查核心包、TUN、配置文件、服务状态、进程、应用商店入口、路由规则、NAT、DNS 和最近日志，给出 PASS / WARN / FAIL 汇总。

### 游戏加速器

- 奇游联机宝：安装奇游官方脚本和依赖，校验入口脚本特征，写入应用商店卡片、状态页和卸载脚本，可查看 `qy_acc`、`qy_mosq`、`qy_proxy`、代理连接和云端连接状态。
- 雷神加速器：可检测已安装雷神并接入应用商店，也可安装雷神官方脚本和依赖；状态页展示服务、加速进程、升级监控、端口监听、连接数和最近日志，并提供卸载入口。

### 应用商店与页面美化

- 美化应用商店：写入统一图标、卡片样式、空状态、系统状态面板、应用状态标签和 iframe 白名单，修正 OpenClash、AdGuardHome、OpenVPN、OpenList、ZeroTier、EasyTier、Web SSH、FanControl 等打开路由。
- 插件异步卸载：写入统一卸载 helper 和控制器，让已接入的脚本插件可以从应用商店发起卸载并查看结果。

### 设备维护与检测

- 统一测试模式：集中检查已安装插件、LuCI 路由、服务状态、关键文件、进程、日志和应用商店入口，用于安装后复核和现场排障。
- NRadio_C8-688 / C2000MAX 风扇控制：写回原厂“更多-风扇”页面、后台服务和配置文件，支持温度来源、Smart 最低风速、分段温控、过热保护和检测间隔。`NRadio_C8-688 / HC-WT9104` 默认使用 CPU 温度源、Smart 最低 50%、10 秒检测、85°C 保护；`NRadio_C2000MAX / HC-WT9303` 默认使用 CPU/CPE 取高值、Smart 最低 30%、5 秒检测、80°C 保护。

## 当前公开文件

| 文件 | 用途 |
| --- | --- |
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.3 正式总脚本，公网默认下载入口 |
| `00-current/ssh-nradio-plugin-installer-2.0.0beta.sh` | V2.0.0-beta 历史备份，不作为当前下载渠道 |
| `00-current/nradio-fanctrl-plugin.sh` | 风扇控制独立脚本 |
| `00-current/qiyou-nradio-temp-installer.sh` | 奇游联机宝历史临时脚本 |
| `00-current/leigod-nradio-temp-installer.sh` | 雷神加速器历史临时脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 自愿支持图片 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈边界 |

## V2.0.3 状态

- 默认下载脚本已切换为 `V2.0.3`。
- 旧 beta 独立短下载入口已取消。
- 主菜单改为 5 个功能分类。
- 奇游联机宝和雷神加速器已并入正式菜单，菜单不再标注“测试中”。
- 设备维护与检测中的风扇控制已扩展到 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 风扇控制已增加 Smart 多段温控、最低风速、温度来源、过热保护和检测间隔，并对 `NRadio_C8-688` / `NRadio_C2000MAX` 分机型写入默认策略。
- 应用商店 FanControl 打开路由统一为 `nradioadv/system/fanctrl`，并保留旧路由迁移逻辑。
- 奇游/雷神安装阶段号、官方脚本 SHA256 日志和雷神依赖失败提示已补齐。
- 公网页由 GitHub `main` 分支通过 Vercel 发布。

当前正式脚本校验：

```text
SHA256  4aaa62e0793b4e47769f233a78e1c4ef7dfbb71d9900e2fa242e25e349d25fe1
Bytes   857098
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
