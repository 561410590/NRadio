# Changelog

## V3.0.9 - 2026-09-11（本地更新）

- `5 > 3` 修复重复规则跳过重载，支持同域 HTTP 订阅下载策略同步。
- 域名分流增加加密 DNS 联动、缓存清理与重载生效核验。
- 支持页、下载命令、仓库文档与校验规则同步版本；网页下载统一使用 ghproxy.vip。
- Repository checks 更新 Mesh 包校验、下载链接及 SHA-256 清单；否定检查失败时中止，内嵌脚本检查使用独立临时目录。

## NRadio Mesh 1.20.1-2 - 2026-09-11（本地下载包更新）

- 网页配套包更新为 `luci-app-nradio-roaming_1.20.1-2_all.ipk`。
- 无线重载、换信道后恢复节点发现与重连，保留已授权名单。
- 完善 Q6000 级联组网、节点拓扑与连接状态诊断；无线互联按机型和驱动适配。

## V3.0.7 - 2026-09-07（正式发布）

- GitHub 资源下载加入 `gh-proxy.com` 优先与官方地址自动回退，覆盖哈基米、OpenList、EasyTier、MT5700 WebUI、Web SSH 等安装资源；下载进度改为实际传输进度，并支持断点续传。
- `NRadio_C2000Ultra` 接入 C2000MAX 的 SD 卡检测与 Swap 管理：默认创建 512 MiB，最大扩容至 2048 MiB；统一体检和应用商店同步显示 Swap 状态。
- MT5700 WebUI 的 C5800 适配按实际 `cpe / cpe1` 显示单线或双线，只有 `cpe1` 时使用对应连接；双线路详情、AT 与计划继续隔离。
- AdGuardHome 安装后统一路由器本机与局域网普通查询的 DNS 链，保留已有域名专用上游，并按实际配置变化重启对应服务。
- 更新应用商店 V3、插件弹窗、8080 原生 LuCI 总览、首页温度切换和 5G 连接监听。

## V3.0.6 - 2026-09-03（正式发布）

- 5G 连接监听改为路由器后台常驻服务，每 10 秒记录线路、网络、频段和基站变化；关闭 LuCI 页面后继续记录。
- 修复 LTE 频段被误标为 N 频段，4G 使用 B 前缀，5G NR 使用 N 前缀。
- 智能频段状态、只读预览、立即执行和日志并入 5G 连接监听 LuCI 页面；CLI 子菜单只保留安装或更新、卸载。
- C5800-688 页面新增智能频段可逆启停；停用后交还系统管理，可直接重新启用，连接监听保持运行。
- 设备维护菜单保持连续编号；连接监听支持 C5800-650、C5800-688 和 C2000MAX，智能频段仍仅支持 C5800-688。
- 删除安装结束后的重复终验，修复页面按钮拥挤；5G 连接监听组件更新到 `20260903-4`。
- 图文支持页、README、CHANGELOG、CHECKSUMS 与 Repository checks 已同步到 V3.0.6；`v3.0.6` 标签与 GitHub Release 已正式发布。

## NRadio Mesh 1.0.14 - 2026-09-02

- 支持页和固定下载包更新到 `luci-app-nradio-roaming_1.0.14-1_all.ipk`。
- 自动连接改为 5G 优先、同频信号强度排序；失败后继续尝试候选，最多 8 个。
- NRadio BSSID 候选识别扩展到 `F0/F2/F4/F6/F8/FA/FC/FE:83:C6` 地址族。
- 修复缺少 `join_backup / last_backup` UCI 项时恢复测试被 `set -e` 提前中断；插件 12 项测试与 IPK 审计通过。
- Repository checks 新增 Mesh 1.0.14 包名、版本、关键行为、权限和 Shell 语法检查。

## V3.0.5 - 2026-09-02（正式发布）

- 新增 `NRadio_C2000Ultra`，识别 `HC-WT9500 / HCMT7987-SNSD`；共用板号时优先按原始 model 区分 C2000 Ultra 与 C2000MAX，开放默认通用菜单并保留机型专属功能限制。
- 新增 `NRadio_AK68-798`，识别 `HC-WT9194 / HCMT7987-S256`，按 16 MiB NOR 轻量模式开放功能。
- `4 > 4` 增加 C2000Pro / AK68-798 轻量应用商店；完整应用商店美化和还原对两个轻量机型隐藏。
- AK68-798 开放 `5 > 10` 首页 CPU 温度显示和统一体检。
- 支持页新增 AK68-798 SSH 2222 恢复教程和 `AK68-798-SSH-2222.nr` 下载。
- Repository checks 新增配置包封装、gzip/tar、Dropbear 内容、SHA-256、网页链接、Vercel 路由和校验清单检查。

## NRadio QoS Pro 1.0.24 - 2026-08-31

- 支持页版本、包名与固定下载入口更新到 `luci-app-nradio-qos-pro_1.0.24-1_all.ipk`。
- 增加 VPN 站点与 mwan3 排除集合联动，覆盖启停、VPN 路由事件和后台同步；同步失败有可见诊断，独立 VPN 恢复保留 tc 队列。
- 根据用户提供的 C8-788 实机输出适配 `eth3` 和原厂双栈全宽 mark 分类顺序，恢复时保留缺失的硬件加速配置项。
- 合并 1.0.21–1.0.23 的 C8-688 分类修复、IPv6 多地址跟踪、队列稳定性、页面草稿保护与请求超时处理。
- 本地回归与包校验通过；本次发布不等于实机限速或 VPN 连通性验收。总脚本保持 V3.0.0。

## V3.0.0 - 2026-08-30（本地构建）

- 支持页新增“NROS上开发的插件”区域，介绍 SSH 开启、Mesh 组网和 QoS 限速插件，并提供三个 IPK 下载地址。
- TTYD / Web SSH 下载对过期证书环境使用 curl `-k`、wget/uclient-fetch `--no-check-certificate`，删除旧 ttyd 文件所有权拦截和安装尾部失败式校验。
- TTYD / Web SSH 默认免登录：固定 `credential=0`，删除随机密码、用户名密码配置及 `--credential` 启动参数。
- `5 > 11` 更新为仅限 `NRadio_C5800-650 / C5800-688` 的“5G 连接监听”，提供安装或更新与原厂恢复式卸载。
- 本地脚本、支持页、README、CHANGELOG、CHECKSUMS 与 Repository checks 同步到 `V3.0.0 / 2026-08-30`；公开正式 Release 仍为 2026-08-29。

## V3.0.0 - 2026-08-29（正式发布）

- `SCRIPT_VERSION` 更新为 `V3.0.0`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-29`。
- 新增 `NRadio_C8-788`：识别 `HC-WT9302 / HCMT7987-NAND`，按小容量 NAND 受限配置开放 OpenClash、奇游/雷神、应用商店维护、统一体检、首页温度和风扇控制。
- 新增 `1 > 9 MT5700 WebUI V3.0.0`，安装 `semi-tcpweb` V3.0.0；NRadio 应用商店可打开和卸载，入口跳转 `/5700/`，不安装上游标准 LuCI 菜单包。
- 新增 `5 > 11 5G 连接优化安装或更新（全部 NROS）`，包含拨号与 SIM 日志、锁频执行修复、频段参数校验、SIM 切换互斥、蜂窝状态和基站切换时间线。
- 修复 5G 连接优化安装后未重启 `cpesel` 导致拨号日志不生成；页面区分日志缺失、读取失败和空日志状态。
- 新增 `4 > 3 OpenWrt 原版 LuCI（8080）`；首页 CPU/5G 温度、双 5G 显示、运营商与卡名修复继续使用独立菜单和文件。
- 修复 8080 安装链改变 NRadio 主站默认主题；安装结束恢复 `/luci-static/nradio`。
- 智能频段升级为 v7，读取频段前后核对当前 SIM；SIM 未知或切换中时拒绝执行频段控制。
- 修复智能频段 v7 运行文件缺少 `process_starttime()` 和 `ensure_runtime_dir()`。
- 兼容 NROS 2.2.12 应用商店手机保存按钮和固件接口差异，只补固件缺少的接口。
- 支持页加入 C8-788 SSH 管理 IPK 下载，明确必须在 NRadio 应用商店本地安装，不能使用隐藏链接开启 SSH。
- README、CHANGELOG、CHECKSUMS 与 Repository checks 已同步到 V3.0.0 / 2026-08-29；正式发布资产包含总脚本、C8-788 SSH 管理 IPK 和校验清单。

## V2.9.9 - 2026-08-20（正式发布）

- `SCRIPT_VERSION` 更新为 `V2.9.9`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-20`。
- 运营商与卡名兼容层升级为 `20260820-4`：NROS 2.2.12 固件原生 `sim_name` 优先，官方值为空时才回退精确 ICCID 映射；无有效 ICCID 时不跨页面持久化缓存。
- 同时兼容新固件 `format_isp_info(cpeinfo)` 状态对象与旧固件 `format_isp_info(simIsp, isp)` 双参数接口，覆盖新旧运营商字段和双卡显示。
- C2000MAX 应用商店 V3 首次收到 MAX 状态时自动展开系统状态并显示 Swap；用户手动折叠后，后续刷新不强制重开；非 MAX 默认行为不变。
- C2000MAX 已完成纯 SCP 上传和 `4 > 1` 应用商店 V3 五步重跑，`appcenter`、`uhttpd` 与实时 Swap 数据正常。
- 支持页、README、CHANGELOG、CHECKSUMS 和 Repository checks 同步到 V2.9.9；Repository checks 成功后发布同版本 tag 和 GitHub Release。

## V2.9.8 - 2026-08-17（本地构建）

- 补齐 OpenVPN DNS 清理与 C2000Pro Web SSH 变量，生成的通用卸载助手改为自包含事务链。
- 网页卸载控制器和卸载助手共用全局锁，并记录状态、退出码、日志、PID 与开始时间；异常退出和超时任务可自动收口。
- Docker 安装新增系统文件清单和校验算法；卸载只删除仍属于脚本且未被用户修改、未被其他软件包接管的文件，旧残留使用扩展盘原件安全比对。
- 下载链兼容 BusyBox/GNU wget 并自动回退 `uclient-fetch`；隐藏输入在正常退出和中断时恢复回显，诊断脱敏覆盖 URL、Header、JSON 和更多凭据字段。
- 智能频段当前运行代码为总脚本内嵌 v7；独立 `nradio-smart-band.sh` 不属于运行或公开发布依赖。

## V2.9.5 - 2026-08-13（正式发布）

- `SCRIPT_VERSION` 更新为 `V2.9.5`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-13`。
- 修复应用商店 V3 共享接入链：V3 模板按 UCI `luci_module_route` 校验，旧版原厂模板继续使用 fallback 注入，避免 OpenClash 及其他插件在应用商店接入阶段误报缺少打开路由。
- OpenClash 安装依赖与 NRadio 定制内核、官方 `luci-app-openclash` IPK 依赖对齐，移除 `kmod-inet-diag`、`kmod-nft-tproxy` 安装必死点。
- 智能频段、奇游、雷神、MosDNS、DDNS-GO 与 ttyd 撤除固定 MD5/SHA256 安装门禁；保留 shell 语法、压缩包、IPK 和二进制实际可用性检查。
- 撤除应用商店事务目录、通用 `.bak`、OpenClash 自定义规则、5G 聚合、WebSSH 与 Docker 的持久备份写入；应用商店美化和还原直接执行。
- 支持页同步 `V2.9.5 / 2026-08-13`，即将支持机型更新为 `NRadio_N5000`；手机首屏改为五等分完整导航、双按钮同行、双列标签和双列版本面板。
- 支持页安全准则改为仅限 NROS 2.x，并明确这是 SSH 脚本、不是应用商店安装包，禁止在应用商店安装。
- README、CHANGELOG、CHECKSUMS 与仓库检查规则同步发布；本版本进入 GitHub `main`，并由 `v2.9.5` Release 正式提供总脚本与校验清单。

## V2.8.5 - 2026-08-10

- `SCRIPT_VERSION` 更新为 `V2.8.5`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-10`。
- 完整 `nradio-smart-band v5` 源码内嵌总脚本，运行和发布不再依赖旁置文件；总脚本释放前执行 shell 语法与固定 SHA256 校验，再原子写入 `/root/nradio-smart-band.sh`。
- 新增 `5 > 8 智能频段管理（C5800-688）`，提供安装或更新、状态、只读模拟、立即执行、运行日志和卸载；cron 任务去重写入并纳入原有配置备份链。
- `5 > 1` 统一体检加入智能频段脚本权限、语法、v5 SHA256、cron 唯一性、准确任务行和只读状态检查。
- 智能频段策略升级为联网健康优先：健康 N28/N41 仅记录；IPv4 连续 3 次失败后先执行 DHCP/ifup 软恢复，CFUN 仅作带 12 小时冷却和 24 小时次数限制的最终手段；IPv6 异常不单独触发 CFUN。
- 支持页同步 V2.8.5，新增单一总脚本和智能频段摘要、历史版本折叠、可靠复制反馈、键盘焦点、阅读进度、减少动态效果和移动端导航适配。
- 2026-08-11 支持页新增 `NRadio_C2000Ultra` 与后续更名为 `NRadio_N5000` 的“即将支持、暂未适配”预告卡片，并明确两款尚未加入总脚本识别与功能放行。
- README、CHANGELOG、CHECKSUMS 与仓库检查规则已同步；工作流直接提取并验证总脚本内嵌 v5，不再把独立智能频段脚本列为公开发布依赖。
- 总脚本、网页和仓库资料已同步至 GitHub `main`，并纳入 `v2.8.5` 正式发布。

## V2.8.0 - 2026-08-03

- `SCRIPT_VERSION` 更新为 `V2.8.0`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-03`。
- 修复 `shell_quote()` 的单引号转义；OpenVPN 与 EasyTier 状态文件加入 `NRADIO_STATE_FORMAT='2'`，主脚本、内嵌卸载脚本和生成的 EasyTier 路由脚本均拒绝加载旧版无标记状态文件。
- 下载、GitHub API、CDN 探测、EasyTier 状态查询及集成下载链移除 `curl -k`、`--insecure` 和 `wget --no-check-certificate`，恢复 TLS 证书校验。
- `ensure_opkg_update()` 失败时显式返回 1；OpenClash、MosDNS、DDNS-GO、ZeroTier、EasyTier、奇游和雷神等 8 个调用点失败即停止对应安装。
- 保留奇游和雷神入口脚本的固定 SHA256 与执行前校验。
- 本地总脚本、支持页、README、CHANGELOG、CHECKSUMS 与仓库检查规则同步到 V2.8.0。
- C5800-688 已直接运行 `5 > 1` 统一体检：26 PASS、2 WARN、0 FAIL、4 SKIP；OpenClash、AdGuardHome、OpenVPN 和默认路由等核心项目通过。
- 本版本当前只在本地完成同步与验证；GitHub Release 和公网仍为 V2.7.5。

## V2.7.5 - 2026-08-02

- `SCRIPT_VERSION` 更新为 `V2.7.5`，`SCRIPT_RELEASE_DATE` 更新为 `2026-08-02`。
- 完成新固件 FanControl ROM 保护收口：固件已内置 controller、CBI、`temperature_ajax.htm` 或 `temperature.htm` 时，同时跳过内容写入和 `chmod`，避免 OverlayFS 将 ROM 文件 copy-up 到 upper。
- FanControl ROM 判断位于 `NRadio_C8-688` / `NRadio_C2000MAX` 共用写入链，两种机型使用相同保护逻辑；脚本自建的美化模板、配置和服务文件仍正常写入与设置权限。
- 保留 OpenClash `v0.47.133` 新 LuCI 调试日志页兼容：空状态提示、生成日志后的状态更新、六标签页注入、iframe 黑屏兜底和原版页面顶层跳转继续进入安装校验链。
- 新增独立维护脚本 `00-current/nradio-smart-band.sh` v3：跳过已禁用蜂窝接口、清理旧重试状态、使用 2 小时冷却与 12 小时重试窗口、记录实时 band/频率/带宽，并增加并发锁和原子状态写入。
- C5800-688（HC-WT9126、NROS `2.2.8.n0.c0`）已完成智能频段脚本现场验证：禁用 `cpe` 不再重启，启用 `cpe1` 保持 NR N1，默认路由不中断。
- 同步总脚本、智能频段脚本、网页、README、CHANGELOG、CHECKSUMS 与仓库检查规则；线上状态以 GitHub Release 与公网实测为准。

## V2.7.0 - 2026-07-31

- `SCRIPT_VERSION` 更新为 `V2.7.0`，`SCRIPT_RELEASE_DATE` 更新为 `2026-07-31`。
- 适配 C2000MAX NROS `2.2.8.n0.c1` 固件内置 FanControl LuCI 文件。
- `write_fanctrl_plugin_files()` 检测 `/rom` 中的 controller、CBI、`temperature_ajax.htm` 和 `temperature.htm`；ROM 已存在时不再用 heredoc 覆盖。
- 继续生成固件缺失的 `polish.htm`、后台服务、UCI 配置和 init 脚本，保持风扇页面与温控策略可用。

## V2.6.5 - 2026-07-23

- `SCRIPT_VERSION` 更新为 `V2.6.5`，`SCRIPT_RELEASE_DATE` 更新为 `2026-07-23`。
- OpenWrt 21.02.7 活跃 feed 从不可用的清华源切换为阿里云源，镜像优先级调整为阿里云、OpenWrt 官方、清华备用。
- 适配 OpenClash `v0.47.133` 新增的 `Debug Logs` 标签：未生成日志时显示明确空状态，点击 `Generate Logs` 后刷新提示状态。
- OpenClash 原版页面继续保留六标签页、OEM 顶栏隐藏和全宽页面修复。

## V2.6.0 - 2026-06-15

- `SCRIPT_VERSION` 更新为 `V2.6.0`，`SCRIPT_RELEASE_DATE` 更新为 `2026-06-15`。
- 新增 `NRadio_C2000Pro` 识别，覆盖 UDX710 / RG200U-CN 身份映射与 NROS `2.1.8.n0.c1`。
- 新增 C2000Pro 应用商店兼容层，提供最小 appcenter UCI、controller、模板、插件卡片、iframe、卸载动作和系统状态接口。
- C2000Pro 不套用 C2000MAX 存储卡、C8/C5800 `rootfs_2nd`、风扇和 5G 聚合逻辑；启动时显示专属资源与刷机风险提示。

## V2.5.0 - 2026-06-14

- `SCRIPT_VERSION` 更新为 `V2.5.0`，`SCRIPT_RELEASE_DATE` 更新为 `2026-06-14`。
- `5 > 6` 新增哈基米 / OpenClash 依赖检查修复，覆盖配置、服务、核心、`ASN.mmdb` 和 `Model.bin`。
- `5 > 1` 统一体检增加封版摘要、备份清单和动作日志摘要。
- 新增 `5 > 7` 封版工具箱，支持导出脱敏诊断报告、查看备份清单和动作日志。
- 写入型菜单动作记录到 `/root/.nradio-plugin-menu/action-history.log`，保留最近约 300 行且不记录密码和敏感 URL。

## V2.3.0 - 2026-06-13

- `SCRIPT_VERSION` 更新为 `V2.3.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-13`。
- PicoClaw / 鲲鹏小龙虾接入 C8/C5800 `rootfs_2nd` 应用迁移与还原链。
- `5 > 4 > 5` 迁移和 `5 > 4 > 6` 还原新增 `/usr/bin/picoclaw`、`/usr/bin/picoclaw-launcher`、`/.picoclaw`。
- 迁移复用现有 `nradio-apps` 软链记录、服务停启、运行文件校验和还原流程。
- 公网页同步 V2.3.0 当前版本口径，并在页脚标注因为暂时没有 ChatGPT 会员，后续更新暂缓。

## V2.2.5 - 2026-06-09

- `SCRIPT_VERSION` 更新为 `V2.2.5`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-06-09`。
- OpenClash 应用商店 iframe 弹窗保留原有弹窗逻辑和六个官方标签页。
- OpenClash iframe 增加黑屏/空白兜底，可重载弹窗或顶层打开原版页面。
- “原版页面”按钮顶层跳转到 `/cgi-bin/luci/admin/services/openclash/client`。
- OpenClash 原版页面隐藏 OEM 顶栏、footer、首页、蜂窝、上网、Wi-Fi、终端和更多。
- OpenClash 原版页面修复固定高度导致的半屏显示问题。
- 公网页同步 V2.2.5 当前版本口径，并保留 V2.2.0、V2.1.5、V2.1.0 历史日志。

## V2.2.0 - 2026-06-04

- 应用商店系统状态卡新增 C2000MAX 识别。
- C2000MAX 显示 swap 虚拟内存总量、用量和百分比。
- 非 C2000MAX 隐藏 swap 指标；C2000MAX 未启用 swap 时显示“未启用”。

## V2.1.5 - 2026-05-29

- 新增 `NRadio_C5800-650` / `HC-WT9120` 识别。
- NROS `1.9.4.n0.c3` 按 C5800-650 机型放行。
- Docker / `rootfs_2nd` 扩展盘支持链补入 C5800-650。
- 缺 NRadio 应用商店环境时，启动层直接退出并提示缺失路径。

## V2.1.0 - 2026-05-28

- `SCRIPT_VERSION` 更新为 `V2.1.0`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-28`。
- Docker 加入常用插件安装菜单第 8 项，仅支持 `NRadio_C5800-688` / `NRadio_C8-688`。
- Docker 安装前要求已启用 `rootfs_2nd` eMMC 扩展盘，下载缓存、feed index、工作目录、IPK 缓存、手动解包目录、备份和 `data-root` 均固定在 `/mnt/rootfs_2nd_data/nradio-apps/docker`。
- Docker LuCI 页面写入 `nradioadv/system/docker`，应用商店入口、图标、状态接口和异步卸载链同步接入。
- Docker 安装链修复 overlay 打满和系统路径污染风险：大体积 Docker 二进制保留扩展盘软链，小依赖库复制到系统路径。
- 公网页同步 V2.1.0 版本口径，当前里程碑改为 Docker 扩展盘安装链接入，更新卡不重复展示 V2.1.0。

## V2.0.70 - 2026-05-19

- `SCRIPT_VERSION` 更新为 `V2.0.70`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-19`。
- 5G 负载均衡支持副 5G / 蜂窝权重设置，保存后自动提交并重启 `mwan3`，避免 UCI 已变但运行态仍停留在旧比例。
- 新增 C8/C5800 eMMC 存储扩展，支持 `rootfs_2nd` 扩展盘接入、应用迁移、应用还原和第二系统烧录保护。
- 补强应用还原：OpenClash / AdGuardHome 在 overlay 空间不足时可进入 hybrid 状态，保留扩展盘大项子链接并继续记录迁移状态，避免误删扩展盘真实内容。
- 修复 OpenList 在 C8/C5800 存储扩展后 `/mnt/app_data/openlist` 断链目标缺失导致安装失败的问题；安装链会识别符号链接并先创建扩展盘目标目录及 `bin/data/tmp`。
- 修复 DDNS-GO 迁移到扩展盘后以 `ddns-go` 用户启动失败的问题：存储扩展入口、迁移和还原流程会修正 `nradio-apps` 及目标父目录的可穿透权限。
- OpenClash 扩展盘迁移、还原和哈基米分流助手重载前新增 `ASN.mmdb` 有效性校验，避免缺失数据库时继续迁移或重载。
- OpenVPN 页面升级到 Mk5 深色玻璃界面，pass 7 / pass 8 / pass 9 / pass 10 精修已回写总脚本，并修复摘要卡、标题压缩、表单、日志、诊断区、弹窗层级和小屏溢出细节。
- AdGuardHome 状态页精修、应用商店 pass 3 至 pass 6 精修和 C5800 热更新结果已回写总脚本。
- 应用商店系统卡片内存显示改为短文本，OpenVPN 应用卡版本号显示短版本并保留完整 title。
- 修复 C2000MAX 应用商店 1 号应用卡 `::after` 背景选择器缺口，补齐 `3n+1 / 3n+2 / 3n+3` 同级覆盖。
- 公网页同步 V2.0.70 版本口径，并保留粉色主题视觉精修。
- 本地全量 bug 扫描收口：安装链移除 `base64` / `gzip` 依赖路径，OpenList / DDNS-GO 归档校验改为 tar 自检，MosDNS 解压前补齐 `unzip` 依赖兜底，应用商店 iframe 关闭与外层布局清洗链同步修复。
- 常用插件菜单中的扩容 swap 虚拟内存入口改为仅支持 `NRadio_C2000MAX`，菜单文案同步为“扩容 swap 虚拟内存（仅支持NRadio_C2000MAX）”。

## V2.0.55 - 2026-05-11

- `SCRIPT_VERSION` 更新为 `V2.0.55`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-11`。
- 设备维护与检测新增统一体检增强版，覆盖系统资源、安装前预检、插件健康矩阵、应用商店一致性、端口冲突、哈基米规则检查和脱敏摘要。
- 设备维护与检测新增哈基米傻瓜分流助手，读取当前 YAML 分流目标后，可按数字菜单把域名、IP 或网段写入哈基米自定义规则文件。
- 哈基米自定义规则固定写入 `/etc/openclash/custom/openclash_custom_rules.list`，避免订阅 YAML 更新覆盖用户规则。
- 修复相同哈基米规则已存在时未启用自定义规则开关的问题，确保已有规则也能生效。
- 修复 C2000MAX 工厂提取内容中 `etc/gcom/ncm.json` 的非法尾逗号。

## V2.0.50 - 2026-05-10

- `SCRIPT_VERSION` 更新为 `V2.0.50`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-10`。
- 新增 **DDNS-GO** 插件（常用插件菜单第 7 项），安装链覆盖下载校验、三件套安装、OEM 包装页、图标、应用商店注册、异步卸载链和虚拟内存接入。
- DDNS-GO 首次安装流程新增 Web 登录账号密码设置，启动服务前初始化并写入 `/etc/ddns-go/ddns-go-config.yaml`。
- 修复 `opkg print-architecture` 中 `noarch` 排在前面时导致 DDNS-GO 架构校验误判的问题。
- 补强 DDNS-GO 应用商店 `package_list` 路由校验，避免命中 package 主条目后误报 route mismatch。
- 补强应用商店异步卸载链：任务日志写入当前插件日志、同插件并发锁、opkg 锁等待和失败反馈。
- 修复 appcenter cfg 口径下旧路由清理、section 类型识别、DDNS-GO YAML user/password 补齐和权限一致性问题。
- 修复 C2000MAX 安装 OpenList 时下载包和解压目录占用 `/tmp` 的 OOM 风险：C2000MAX 自动改用 OpenList lite 包，并把下载包与解压目录放到存储卡临时目录。
- OpenList C2000MAX 下载失败兜底改为清理损坏续传临时文件后切换源或完整重下，避免坏 `.tmp` 反复参与续传。
- 公网页同步 V2.0.50 已发布口径，补入 DDNS-GO、应用商店卡片布局和 AdGuardHome 内页二次重新美化说明。

## V2.0.40 - 2026-05-08

- `SCRIPT_VERSION` 更新为 `V2.0.40`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-08`。
- 修复 EasyTier 应用商店卸载后路由规则残留，清理链覆盖 `priority 60 / 70 / 196`。
- 修复 MosDNS 同步器日志路径写死问题，改为读取 `mosdns.main.log_file`。
- 修复 MosDNS 下载后 SHA256 为空时仍可能放行的问题。
- AdGuardHome 应用商店内页重新美化，首页打开即可直接看到 DNS 查询和拦截统计数。
- AdGuardHome 内页新增本地运行态/监听回退，未填 `Dashboard API password` 时也能显示运行中、监听地址和端口。
- 安装链补入 AdGuardHome `dashboard_user / dashboard_password` 录入逻辑，便于直接读取 `3000` 原版仪表盘统计。
- 修复 AdGuardHome `base.lua` heredoc 中残留的 Linux 空设备重定向问题：`2>nul` 改为 `2>/dev/null`。
- 公网页同步到 V2.0.40 当前主线口径，并加入 AdGuardHome 内页重新美化说明。

## V2.0.35 - 2026-05-06

- `SCRIPT_VERSION` 更新为 `V2.0.35`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-06`。
- 新增 **MosDNS** 插件（常用插件菜单第 6 项）：轻量 DNS 分流，支持国内外上游 DNS 分流/缓存，UCI 配置页 + 保存自动同步 YAML + 日志页。
- 脚本内新增 MosDNS 完整安装链、卸载链、CDN 下载优化、自写进度条。
- 公网页同步 V2.0.35 版本口径，新增 MosDNS 说明。

## V2.0.30 - 2026-05-04

- `SCRIPT_VERSION` 更新为 `V2.0.30`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-04`。
- 雷神主卸载链在官方卸载脚本执行后继续无条件兜底清理。
- 雷神内置 `/usr/libexec/nradio-leigod-uninstall` 同步无条件兜底清理。
- 雷神卸载链补删 `/etc/config/acc_version.ini` 和 `/tmp/leigod-plugin-install.sh`。
- 实机验证确认应用商店卸载后无雷神二进制、init、配置、进程、监听端口、controller、view、icon 和 AppCenter 残留。
- 公网页同步 V2.0.30 雷神卸载残留清理说明，并保留 V2.0.25 / V2.0.20 历史更新卡。

## V2.0.25 - 2026-05-03

- `SCRIPT_VERSION` 更新为 `V2.0.25`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-03`。
- 应用商店与页面美化菜单保留“还原应用商店”入口。
- 还原功能直接写回脚本内置 C2000MAX 2.1.7 原厂 `appcenter.htm` / `appcenter.lua`。
- 该功能不读取旧备份目录，不覆盖 `/etc/config/appcenter`。
- 应用商店美化内部 CSS 与校验标记同步为 V2.0.25。
- 公网页同步 V2.0.25 应用商店恢复默认说明，并保留 V2.0.20 历史更新卡。

## V2.0.20 - 2026-05-02

- `SCRIPT_VERSION` 更新为 `V2.0.20`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-02`。
- OpenVPN 控制台界面升级，主页面删除“配置 / 认证 / 隧道 / 路由”四个冗余状态项。
- “实时校验”统一改为“目标检查”，“推荐动作”统一改为“可用操作”，“诊断工作区”统一改为“诊断”。
- 基础配置、高级配置、文件编辑和导入页面同步统一为暗色控制台风格。
- 二级页返回按钮统一为“返回控制台”，导入页“推荐”标签改为“模板”。
- 补齐 OpenVPN Mk3 CSS 精确覆盖块，确保安装输出使用当前本地 Mk3 美化版样式。
- 公网页同步 V2.0.20 OpenVPN 控制台界面升级说明，并继续保持粉色主题。

## V2.0.15 - 2026-05-01

- `SCRIPT_VERSION` 更新为 `V2.0.15`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-01`。
- 奇游联机宝安装前改为调用 `ensure_opkg_update`，复用哈基米的软件源检查和切换流程。
- 雷神加速器安装前改为调用 `ensure_opkg_update`，复用哈基米的软件源检查和切换流程。
- 如果软件源不是 OpenWrt 21.02.7 清华源，会先备份原配置并切换，再继续安装依赖。
- `opkg update` 失败提示统一指向 `/tmp/nradio-plugin-opkg.update.log`。
- 公网页同步 V2.0.15 奇游 / 雷神源切换说明。

## V2.0.10 - 2026-04-30

- `SCRIPT_VERSION` 更新为 `V2.0.10`。
- `SCRIPT_RELEASE_DATE` 保持 `2026-04-30`。
- 风扇控制页面新增定时策略开关，默认关闭，不影响现有用户配置。
- 定时策略支持开始时间、结束时间和定时期间模式，可选 `Close` / `Low` / `Medium` / `High` / `Smart`。
- 支持跨天时段，例如 `23:00` 到 `07:00`。
- 过热保护仍为最高优先级，定时模式不能覆盖保护逻辑。
- C8-688 / C2000MAX 继续保留各自的温度来源、检测间隔、Smart 最低风速和过热保护默认策略。
- 公网页同步 V2.0.10 风扇定时策略说明。

## V2.0.7 - 2026-04-30

- `SCRIPT_VERSION` 更新为 `V2.0.7`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-30`。
- 新增 `HC-WT9108` 机型识别，并映射为 `NRadio_C8-668`。
- 脚本首页支持机型文案加入 `NRadio_C8-668`。
- 风扇控制门禁保持不变，仍只开放 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 公网页同步 V2.0.7 版本口径，支持机型扩展为 5 款。

## V2.0.6 - 2026-04-29

- `SCRIPT_VERSION` 更新为 `V2.0.6`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-29`。
- 应用商店美化用户可见口径统一为“哈基米”，底层 OpenClash 路由保持原插件路径。
- 奇游联机宝状态查看在未安装场景下不再因缺少 `PKG_INFO` 触发 `set -e` 异常退出。
- 公网页同步 V2.0.6 版本口径、安装教程闭环和主要功能区布局。

## V2.0.5 - 2026-05-01

- `SCRIPT_VERSION` 更新为 `V2.0.5`。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-05-01`。
- 基于 V2.0.3 风扇控制增强继续发布，保留温度来源、Smart 最低风速、多段阈值、过热保护和检测间隔。
- OpenVPN 连接中枢 Mk2 美化热更新回写总脚本。
- OpenVPN 状态接口新增 `fast=1` 快速模式，首次打开跳过逐条远端探测，完整诊断随后自动补齐。
- OpenVPN 标准页、二级分类页和上传提示区补齐无障碍状态与视觉层。
- 公网页和定时发布 workflow 更新为 2026-05-01 发布口径。

## V2.0.2 - 2026-04-29

- `SCRIPT_VERSION` 更新为 `V2.0.2`。
- 应用商店 FanControl 打开路由统一为 `nradioadv/system/fanctrl`，并保留旧 `fanctrl_plus` 路由迁移逻辑。
- 奇游联机宝安装阶段号统一为 3 阶段，并记录入口脚本 SHA256。
- 雷神加速器安装阶段号统一为 3 阶段，记录官方脚本 SHA256，并对依赖安装失败给出明确提示。
- 应用商店美化修复层标记同步到 V2.0.2。

## V2.0.1 - 2026-04-28

- `SCRIPT_VERSION` 更新为 `V2.0.1`。
- 设备维护与检测中的风扇控制从仅支持 `NRadio_C8-688` 扩展为支持 `NRadio_C8-688` / `NRadio_C2000MAX`。
- 风扇控制菜单、安装提示和完成说明同步为 C8-688 / C2000MAX 口径。
- 独立风扇控制脚本标题同步为 `NRadio-C8-688/C2000MAX风扇控制插件脚本`。
- 应用商店美化修复层标记同步到 V2.0.1，避免正式脚本内部版本标记混淆。
- `SCRIPT_RELEASE_DATE` 更新为 `2026-04-29`。

## V2.0.0 - 2026-04-27

- 正式脚本切换为默认公开下载文件：`00-current/ssh-nradio-plugin-installer.sh`。
- `SCRIPT_VERSION` 固定为 `V2.0.0`。
- 主菜单改为 5 个功能分类。
- 奇游联机宝和雷神加速器并入正式菜单，取消“测试中”显示。
- 旧 beta 独立短下载入口从 `vercel.json` 移除。
- 公网页更新为单一 V2.0.0 下载入口。
- 支持页继续美化，首屏、下载面板和底部说明改为正式发布页口径。

验证记录：

- 公网支持页：`https://nradio.mayebano.shop/` 返回 `200`。
- 公网脚本：`https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh` 返回 `200`。
- 公网脚本版本行：`SCRIPT_VERSION="V2.0.0"`。
- 公网脚本中“测试中”出现次数：`0`。
- 旧 beta 短下载路由返回 `404`。

## V2.0.0-beta - 2026-04-27

- 交互式入口改为功能分类菜单。
- 新增“游戏加速器”分类。
- 奇游联机宝和雷神加速器并入总脚本，提供应用商店卡片、NRadio 包装页、状态读取和卸载链。
- 用户在 `NRadio_C2000MAX NROS2.1.8.n0.c1` 新设备上完成安装链路现场验证：
  - 奇游联机宝安装、状态读取和应用商店接入完成。
  - 雷神加速器安装、监听端口、服务启用和应用商店接入完成。
  - 应用商店美化 5 阶段执行完成。

## V1.60.5 - 2026-04-26

- 修复应用商店美化旧 CSS 残留。
- 补齐只读系统状态面板。
- 修复进度条占比、破图图标兜底和空描述隐藏。
- 继续保持应用商店外层布局、下载链、安装链和卸载链不变。

## V1.60.0 - 2026-04-26

- 新增“美化应用商店”独立功能。
- 应用卡片、状态徽标、后台标记、按钮和系统状态面板统一优化。
- 该功能独立执行，不自动跟随 2~8 插件安装链。

## V1.50.x - 2026-04

- V1.50.1：脚本插件卸载体验对齐原厂应用商店。
- V1.50.2：应用商店图标缓存刷新修复。
- V1.50.3：2~8 虚拟内存接入链修正。
- V1.50.4：ttyd / Web SSH 页面美化，并补上 14 号 C8-688 机型门禁。
- V1.50.5：OpenVPN Mk2 页面美化回写总脚本。

## Early V1.x

- V1.0.0 起形成 1~8 菜单基础闭环。
- 后续逐步加入 OEM 环境识别、OpenVPN 控制台、swap 管理、EasyTier、风扇控制和应用商店接入链路。
