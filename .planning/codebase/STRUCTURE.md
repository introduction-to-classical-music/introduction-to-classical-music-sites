# Codebase Structure

**Analysis Date:** 2026-04-22

## Directory Layout

```text
introduction-to-classical-music-sites/
├── site/            # 静态站点产物（current + 按版本归档）
├── scripts/         # 发布、审计与元文件生成脚本（PowerShell）
├── config/          # 部署参数模板（example JSON）
├── docs/            # 上线方案与发布流程文档
├── .planning/       # GSD 规划与代码地图产物
├── README.md        # 仓库边界与常用命令
└── START_HERE.md    # 接手入口文档
```

## Directory Purposes

**site/:**
- Purpose: 保存可直接部署的静态站点文件
- Contains: `current/`、`v0.1.0/`、HTML 页面树、`_astro` 样式资源、`library-assets` 图片资源
- Key files: `site/current/index.html`、`site/current/sitemap.xml`、`site/current/.icm-build-meta.json`

**scripts/:**
- Purpose: 把上线链路拆分为可单独执行的脚本
- Contains: 版本同步、审计、元信息生成、OSS 上传、CDN 刷新脚本
- Key files: `scripts/stage-site.ps1`、`scripts/audit-site.ps1`、`scripts/write-static-metadata.ps1`、`scripts/publish-oss.ps1`、`scripts/refresh-cdn.ps1`

**config/:**
- Purpose: 承载配置模板，避免把真实配置写入仓库
- Contains: 阿里云部署模板、站点发布模板
- Key files: `config/alicloud-deploy.example.json`、`config/site-release.example.json`

**docs/:**
- Purpose: 提供部署方案、发布顺序与运维建议
- Contains: `OSS + CDN` 方案、发布工作流
- Key files: `docs/alicloud-oss-cdn-plan.md`、`docs/release-workflow.md`

**.planning/codebase/:**
- Purpose: 存放代码库映射文档供后续 GSD 命令消费
- Contains: `STACK.md`、`INTEGRATIONS.md`、`ARCHITECTURE.md`、`STRUCTURE.md`
- Key files: `.planning/codebase/STACK.md`、`.planning/codebase/ARCHITECTURE.md`

## Key File Locations

**Entry Points:**
- `README.md`: 仓库范围与常用命令总入口
- `START_HERE.md`: 新维护者接手顺序
- `scripts/stage-site.ps1`: 发布流水线起点（导入站点）

**Configuration:**
- `config/alicloud-deploy.example.json`: OSS/CDN 部署参数模板
- `config/site-release.example.json`: 站点发布参数模板

**Core Logic:**
- `scripts/audit-site.ps1`: 上线前内容审计
- `scripts/write-static-metadata.ps1`: 生成 `robots.txt`、`sitemap.xml`、`404.html`
- `scripts/publish-oss.ps1`: 上传站点到 OSS
- `scripts/refresh-cdn.ps1`: 刷新 CDN 缓存

**Testing:**
- Not detected（仓库无自动化测试目录与测试配置）

## Naming Conventions

**Files:**
- 脚本文件使用 kebab-case：`stage-site.ps1`、`publish-oss.ps1`
- 文档文件使用 kebab-case 或大写固定名：`release-workflow.md`、`README.md`
- 站点页面入口统一 `index.html`：如 `site/current/about/index.html`

**Directories:**
- 站点实体目录按语义复数命名：`composers/`、`works/`、`recordings/`
- 版本目录使用 `v<semver>` 形式：`site/v0.1.0`
- 当前发布目录固定为 `site/current`

## Where to Add New Code

**New Feature:**
- Primary code: 若是部署流程增强，放在 `scripts/`；若是流程文档，放在 `docs/`
- Tests: Not applicable（当前仓库未建立测试基线）

**New Component/Module:**
- Implementation: 新增发布脚本放 `scripts/`，命名遵循 `<verb>-<target>.ps1`

**Utilities:**
- Shared helpers: 当前未抽出共享模块；若脚本逻辑复用变多，优先在 `scripts/` 新增通用 `.ps1` helper 文件并由主脚本调用

## Special Directories

**site/current:**
- Purpose: 当前准备上线的发布快照
- Generated: Yes（由外部构建产物同步而来）
- Committed: Yes

**site/v0.1.0:**
- Purpose: 历史版本归档
- Generated: Yes
- Committed: Yes

**site/current/_astro:**
- Purpose: 构建产物的静态资源目录（样式/可能的脚本 chunk）
- Generated: Yes
- Committed: Yes

---

*Structure analysis: 2026-04-22*
