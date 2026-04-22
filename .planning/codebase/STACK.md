# Technology Stack

**Analysis Date:** 2026-04-22

## Languages

**Primary:**
- HTML - 用于静态站点页面产物，位于 `site/current/**/*.html` 与 `site/v0.1.0/**/*.html`
- PowerShell - 用于发布与审计自动化脚本，位于 `scripts/*.ps1`

**Secondary:**
- CSS - 编译后样式资源，位于 `site/current/_astro/*.css` 与 `site/v0.1.0/_astro/*.css`
- JavaScript - 内联交互脚本嵌入 HTML，位于 `site/current/index.html`、`site/current/about/index.html` 等页面
- JSON - 部署配置模板与构建元信息，位于 `config/*.example.json`、`site/current/.icm-build-meta.json`

## Runtime

**Environment:**
- PowerShell（版本未在仓库内锁定）- 运行 `scripts/*.ps1`
- 静态 HTTP 服务环境（Nginx/OSS 静态托管/CDN 回源均可）- 承载 `site/current` 或 `site/<version>`

**Package Manager:**
- Not detected（仓库未检测到 `package.json`、`requirements.txt`、`go.mod`、`Cargo.toml`）
- Lockfile: missing

## Frameworks

**Core:**
- 静态站点产物仓模式（无应用运行时代码）- 仓库只保存已构建站点与发布脚本，见 `README.md`
- Astro（推断，版本未检测）- 由 `_astro` 目录与资源命名特征推断，见 `site/current/_astro/`

**Testing:**
- Not detected（无 Jest/Vitest/Pytest/Go test 配置）

**Build/Dev:**
- ripgrep (`rg`) - 由 `scripts/audit-site.ps1` 调用用于违规内容扫描
- ossutil CLI - 由 `scripts/publish-oss.ps1` 调用用于上传 OSS
- aliyun CLI - 由 `scripts/refresh-cdn.ps1` 调用用于刷新 CDN

## Key Dependencies

**Critical:**
- `ossutil`（外部 CLI）- 把 `site/<version>` 递归上传到 OSS，见 `scripts/publish-oss.ps1`
- `aliyun`（外部 CLI）- 调用 `cdn RefreshObjectCaches` 刷新缓存，见 `scripts/refresh-cdn.ps1`
- `rg`（外部 CLI）- 审计 `localhost`、本地路径、测试标记等发布禁项，见 `scripts/audit-site.ps1`

**Infrastructure:**
- 阿里云 OSS - 静态文件托管目标，见 `docs/alicloud-oss-cdn-plan.md`
- 阿里云 CDN - 对外分发与缓存加速层，见 `docs/alicloud-oss-cdn-plan.md`

## Configuration

**Environment:**
- 站点来源根目录通过参数 `-SourceSitesRoot` 或环境变量 `ICM_SITE_SOURCE_ROOT` 注入，见 `scripts/stage-site.ps1`
- OSS 上传需要 `-Bucket` 与 `-Endpoint`，见 `scripts/publish-oss.ps1`
- CDN 刷新需要 `-Domain` 与 `-Paths`，见 `scripts/refresh-cdn.ps1`
- 配置模板位于 `config/alicloud-deploy.example.json` 与 `config/site-release.example.json`

**Build:**
- 无本仓构建配置；仓库不负责从源码构建，只接收构建后静态产物，见 `README.md`
- 发布期元文件由 `scripts/write-static-metadata.ps1` 生成：`robots.txt`、`sitemap.xml`、`404.html`

## Platform Requirements

**Development:**
- 能执行 PowerShell 脚本的环境
- 可访问阿里云并已配置 `ossutil`/`aliyun` 凭据（用于上线阶段）
- 具备静态站点来源目录（由外部工作区提供）

**Production:**
- 阿里云 OSS + CDN + 域名 + HTTPS 证书方案，见 `docs/alicloud-oss-cdn-plan.md`

---

*Stack analysis: 2026-04-22*
