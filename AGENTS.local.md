# 本机工作台（kyc 的 PC 专用）

本文件是这台机器的本地规程，与仓库根目录的 `AGENTS.md` 配套使用：流程纪律以
`AGENTS.md` 为准，硬件与路径事实以本文件为准。给 agent 的第一句话：
「先读 AGENTS.local.md 和 AGENTS.md，再开始。」

## 机器与角色

- 硬件：RX 580（Polaris/GCN，RADV 驱动）、CPU 6 核 6 线程、内存 16GB、Arch 系 Linux。
- 机主不写代码。agent 负责全部技术操作：构建、改码、测速、记录。
- 机主的儿子也会在这台机器上玩。游戏由机主启动和关闭，agent 绝不启停模拟器
  （沿 `AGENTS.md` 的规矩）；机主玩着的时候 agent 可以在旁边测，但保持轻量，
  一次只发一个调试请求，不做抓帧循环。

## 仓库关系

- 本仓库是 `kyc/Lichii`，工作分支 `tuned`。上游是 `zortos293/Lichii`（分支
  `nx2`），再上游是 `Djihads80/Eglantine`。
- 动手修任何问题之前，先按 `AGENTS.md` 的流程查上游（两个仓库的 PR、issue、
  未合并分支）有没有现成修复。有就移植，没有才自己写，不许猜。
- `tuned` 分支以官方 build 117（`bf4c42e2`）为基底，已经合入以下上游未合并的
  补丁，不要重复合并：
  - #756 Linux 冷内存标记改 MADV_COLD（治每隔几分钟冻 3–15 秒）
  - #259 缓冲区预刷 PREFLUSH（运行时开关，见下）
  - #463 纹理缓存不上传过期内存（时之笛城堡镇约 +20%）
  - #354 修时之笛在 AMD 上的发绿
  - 发布工作流已裁成只建 Linux x86_64（普通版与 PGO 版）

## 构建

- 一键构建：`tools/local/build.sh`。增量构建，目录 `build/local`，ccache 已开。
  首次全量构建很久（以小时计），之后增量以分钟计。
- 内存只有 16GB：链接阶段若被系统杀掉，用 `LICHII_JOBS=3 tools/local/build.sh`
  降并行重试。Qt 用系统 Qt 6；若装了 Qt 6.8.3 到家目录，设
  `QT_PREFIX=$HOME/Qt/6.8.3/gcc_64` 再构建。
- 依赖与 CI 的区别：本地构建关了更新检查（`ENABLE_UPDATE_CHECKER=OFF`），
  依赖清单以 `docs/Deps.md` 为准，CI 的 Ubuntu 清单在
  `.github/workflows/release-binaries.yml` 里可作对照。
- PGO 不在本地做。成品包走本 fork 的 GitHub Actions：推送 `tuned` 分支后手动
  触发 `release-binaries`（publish_release=true），产物是
  `lichii-linux-x86_64-pgo.AppImage` 和普通版。本地构建只用于迭代验证。

## 验证闭环（性能结论只认数据）

- 机主用 `tools/local/play.sh` 启动游戏，自带调试服务器
  `EDEN_NX2_DEBUG_SERVER=127.0.0.1:6545`。agent 通过
  `python3 tools/nx2/debug_mcp.py --server 127.0.0.1:6545 --call '{"method":"frame_times","params":{"seconds":30}}'`
  拿帧时间，用 `status`、`log_tail`、`screenshot` 辅助。全套方法见
  `docs/nx2/debug-mcp.md`。
- 每个优化结论必须给出改动前后的 frame_times 数据（同一游戏、同一场景、
  各至少 30 秒）。不许用「感觉更流畅」交差。
- A/B 对照优先用现成的 `EDEN_NX2_*` 实验开关和 `EDEN_NX2_REJECT_HASH`
  （用法见 `AGENTS.md` 的调试工具表），不用为每个想法重编一版。拒绝过的
  着色器在收工前必须全部恢复。
- `#259` 的 PREFLUSH 就是这类开关：启动时设 `EDEN_NX2_PREFLUSH=1` 才生效。
  测它时开、不测时关，两组数据都要留。
- 日志在模拟器的日志目录（`eden_log.txt`），里面有 `Nx2Perf` 统计行，
  先读日志再动手。

## 本机硬件铁律

- Polaris 没有协作矩阵单元，也没有网格着色器硬件。凡涉及 HMMA/张量、
  mesh shader 的上游结论（多为 RDNA 或 NVIDIA 实测）在本机一律不成立，
  只能以本机实测为准。相关路径在本机走的是软件 HMMA 与计算管线模拟
  （#174、#569 已合入基底）。
- RADV 的 ACO 编译器本身就快。上游的编译卡顿类修复（预热、快速首建等）
  在本机的收益先量化再引用，不许照搬 NVIDIA 数字。
- 显存与内存都紧：不要开全量管线预加载（`EDEN_NX2_PRELOAD_ALL_PIPELINES`
  类策略），ASTC 纹理保留 RGBA8 的显存代价在本机要盯住。

## 交付

- 流程：本地改码 → `tools/local/build.sh` 构建通过 → 机主实测或 agent 经
  调试服务器测得数据 → 提交到 `tuned` 分支 → 需要成品包时触发 Actions。
- 实验开关默认关。验证无效的想法直接删掉，不留在分支里。
- 提交信息写清：游戏、症状、改动、前后帧时间。一行说不完就写正文，
  参照 `tuned` 分支已有提交的写法。
