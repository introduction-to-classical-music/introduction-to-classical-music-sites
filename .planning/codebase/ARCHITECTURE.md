# Architecture

**Analysis Date:** 2026-04-22

## Pattern Overview

**Overall:** 静态站点产物仓 + 脚本化发布流水线（artifact-repo + script-driven deployment）

**Key Characteristics:**
- 仓库不含站点源码，仅存放已构建静态文件，见 `README.md` 与 `site/`
- 通过 PowerShell 脚本完成“同步 -> 审计 -> 元文件生成 -> 上传 OSS -> 刷新 CDN”链路，见 `scripts/*.ps1`
- 版本目录与当前目录并存（`site/v0.1.0` 与 `site/current`），支持上线前对比与回滚

## Layers

**静态内容层:**
- Purpose: 承载对外可发布的 HTML/CSS/图片等静态内容
- Location: `site/current/`、`site/v0.1.0/`
- Contains: 页面目录（`composers/`、`recordings/`、`works/` 等）、资源目录（`_astro/`、`library-assets/`）
- Depends on: 外部静态站点构建产物（由其他仓库/工作区提供）
- Used by: 发布脚本层（上传与审计）

**发布编排层:**
- Purpose: 执行版本同步、发布前审计、元文件生成、上传与 CDN 刷新
- Location: `scripts/`
- Contains: `stage-site.ps1`、`audit-site.ps1`、`write-static-metadata.ps1`、`publish-oss.ps1`、`refresh-cdn.ps1`
- Depends on: PowerShell、`rg`、`ossutil`、`aliyun`、`site/` 目录
- Used by: 维护者手动执行，流程见 `docs/release-workflow.md`

**配置与文档层:**
- Purpose: 提供部署参数模板与操作规程
- Location: `config/`、`docs/`、`README.md`、`START_HERE.md`
- Contains: 示例 JSON、上线架构说明、发布步骤与边界约束
- Depends on: 实际环境参数（域名、Bucket、Endpoint）
- Used by: 发布编排层与协作者接手流程

## Data Flow

**静态站点发布流:**

1. 从外部来源目录读取版本站点（`scripts/stage-site.ps1` 的 `-SourceSitesRoot` 或 `ICM_SITE_SOURCE_ROOT`）
2. 同步到 `site/<version>` 与 `site/current`
3. 审计文本禁项（`localhost`、`127.0.0.1`、本地盘符路径等），见 `scripts/audit-site.ps1`
4. 生成 `robots.txt`、`sitemap.xml`、`404.html`，见 `scripts/write-static-metadata.ps1`
5. 通过 `ossutil` 上传到 OSS，见 `scripts/publish-oss.ps1`
6. 通过 `aliyun` CLI 刷新 CDN 缓存，见 `scripts/refresh-cdn.ps1`

**State Management:**
- 以文件系统状态为主：目录即状态（`site/current` 表示待发布快照，`site/v*` 表示版本归档）
- 构建元信息保存在 `site/*/.icm-build-meta.json`

## Key Abstractions

**版本快照（Release Snapshot）:**
- Purpose: 标识一个完整可发布站点版本
- Examples: `site/v0.1.0/`、`site/current/`
- Pattern: 双目录镜像（版本目录 + 当前目录）

**发布脚本命令面（Script Command Surface）:**
- Purpose: 将发布各阶段拆分成独立可重复命令
- Examples: `scripts/stage-site.ps1`、`scripts/publish-oss.ps1`
- Pattern: 参数化脚本 + 失败即中断（`$ErrorActionPreference = "Stop"`）

## Entry Points

**本地接手入口:**
- Location: `START_HERE.md`
- Triggers: 新维护者接手、首次部署准备
- Responsibilities: 给出阅读顺序与最小上线路径

**发布流水线入口:**
- Location: `docs/release-workflow.md`
- Triggers: 每次版本发布
- Responsibilities: 规定发布顺序与禁止事项

**执行入口（命令级）:**
- Location: `scripts/*.ps1`
- Triggers: 命令行调用
- Responsibilities: 分阶段实施同步、审计、生成、上传、刷新

## Error Handling

**Strategy:** 失败即终止（Fail Fast）

**Patterns:**
- 脚本统一使用 `$ErrorActionPreference = "Stop"`，在关键前置条件不满足时 `throw`
- 外部 CLI 执行后检查退出码并显式报错（如 `scripts/publish-oss.ps1`）

## Cross-Cutting Concerns

**Logging:** 控制台输出 + 审计失败文件日志（`logs/audit-site-<version>.log`）
**Validation:** 通过 `scripts/audit-site.ps1` 对站点文本执行规则扫描
**Authentication:** 不在仓库内实现；依赖本地 `ossutil`/`aliyun` 凭据配置

---

*Architecture analysis: 2026-04-22*
