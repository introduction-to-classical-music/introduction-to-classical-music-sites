# Windows 长路径说明（clone / checkout / status / add）

本仓库包含 `site/` 下的静态站点归档，其中 `site/current`、`site/v0.1.0` 的 `library-assets` 使用深层目录 + 中文资产名，部分路径 **超过 Windows 传统 `MAX_PATH`（260 字符）**。在 Windows 上 clone、checkout、`git status`、`git add`/`commit`、PowerShell 文件遍历等操作可能遇到 `Filename too long` 或文件缺失。

## 当前实测（2026-11-17）

仓库：`repositories/site-deploy/introduction-to-classical-music-site-deploy`（工作树 HEAD `c7c26e2` 时测量）

| 指标 | 值 | 说明 |
|---|---|---|
| 最长 tracked 路径（字符数） | **161 字符** | `site/current/library-assets/managed/people/person-symphonieorchester-des-bayerischen-rundfunks/...jpg`（repo 相对） |
| 最长 tracked 路径（UTF-8 字节数） | **217 字节**（121 字符） | `.../person-叶夫根尼亚历山德罗维奇穆拉文斯基/...jpg`（中文名放大字节数） |
| `git ls-files` 默认转义显示长度 | **约 459 字符** | Git 默认 `core.quotepath=true` 会把中文转义为 `\346\217\266...`，是**显示长度**，不是真实路径长度 |
| 当前本机 clone 下最长绝对路径 | **284 字符** | clone 根目录 122 字符 + 161 字符 repo 相对路径 + 1 分隔符 |
| `site/current` 绝对路径 >260 的文件数 | **3**（本机 clone） | 若 clone 根目录更短则可能不超限 |
| 超限阈值 | clone 根目录长度 **> 98 字符** | 122 + 1 + 161 = 284 > 260；每缩短/加深 1 字符，最长绝对路径同步变化 |
| 本机 OS 长路径策略 | `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1` | Windows 原生长路径支持已开启 |

> 注意：仓库内部讨论中“约 459 字符”指上表 **Git 转义显示长度**；决定是否超 `MAX_PATH` 的是**真实绝对路径长度**（取决于 clone 根目录，见上表）。

## 必需配置：`core.longpaths=true`

- 本仓库**本地配置已由 root 设置**：`core.longpaths=true`（`git config --get core.longpaths` 返回 `true`）。
- 该配置**不是**仓库内容（不会随 clone 传播）；**每个新 clone** 都必须自行配置（本仓库或全局）：
  ```powershell
  # 在仓库内配置（推荐，仅影响本仓库）
  git config core.longpaths true
  # 或全局配置（影响该用户所有仓库）
  git config --global core.longpaths true
  ```
- 校验：
  ```powershell
  git config --get core.longpaths        # 期望 true
  ```
  ```powershell
  # 若 clone/checkout 已完成但文件缺失，先确认是否因长度失败：
  git status --porcelain                 # 期望 clean；异常时检查 "Filename too long"
  ```

## 路径长度校验命令

PowerShell（测量 `site/current` 当前工作树绝对/相对路径）：

```powershell
$root = (Get-Location).Path
$files = Get-ChildItem -LiteralPath "site/current" -Recurse -File
$items = $files | ForEach-Object {
  [pscustomobject]@{
    Abs = $_.FullName.Length
    Rel = ($_.FullName.Substring($root.Length).TrimStart('\','/')).Length
    Path = $_.FullName
  }
}
$items | Sort-Object Abs -Descending | Select-Object -First 5
"clone_root_len=$($root.Length)"
"threshold_root_len_for_260=$((260 - 1 - 161))"   # 161 = 当前最长 repo 相对路径
```

Git 原始路径长度（避免 quotepath 转义干扰）：

```powershell
# 原始字符长度（Windows PowerShell 5.1；PS7 亦可用）
git -c core.quotepath=false ls-files | ForEach-Object { [pscustomobject]@{ Len = $_.Length; Path = $_ } } |
  Sort-Object Len -Descending | Select-Object -First 5
```

```bash
# Git-Bash 等价（按字符/字节查看）
git -c core.quotepath=false ls-files -z | tr '\0' '\n' | awk '{ print length, $0 }' | sort -rn | head -5
```

验收/发布前建议至少执行：`git status --porcelain`、`git add -A --dry-run`、`git ls-files | Measure-Object`，确认无 `Filename too long` 且文件数与预期一致（当前 `site/current` 569 files）。

## 可执行长路径守卫（`scripts/check-long-paths.ps1`，W9b / C-F21）

仓库已接入可执行守卫，防止长路径继续恶化。它用 `git ls-tree -r -z --name-only HEAD` 读取**真实 UTF-8 路径**（NUL 分隔，不经过 Git C-quote 转义），计算每条 tracked 文件的**绝对 Windows 路径长度**，只读、不重命名任何文件。

```powershell
# 本机/CI 直接运行（默认阈值 240，上限 260）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-long-paths.ps1

# 机器可读（CI/证据）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-long-paths.ps1 -Json
```

输出示例（本机 canonical clone，root=122 字符）：

```text
tracked=1161 max=284 overThreshold(240)=23 overLimit(260)=6 core.longpaths=true
acceptedBaseline: overLimit=6 max=284 longPaths=6 matched=6 newOverLimit=0
RESULT: PASS (accepted baseline not exceeded; no new >= 260 paths)
```

**Accepted baseline（审查 C-F21 登记）**：6 条 tracked 路径 ≥260、max=284。这 6 条是 `site/current` 与 `site/v0.1.0` 下同名 legacy 人物图（`person-symphonieorchester-des-bayerischen-rundfunks`、`person-bremen-philharmonisches-staatsorchester`、`person-rundfunk-sinfonieorchester-berlin`）；守卫内置这 6 条相对路径白名单。

失败条件（任一成立即 exit 1）：

- 出现**不在 accepted 白名单内**的 ≥260 路径（含重命名后新增/变长路径）；
- `max absolute length > 284`（即使路径都在白名单内，clone 根过长也会 fail 提示根目录过深）；
- `overLimit(260) > 6`。

更低阈值（240）只警告、不失败；低于上限时正常 PASS。因为长度是绝对路径，**同一 commit 在更短的 clone 根（如 CI windows-latest）下计数只会更低**，不会误报；accepted baseline 是上界而非固定值。CI 已在 `windows-latest` 的 `site-release-check.yml` 中加入该步骤（checkout 后、回归测试前）。

## 限制与兼容性

- **Git**：`core.longpaths=true` 后 Git for Windows 使用 `\\?\` 长路径 API；这是 clone/checkout/status/add 的主要前提。
- **OS**：部分工具仍需系统级 `LongPathsEnabled=1`（本机已开启）；未开启的机器即使 Git 配置也可能在其他工具上失败。
- **PowerShell/.NET**：Windows PowerShell 5.1 / .NET Framework 对长路径支持不一致，部分 cmdlet（如老版本 `Get-ChildItem`/`Copy-Item`、部分 `.NET` API）仍可能受 260 限制；脚本应使用 `-LiteralPath`，必要时先 `cd` 到较短的父目录或使用支持长路径的 API。
- **Node/7-Zip/robocopy**：现代 Node（`fs`）与 7-Zip/robocopy 通常支持长路径；`Expand-Archive`/`Compress-Archive` 在老环境上可能受限。
- **CI（GitHub Actions windows-latest）**：checkout 在工作目录展开仓库；若运行器未预置长路径配置，可能 checkout 失败。仓库的 CI 检查（`site-release-check.yml`）包含 `scripts/check-long-paths.ps1`（长路径预算守卫）与 `scripts/test-site-release.ps1`（回归测试，使用临时目录、不依赖 `site/current` 深路径）；若 checkout 出现长度问题，需在运行器/工作目录侧配置长路径或缩短工作目录。
- **短路径优先**：把仓库 clone 到较短的根目录（例如 `C:\src\site-deploy`）可显著降低超限概率（当前阈值：根目录 ≤98 字符时 161 字符最长路径不会超过 260）。

## 资产改名（D7 / W9b，留到内容更新窗口）

- 当前策略（D7-C）：**先** `core.longpaths=true` + 文档/校验，**不**在本轮重命名资产；改名会影响 `siteDigest`、站点 URL、官方库中的资产引用与已发布的 Pages 产物，必须与内容更新窗口一起做。
- 后续内容窗口可选方案：缩短 `library-assets` 目录/文件名（如统一 hash 命名）、或在库导出阶段做路径映射；执行前需更新官方库引用、重新导出、重新审计与 Pages 发布，并记录新的 `sourceDigest`/`siteDigest`。
- 在改名完成前，所有 Windows 维护者/CI 都必须遵守本文的 `core.longpaths` 配置与校验步骤。

## 相关文档

- 发布/审计/回滚流程：[release-workflow.md](release-workflow.md)
- 摘要语义（改资产会改变 digest）：[site-release-digest.md](site-release-digest.md)
- 最新发布记录：[releases/2026-11-17-v0.1.1-pages-w10.md](releases/2026-11-17-v0.1.1-pages-w10.md)
- PR 检查清单：[.github/pull_request_template.md](../.github/pull_request_template.md)
