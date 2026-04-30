# NRadio 插件助手

NRadio 官方 NROS2.0 路由器使用的 SSH 菜单脚本。

- 当前版本：`V2.0.15`
- 公网页：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)
- Release：[v2.0.15](https://github.com/561410590/ssh-nradio-plugin-installer/releases/tag/v2.0.15)

## 适用设备

支持以下官方 NROS2.0 设备：

| 设备 |
| --- |
| `NRadio_C8-688` |
| `NRadio_C8-668` |
| `NRadio_C5800-688` |
| `NRadio_NBCPE` |
| `NRadio_C2000MAX` |

标准 OpenWrt 不适用。脚本不是应用商店安装包，也不是固件升级包。

## 安装

先在 NRadio 后台系统安全页开启 SSH，保存并应用。

SSH 登录路由器后，在终端执行：

```sh
cd /root
wget -O ssh-nradio-plugin-installer.sh https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh
sh ssh-nradio-plugin-installer.sh
```

出现 NRadio 脚本菜单后，再按菜单编号继续。

不要把脚本上传到应用商店，也不要当固件升级包使用。

## 功能清单

当前 6 个功能组：

| 功能组 | 内容 |
| --- | --- |
| 常用插件 | Web SSH、OpenList、AdGuardHome、哈基米 |
| 网络组网 | EasyTier、ZeroTier、OpenVPN |
| 应用商店美化 | 卡片视觉、状态徽标、只读面板 |
| 系统维护 | swap、自检、卸载链 |
| 风扇控制 | C8-688、C2000MAX、Smart PWM |
| 游戏加速器 | 奇游、雷神、状态读取 |

## V2.0.15 更新

- 奇游、雷神安装前复用哈基米软件源检查流程。
- 未切到 OpenWrt 21.02.7 清华源时，先备份并切换，再继续安装。
- 公网页同步奇游 / 雷神源切换说明。
- 应用商店美化可见口径统一为“哈基米”。

## 版本记录

- `V2.0.15`：奇游 / 雷神源切换。
- `V2.0.10`：风扇定时策略。
- `V2.0.7`：新增 `NRadio_C8-668`。
- `V2.0.6`：奇游状态与应用商店标记收口。
- `V2.0.3`：风扇控制增强。
- `V2.0.2`：FanControl 路由、奇游 / 雷神阶段提示和 SHA256 日志补齐。
- `V2.0.1`：风扇控制支持 `NRadio_C8-688` / `NRadio_C2000MAX`。
- `V2.0.0`：默认下载脚本切到正式版。

## 文件

| 文件 | 用途 |
| --- | --- |
| `00-current/ssh-nradio-plugin-installer.sh` | V2.0.15 正式脚本 |
| `40-server-web/mayebano-support/index.html` | 公网支持页 |
| `40-server-web/mayebano-support/wechat-donate.png` | 微信支持图片 |
| `CHECKSUMS.txt` | 当前公开文件校验 |
| `CHANGELOG.md` | 版本记录 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈 |

## 脚本校验

当前脚本：

```text
SHA256  36908f940697380b7dadab94321a381f7465868a95aadbd5bcde43f3b1f0bbf3
Bytes   889185
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 反馈

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。
