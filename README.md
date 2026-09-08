# NRadio 插件助手

NRadio 官方 NROS 路由器使用的 SSH 菜单脚本。

- 当前本地版本：`V3.0.7`（2026-09-07）
- 当前公网正式版本：`V3.0.7`，下载与校验以 GitHub Releases 页面为准
- 当前状态：`V3.0.7` 总脚本、图文支持页、仓库资料与 Repository checks 已同步发布。
- 公网页：[https://nradio.mayebano.shop/](https://nradio.mayebano.shop/)
- GitHub Releases：[发布页](https://github.com/561410590/ssh-nradio-plugin-installer/releases)

## 当前维护状态

总脚本、图文支持页、仓库资料与检查规则使用 `V3.0.7`。正式标签与 Release 为 `v3.0.7`。

## Mesh组网插件 1.0.14

- 当前下载包：`luci-app-nradio-roaming_1.0.14-1_all.ipk`；支持页固定入口为 [nradio-mesh.ipk](https://nradio.mayebano.shop/nradio-mesh.ipk)。
- 自动连接按 5G 优先、同频信号强度排序；当前候选失败后自动尝试下一个，最多尝试 8 个候选。
- NRadio BSSID 候选识别覆盖 `F0/F2/F4/F6/F8/FA/FC/FE:83:C6` 地址族，并继续通过受保护探针确认真实控制器。
- 本地 12 项插件测试、IPK 解包审计与 Repository checks 均通过；真实组网仍需按设备现场验收。

## QoS 应用商店插件 1.0.24

- 当前下载包：`luci-app-nradio-qos-pro_1.0.24-1_all.ipk`；支持页固定入口为 [nradio-qos-pro.ipk](https://nradio.mayebano.shop/nradio-qos-pro.ipk)。在 NRadio 应用商店选择本地安装，配置真实带宽后启用。
- VPN 与双线路联动：启停、VPN 重连和后台检查同步站点路由的 mwan3 排除集合；失败显示诊断，VPN-only 恢复保留限速队列。
- C8-788：依据 `HC-WT9302 / HCMT7987-NAND / NROS 2.2.12.n0.c1` 实机输出适配 `eth3` 蜂窝出口及原厂双栈全宽 mark 分类顺序。
- 合并 IPv6 多地址跟踪、减少队列重建、未保存输入保护和请求超时处理。本地回归与安装包检查通过；实机 VPN 连通性和限速数值需按设备验收。
- 本节是独立 QoS 插件更新，当前本地总脚本版本为 `V3.0.7`。

## 适用设备

支持以下官方 NROS 设备：

| 设备 | 机型代号 | NROS 范围 |
| --- | --- | --- |
| `NRadio_C8-688` | `HC-WT9104` | NROS 2.x |
| `NRadio_C8-668` | `HC-WT9108` | NROS 2.x |
| `NRadio_C8-788` | `HC-WT9302` / `HCMT7987-NAND` | NROS 2.x（小容量 NAND 受限配置） |
| `NRadio_C5800-650` | `HC-WT9120` | NROS 2.x |
| `NRadio_C5800-688` | `HC-WT9126` | NROS 2.x |
| `NRadio_NBCPE` | `HC-WT9111` / `NRADIO-WT9111` | NROS 2.x |
| `NRadio_C2000MAX` | `HC-WT9303` | NROS 2.x |
| `NRadio_C2000Pro` | `UDX710` / `RG200U-CN` | NROS 2.x（有限兼容） |
| `NRadio_AK68-798` | `HC-WT9194` / `HCMT7987-S256` | NROS 2.x（16 MiB NOR 轻量模式） |
| `NRadio_C2000Ultra` | `HC-WT9500` / `HCMT7987-SNSD` | NROS 2.x（通用功能、SD 卡检测与 Swap） |

支持页已预告 `NRadio_N5000`，当前为“即将支持、暂未适配”：不属于上表的当前支持范围，总脚本不会识别或放行，请等待正式适配公告。

标准 OpenWrt 不适用。脚本不是应用商店安装包，也不是固件升级包。

## 安装

先在 NRadio 后台系统安全页开启 SSH，保存并应用。

`NRadio_C8-788` 不能通过隐藏链接开启 SSH。先下载 [SSH 管理 IPK](https://nradio.mayebano.shop/nradio-ssh-manager.ipk)，在 NRadio 应用商店选择本地安装；安装完成后打开“SSH 管理”并启用 SSH。

`NRadio_AK68-798` 在“更多 → 备份/恢复”上传 [SSH 2222 配置包](https://nradio.mayebano.shop/AK68-798-SSH-2222.nr)，恢复后重启，使用 LAN 地址和 TCP 2222 登录。配置包不修改 root 密码。

SSH 登录路由器后，在终端执行：

```sh
cd /root
wget -O ssh-nradio-plugin-installer.sh https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh
sh ssh-nradio-plugin-installer.sh
```

出现 NRadio 脚本菜单后，再按菜单编号继续。

不要把脚本上传到应用商店，也不要当固件升级包使用。

## 功能清单

当前 5 个功能分类：

| 功能分类 | 内容 |
| --- | --- |
| 常用插件安装 | swap（C2000MAX / C2000Ultra）、哈基米、Web SSH、AdGuardHome、OpenList、MosDNS、DDNS-GO、MT5700 WebUI V3.0.0、Docker（仅 C8/C5800 扩展盘） |
| VPN / 组网 / 路由向导 | EasyTier、ZeroTier、OpenVPN |
| 游戏加速器 | 奇游、雷神、状态读取和卸载链 |
| 应用商店与页面美化 | 卡片视觉、状态徽标、手机保存按钮兼容、原厂还原、C2000Pro / AK68-798 轻量应用商店、OpenWrt LuCI 8080 |
| 设备维护与检测 | 统一体检、哈基米依赖修复、封版工具箱、C8/C5800 eMMC 存储扩展、PicoClaw / 鲲鹏小龙虾迁移与还原、通用卸载链、风扇控制、智能频段 v7、首页 CPU/5G 温度、5G 连接监听 |

## V3.0.7 更新

- GitHub 资源下载加入 `gh-proxy.com` 优先与官方地址自动回退，覆盖哈基米、OpenList、EasyTier、MT5700 WebUI、Web SSH 等安装资源；下载过程显示实际传输进度并支持断点续传。
- `NRadio_C2000Ultra` 接入 C2000MAX 的 SD 卡检测和 Swap 管理：`1 > 1` 默认创建 512 MiB，允许扩容至 2048 MiB；统一体检和应用商店同步显示 Swap 状态。
- MT5700 WebUI 的 C5800 适配按实际 `cpe / cpe1` 显示单线或双线；单线占满一行，只有 `cpe1` 时使用对应连接，双线路的详情、AT 与计划保持隔离。
- AdGuardHome 安装后统一路由器本机与局域网普通查询的 DNS 链，保留已有域名专用上游，并仅按实际变更重启相关服务。
- 更新应用商店 V3、插件弹窗、8080 原生 LuCI 总览、首页 CPU / 5G 温度切换及 5G 连接监听。

## V3.0.6 更新

- 5G 连接监听改为路由器后台常驻服务，每 10 秒记录线路、网络、频段和基站变化；关闭 LuCI 页面后继续记录。
- 修复 4G 频段被误标为 N 频段：LTE 使用 B 前缀，NR 使用 N 前缀。
- 智能频段状态、只读预览、立即执行和运行日志并入 5G 连接监听 LuCI 页面；CLI 子菜单只保留安装或更新、卸载。
- C5800-688 页面新增智能频段可逆启停；停用后系统自行管理频段，连接监听继续运行，可直接重新启用。
- 设备维护菜单按机型连续编号；5G 连接监听继续支持 C5800-650、C5800-688 和 C2000MAX，智能频段仅向 C5800-688 开放。
- 删除安装结束后的重复终验，页面按钮改为稳定网格布局；5G 连接监听组件版本更新到 `20260903-4`。

## V3.0.5 更新

- 新增 `NRadio_C2000Ultra`：识别 `HC-WT9500 / HCMT7987-SNSD`，开放原厂完整应用商店、OpenWrt LuCI 8080、奇游映射及默认通用菜单，保留各机型专属功能限制。
- 新增 `NRadio_AK68-798`：识别 `HC-WT9194 / HCMT7987-S256`，使用 16 MiB NOR 轻量模式。
- `4 > 4` 为 C2000Pro / AK68-798 轻量应用商店；完整应用商店功能对这两个机型隐藏。
- AK68-798 开放 `5 > 10` 首页 CPU 温度显示和统一体检。
- 支持页新增 AK68-798 SSH 2222 恢复教程与 `AK68-798-SSH-2222.nr` 下载。
- Repository checks 校验配置包封装头、gzip/tar 结构、唯一文件、Dropbear 内容、SHA-256、网页链接、Vercel 路由和校验清单。

## V3.0.0 更新

- `SCRIPT_VERSION` 保持 `V3.0.0`，当前本地构建日期为 `2026-08-30`；公开正式 Release 日期仍为 `2026-08-29`。
- 新增 `NRadio_C8-788`：识别 `HC-WT9302 / HCMT7987-NAND`，按 128 MB NAND 小容量配置开放 OpenClash、奇游/雷神、应用商店维护、统一体检、首页温度和风扇控制。
- 新增 `1 > 9 MT5700 WebUI V3.0.0`：安装 `semi-tcpweb` V3.0.0；NRadio 应用商店可打开和卸载，入口跳转 `/5700/`，不安装上游标准 LuCI 菜单包。
- `5 > 11` 调整为仅限 `NRadio_C5800-650 / C5800-688` 的“5G 连接监听”，提供安装或更新与原厂恢复式卸载。
- TTYD / Web SSH 下载允许过期证书环境，移除旧 ttyd 文件所有权拦截和安装尾部失败式校验；访问默认免登录，不再生成或传递 Basic Auth 用户名密码。
- 新增 `4 > 3 OpenWrt 原版 LuCI（8080）`，使用独立目录和独立 uhttpd 监听，不替换 NRadio 80 端口界面。
- 修复 8080 安装链改走 NRadio 主站默认主题的问题；安装结束再次恢复 `/luci-static/nradio`。
- 首页温度、主副 5G 显示、运营商与卡名链继续独立维护；智能频段 v7 在读频段前后核对当前 SIM，SIM 未知或切换中时停止控制。
- 修复智能频段 v7 运行文件缺少 `process_starttime()` 和 `ensure_runtime_dir()` 的问题。
- 兼容 NROS 2.2.12 应用商店手机保存按钮与固件接口差异；保留固件已有功能，只补缺少的接口。
- 支持页加入 C8-788 SSH 管理 IPK 下载和应用商店安装说明；总脚本下载仍指向 `00-current/ssh-nradio-plugin-installer.sh`。
- README、CHANGELOG、CHECKSUMS 和 Repository checks 已同步到 V3.0.0 / 2026-08-30 本地构建。

## V2.9.9 更新

- `SCRIPT_VERSION` 更新为 `V2.9.9`，发布日期 `2026-08-20`。
- 兼容 NROS 2.2.12 官方运营商卡名：固件原生 `sim_name` 优先，官方值为空时才回退精确 ICCID 映射；无有效 ICCID 时不跨页面持久化卡名缓存。
- 同时兼容新固件状态对象与旧固件双参数 `format_isp_info()`，覆盖新旧运营商字段和双卡显示。
- 修复 C2000MAX 应用商店系统状态默认折叠导致 Swap 指标不可见：首次收到 MAX 状态自动展开，用户手动折叠后不再强制重开。
- C2000MAX 已完成纯 SCP 上传和 `4 > 1` 应用商店 V3 五步重跑；`appcenter`、`uhttpd` 与实时 Swap 状态正常。
- 支持页、README、CHANGELOG、CHECKSUMS 和 Repository checks 已同步到 V2.9.9 正式发布口径；Release 资产只包含单一总脚本与校验清单。

## V2.9.8 更新

- 补齐 OpenVPN DNS 清理与 C2000Pro Web SSH 变量，生成的通用卸载助手改为自包含事务链。
- 网页卸载任务加入 PID、退出码、日志、全局锁和超时恢复，避免陈旧 `running` 阻塞后续操作。
- Docker 安装与卸载加入系统文件清单、校验算法和旧残留安全比对；用户改过或被其他软件包接管的文件不删除。
- 下载链兼容 BusyBox/GNU wget 并回退 `uclient-fetch`；隐藏输入在中断时恢复回显，诊断脱敏覆盖更多凭据格式。
- 智能频段当前运行代码以内嵌 v7 为准；独立 `nradio-smart-band.sh` 不属于运行或公开发布依赖。

## V2.9.5 更新

- `SCRIPT_VERSION` 更新为 `V2.9.5`，发布日期 `2026-08-13`。
- 修复应用商店 V3 共享接入链，避免 OpenClash 及其他插件在 LuCI、图标和应用商店接入阶段因旧模板锚点误判而停止。
- OpenClash 安装依赖与 NRadio 定制固件实际能力对齐，移除无法从 21.02.7 feed 安装且不属于官方 IPK 依赖的 `kmod-inet-diag`、`kmod-nft-tproxy`。
- 智能频段、奇游、雷神、MosDNS、DDNS-GO 和 ttyd 撤除固定 MD5/SHA256 安装门禁；继续保留 shell 语法、压缩包可读、IPK 存在和二进制可运行等实际可用性检查。
- 撤除应用商店事务目录、通用 `.bak`、OpenClash 自定义规则、5G 聚合、WebSSH 和 Docker 的持久备份写入；应用商店美化与原厂还原直接执行。
- 支持页同步 `V2.9.5 / 2026-08-13`，预告机型更新为 `NRadio_N5000`，并完成手机首屏五等分导航、双按钮和双列版本面板适配。
- 安全准则收紧为仅限 NROS 2.x；明确本项目是 SSH 脚本，不是应用商店安装包，禁止从应用商店安装。
- README、CHANGELOG、CHECKSUMS 和 GitHub Actions 检查规则已同步；正式发布内容由 `main` 的 Repository checks 验证。

## V2.8.5 更新

- `SCRIPT_VERSION` 更新为 `V2.8.5`，发布日期 `2026-08-10`。
- 完整 `nradio-smart-band v5` 源码内嵌总脚本；上传、下载、保存和发布只需 `ssh-nradio-plugin-installer.sh`，不依赖旁置脚本。
- 新增 `5 > 8 智能频段管理（C5800-688）`：安装或更新、状态、只读模拟、立即执行、日志、卸载均可从中文菜单完成。
- 智能频段策略改为联网健康优先：移动/广电 N28/N41 链路健康时只记录，不再因频段变化频繁 CFUN；IPv4 连续失败后先软恢复，CFUN 仅作带冷却和次数限制的最终手段。
- `5 > 1` 统一体检加入智能频段脚本权限、语法、内嵌 SHA256、cron 唯一性、准确任务行和只读状态检查。
- 支持页升级为 V2.8.5：增加单一总脚本和智能频段状态摘要、历史版本折叠、复制失败提示、键盘焦点、阅读进度与移动端适配。
- 2026-08-11 支持页新增 `NRadio_C2000Ultra` 与后续更名为 `NRadio_N5000` 的“即将支持、暂未适配”预告卡片；未把两款机型加入总脚本识别或功能放行。
- 总脚本、网页和仓库资料已同步至 GitHub `main`，并纳入 `v2.8.5` 正式发布。

## V2.8.0 更新

- `SCRIPT_VERSION` 更新为 `V2.8.0`，发布日期 `2026-08-03`。
- 修复状态值单引号转义；OpenVPN 与 EasyTier 状态文件加入 `NRADIO_STATE_FORMAT='2'`，主脚本、内嵌卸载脚本和生成的 EasyTier 路由脚本拒绝加载旧版无标记状态文件。
- 下载、GitHub API、CDN 探测、EasyTier 状态查询及集成下载链移除不安全 TLS 参数，恢复证书校验。
- `ensure_opkg_update()` 失败时显式返回失败；OpenClash、MosDNS、DDNS-GO、ZeroTier、EasyTier、奇游和雷神等安装入口立即停止，不再带着失败的软件源状态继续安装。
- 奇游与雷神入口脚本继续执行固定 SHA256 校验。
- C5800-688 已运行 `5 > 1` 统一体检：26 PASS、2 WARN、0 FAIL、4 SKIP；核心运行状态通过。
- 当前仅完成本地同步和实机验证；GitHub Release 与公网仍为 `V2.7.5`。

## V2.7.5 更新

- `SCRIPT_VERSION` 更新为 `V2.7.5`，发布日期 `2026-08-02`。
- 新固件已内置 FanControl controller、CBI 或温度模板时，同时跳过内容写入和 `chmod`，避免 OverlayFS 生成 upper 覆盖；该保护同时用于 `NRadio_C8-688` 和 `NRadio_C2000MAX`。
- 保留 OpenClash `v0.47.133` 调试日志标签页兼容、六标签页、iframe 黑屏兜底和原版页面修复。
- 独立维护脚本 `00-current/nradio-smart-band.sh` 更新至 v3：跳过禁用接口、清理旧重试死锁、使用 2 小时冷却和 12 小时重试窗口，并记录实时频段信息。
- C5800-688 / NROS `2.2.8.n0.c0` 已完成现场验证，启用链路保持 NR N1，默认路由不中断。
- 当前脚本 SHA256 和大小见下方“脚本校验”及 [CHECKSUMS.txt](CHECKSUMS.txt)。

## V2.7.0 更新

- 适配 C2000MAX NROS `2.2.8.n0.c1` 固件内置 FanControl LuCI 文件。
- ROM 已有 controller、CBI、`temperature_ajax.htm` 或 `temperature.htm` 时跳过 heredoc 覆盖；固件缺失的美化模板、配置和后台服务继续生成。

## V2.6.5 更新

- OpenWrt 21.02.7 活跃 feed 切换为阿里云源，镜像顺序调整为阿里云、OpenWrt 官方、清华备用。
- OpenClash `v0.47.133` 新增 `Debug Logs` 空状态提示和生成日志后的状态更新。

## V2.6.0 更新

- 新增 `NRadio_C2000Pro` / UDX710 / RG200U-CN 识别及 NROS `2.1.8.n0.c1` 有限兼容。
- 为 C2000Pro 生成最小应用商店兼容层，同时隔离 C2000MAX 存储卡、C8/C5800 `rootfs_2nd`、风扇与 5G 聚合逻辑。

## V2.5.0 更新

- `5 > 6` 新增哈基米依赖检查修复，检查 OpenClash 配置、服务、核心、`ASN.mmdb` 和 `Model.bin`。
- `5 > 1` 增加封版摘要；`5 > 7` 新增脱敏诊断报告、备份清单和动作日志工具箱。

## V2.3.0 更新

- `SCRIPT_VERSION` 更新为 `V2.3.0`，发布日期 `2026-06-13`。
- PicoClaw / 鲲鹏小龙虾接入 C8/C5800 `rootfs_2nd` 应用迁移与还原链，覆盖 `5 > 4 > 5` 和 `5 > 4 > 6`。
- 新增迁移项 `/usr/bin/picoclaw`、`/usr/bin/picoclaw-launcher`、`/.picoclaw`，复用现有 `nradio-apps` 软链记录和服务停启流程。
- 本次只处理已安装 PicoClaw / 鲲鹏小龙虾的落盘迁移，不负责安装插件、登录模型、OpenClash 规则或账号凭据。
- 公网页同步 V2.3.0 版本口径。
- 当前脚本 SHA256：`3f912f428e44a725ed014f6a461d01661d2ded436d5fbec74a3e79e7e59b1243`（大小 1902378 字节）。

## V2.2.5 更新

- `SCRIPT_VERSION` 更新为 `V2.2.5`，发布日期 `2026-06-09`。
- OpenClash 应用商店 iframe 弹窗保留原逻辑，补入黑屏兜底、重载按钮和原版页面顶层跳转。
- OpenClash 保留六个官方标签页：运行状态、插件设置、覆写设置、配置订阅、配置管理、运行日志。
- OpenClash 原版页面隐藏 OEM 顶栏、footer、首页、蜂窝、上网、Wi-Fi、终端和更多，并修复半屏显示。
- 公网页同步 V2.2.5 版本口径，补入 V2.2.0 C2000MAX swap 状态卡日志和 V2.2.5 OpenClash 兼容日志。
- 当前脚本 SHA256：`2666c42c23cddc22ade3911eff0571c967d69821d0cadd3691bb7719a26c6c93`（大小 1899977 字节）。

## V2.2.0 更新

- 应用商店系统状态卡新增 C2000MAX 虚拟内存指标，读取 swap 总量、用量和百分比。
- 非 C2000MAX 自动隐藏 swap 指标，C2000MAX 未启用 swap 时显示“未启用”。

## V2.1.5 更新

- 新增 `NRadio_C5800-650` / `HC-WT9120` 识别，按 NROS 2.x 口径放行。
- Docker / `rootfs_2nd` 扩展盘链补入 C5800-650。
- 缺 NRadio 应用商店环境时，启动层直接退出并提示缺失路径。

## V2.1.0 更新

- Docker 加入常用插件安装菜单第 8 项，仅支持 `NRadio_C5800-688` / `NRadio_C8-688`。
- Docker 安装前要求已启用 `rootfs_2nd` eMMC 扩展盘，下载缓存、feed index、工作目录、IPK 缓存、手动解包目录、备份和 `data-root` 均固定在 `/mnt/rootfs_2nd_data/nradio-apps/docker`。
- Docker LuCI 页面写入 `nradioadv/system/docker`，应用商店入口、图标、状态接口和异步卸载链同步接入。
- Docker 安装链修复 overlay 打满和系统路径污染风险：大体积 Docker 二进制保留扩展盘软链，小依赖库复制到系统路径。
- 公网页同步 V2.1.0 版本口径，当前里程碑改为 Docker 扩展盘安装链接入，历史更新卡只保留 V2.0.70。
- 当前脚本 SHA256：`ec15ab95aca25528f85ed57b1bf2fbc7d243222b2fa1d2262e480892f4da50bd`（大小 1872225 字节）。

## V2.0.70 更新

- 5G 负载均衡支持副 5G / 蜂窝权重设置，保存后自动提交并重启 `mwan3`，避免 UCI 已变但运行态仍停留在旧比例。
- 新增 **C8/C5800 eMMC 存储扩展**，支持将 `rootfs_2nd` 接入为扩展盘，并提供应用迁移、还原和第二系统烧录保护。
- OpenClash / AdGuardHome 还原支持 hybrid 保留策略，overlay 空间不足时保留大项子链接，避免误删扩展盘真实内容。
- OpenClash 扩展盘迁移和哈基米分流助手重载前新增 `ASN.mmdb` 有效性校验，缺失或异常时先停止并提示补齐。
- 修复 OpenList 在 C8/C5800 存储扩展后 `/mnt/app_data/openlist` 断链目标缺失导致安装失败的问题；安装链会识别符号链接并先修复扩展盘目标目录。
- 修复 DDNS-GO 迁移到扩展盘后以 `ddns-go` 用户启动失败的问题，迁移/还原菜单会修正 `nradio-apps` 路径可穿透权限。
- OpenVPN 页面升级到 Mk5 深色玻璃界面，pass 7 至 pass 10 精修已回写总脚本，补强标题、摘要卡、按钮、日志、诊断区、弹窗和小屏防溢出细节。
- AdGuardHome 与应用商店页面美化继续回写总脚本，AdGuardHome 状态页精修、应用商店 pass 3 至 pass 6、系统卡片内存显示、OpenVPN 版本号短显示和 C2000MAX 1 号卡白条修复已进入安装输出。
- 公网页同步 V2.0.70 版本口径，并保留粉色主题视觉精修。
- 本地全量 bug 扫描收口：安装链移除 `base64` / `gzip` 依赖路径，OpenList / DDNS-GO 归档校验改为 tar 自检，MosDNS 解压前补齐 `unzip` 依赖兜底，应用商店 iframe 关闭与外层布局清洗链同步修复。
- 常用插件菜单中的 **扩容 swap 虚拟内存** 仅支持 `NRadio_C2000MAX`，菜单文案同步标明限制。
- 当前脚本 SHA256：`b4aad4ddabde87ce3f4eff2890a4193eb474cf757e9788307fab75ee441b155f`（大小 1702232 字节）。

## V2.0.50 更新

- 新增 **DDNS-GO** 插件（常用插件菜单第 7 项），包含三件套安装、OEM 包装页、图标、应用商店注册、异步卸载链和虚拟内存接入。
- DDNS-GO 首次安装会在启动服务前设置 Web 登录账号密码，并初始化 `/etc/ddns-go/ddns-go-config.yaml`。
- 修复 `opkg print-architecture` 中 `noarch` 排在前面时导致 DDNS-GO 架构误判的问题。
- 补强应用商店 `package_list` 路由校验、旧路由清理、异步卸载日志、同插件并发锁和 opkg 锁等待。
- C2000MAX 安装 OpenList 时自动改用 lite 包，并把下载包与解压目录放到存储卡，降低 `/tmp` 内存占用和文件过大导致的安装失败风险。
- 公网页同步 V2.0.50 已发布口径，补入 DDNS-GO、应用商店卡片布局和 AdGuardHome 内页二次重新美化说明。
- 当前脚本 SHA256：`e32fc09076793822635c65e174e32caf55ab9ecf8e6f9039cccbf5ab635e188a`（大小 1163194 字节）。

## 版本记录

- `V3.0.6`：5G 后台持续监听、4G B 频段识别、智能频段 LuCI 整合与可逆启停。
- `V3.0.5`：C2000 Ultra 与 AK68-798 适配、SSH 2222 恢复教程和可靠性更新。
- `V3.0.0`：全机型 5G 连接优化、OpenWrt LuCI 8080、智能频段 v7、首页双 5G 与温度显示、NROS 2.2.12 页面兼容。
- `V2.9.9`：NROS 2.2.12 官方卡名原生优先、旧固件 ICCID 回退、C2000MAX Swap 状态自动展开。
- `V2.9.8`：卸载事务与全局锁、Docker 文件清单、wget 后备、终端回显恢复和诊断脱敏收口。
- `V2.9.5`：应用商店 V3 共享接入修复、OpenClash 定制固件依赖收口、固定安装哈希与持久备份撤除、支持页手机适配。
- `V2.8.5`：智能频段 v5 内嵌总脚本、`5 > 8` 中文管理、联网健康优先策略与支持页交互优化。
- `V2.8.0`：状态文件注入防护、TLS 校验恢复、opkg 失败阻断，并完成 C5800-688 统一体检。
- `V2.7.5`：FanControl ROM 文件完全免写、OpenClash 新 LuCI 兼容保留、C5800-688 智能频段 v3 现场验证。
- `V2.7.0`：C2000MAX NROS 2.2.8 固件内置 FanControl 文件识别。
- `V2.6.5`：OpenWrt feed 切换阿里云源，适配 OpenClash v0.47.133 调试日志页。
- `V2.6.0`：新增 C2000Pro 机型识别与最小应用商店兼容层。
- `V2.5.0`：哈基米依赖检查修复、封版摘要和封版工具箱。
- `V2.3.0`：PicoClaw / 鲲鹏小龙虾接入扩展盘迁移与还原链。
- `V2.2.5`：OpenClash iframe 黑屏兜底、原版页面顶层跳转、六标签保留、OEM 顶栏隐藏和半屏修复。
- `V2.2.0`：C2000MAX 应用商店系统状态卡补入 swap 虚拟内存显示。
- `V2.1.5`：C5800-650 / HC-WT9120 支持、NROS 2.x 口径放行、应用商店缺失启动阻断。
- `V2.1.0`：Docker 扩展盘安装链接入、C8/C5800 rootfs_2nd 落盘、Docker LuCI 页面、应用商店入口和卸载链接入。
- `V2.0.70`：5G 负载均衡权重设置、mwan3 运行态生效修复、OpenVPN Mk5 pass10、AdGuardHome 状态页精修、应用商店显示修复、C2000MAX 1 号卡白条修复和公网页粉色视觉精修。
- `V2.0.60`：C8/C5800 eMMC 存储扩展、OpenList 存储扩展断链修复、hybrid 应用还原、DDNS-GO 迁移权限修复、OpenClash ASN.mmdb 防丢失校验、C2000MAX swap 菜单限制。
- `V2.0.55`：统一体检增强、哈基米傻瓜分流助手、OpenList C2000MAX 风险提示和哈基米规则生效修复。
- `V2.0.50`：DDNS-GO 集成，OpenList C2000MAX 安装链降内存，应用商店和 AdGuardHome 页面重新美化，卸载链和校验链补强。
- `V2.0.40`：EasyTier / MosDNS 修复，AdGuardHome 内页重新美化并补齐监听和统计链路。
- `V2.0.35`：新增 MosDNS 插件。
- `V2.0.30`：雷神卸载残留清理。
- `V2.0.25`：应用商店原厂还原入口与版本头更新。
- `V2.0.20`：OpenVPN 控制台界面升级。
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
| `00-current/ssh-nradio-plugin-installer.sh` | V3.0.7 本地总脚本，已内嵌智能频段 v7 与 5G 连接监听 |
| `00-current/nradio-smart-band.sh` | 历史独立开发校验源；当前运行代码以总脚本内嵌 v7 为准，不是运行或发布依赖 |
| `40-server-web/mayebano-support/index.html` | V3.0.7 本地支持页入口 |
| `40-server-web/mayebano-support/AK68-798-SSH-2222.nr` | AK68-798 SSH 2222 配置恢复包 |
| `40-server-web/mayebano-support/nradio-ssh-manager.ipk` | C8-788 在 NRadio 应用商店本地安装的 SSH 管理包 |
| `40-server-web/mayebano-support/nradio-mesh.ipk` | NROS 应用商店本地安装的 Mesh 组网包 |
| `40-server-web/mayebano-support/nradio-qos-pro.ipk` | NROS 应用商店本地安装的 QoS 限速包 |
| `40-server-web/mayebano-support/ai_studio_code.html` | 历史支持页源稿，仍保留 V2.2.5 展示口径 |
| `40-server-web/mayebano-support/wechat-donate.png` | 微信支持图片 |
| `CHECKSUMS.txt` | 当前公开文件校验 |
| `CHANGELOG.md` | 版本记录 |
| `CONTRIBUTING.md` | 反馈和贡献说明 |
| `SECURITY.md` | 安全反馈 |

## 发布前校验

本地准备发布前，以下文件必须同步：

- `README.md`
- `CHANGELOG.md`
- `CHECKSUMS.txt`
- `.github/workflows/repo-check.yml`
- `vercel.json`
- `00-current/ssh-nradio-plugin-installer.sh`
- `40-server-web/mayebano-support/index.html`
- `40-server-web/mayebano-support/AK68-798-SSH-2222.nr`
- `40-server-web/mayebano-support/nradio-ssh-manager.ipk`
- `40-server-web/mayebano-support/nradio-mesh.ipk`
- `40-server-web/mayebano-support/nradio-qos-pro.ipk`

建议本地先跑：

```sh
git diff --check -- README.md CHANGELOG.md CHECKSUMS.txt .github/workflows/repo-check.yml 00-current/ssh-nradio-plugin-installer.sh 40-server-web/mayebano-support/index.html
sh -n 00-current/ssh-nradio-plugin-installer.sh
bash -n 00-current/ssh-nradio-plugin-installer.sh
```

`CHECKSUMS.txt` 记录 V3.0.7 发布文件；独立 `nradio-smart-band.sh` 不进入发布文件清单。发布前重新核对总脚本、支持页、AK68-798 SSH 配置包、三个插件 IPK 和 `vercel.json` 的 hash 与大小。

## 脚本校验

当前脚本：

```text
SHA256  a4694700e6ff23d8f39be6e197c0836b780978546d751761258e20d1033cb99c
Bytes   2757647
Path    00-current/ssh-nradio-plugin-installer.sh
```

更多校验值见 [CHECKSUMS.txt](CHECKSUMS.txt)。

## 反馈

- 反馈问题前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 安全相关反馈请阅读 [SECURITY.md](SECURITY.md)。
- 提交 issue 时不要公开 root 密码、Cookie、SSH 地址、私有密钥或完整现场备份。

## 开源许可证

本项目使用 [MIT License](LICENSE) 开源。
