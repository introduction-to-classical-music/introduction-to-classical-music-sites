# External Integrations

**Analysis Date:** 2026-04-22

## APIs & External Services

**Cloud Hosting & Delivery:**
- Alibaba Cloud OSS - 用于静态站点文件托管
  - SDK/Client: `ossutil` CLI（由 `scripts/publish-oss.ps1` 调用）
  - Auth: Not detected in repo（凭据由本机 `ossutil` 配置管理）
- Alibaba Cloud CDN - 用于缓存刷新与分发加速
  - SDK/Client: `aliyun` CLI（由 `scripts/refresh-cdn.ps1` 调用 `cdn RefreshObjectCaches`）
  - Auth: Not detected in repo（凭据由本机 `aliyun` 配置管理）

**External Content Links:**
- Bilibili / YouTube / NetEase Cloud Music / 其他外链资源 - 作为录音条目外部跳转目标
  - SDK/Client: 浏览器原生 `<a href>` 外链
  - Auth: Not applicable
  - 示例页面：`site/current/recordings/recording-第六交响曲田园-蒙都1958/index.html`

## Data Storage

**Databases:**
- Not detected（仓库内无数据库连接代码或 ORM 配置）
  - Connection: Not applicable
  - Client: Not applicable

**File Storage:**
- 阿里云 OSS（目标）+ 仓库内静态目录 `site/`（源）

**Caching:**
- 阿里云 CDN（缓存策略建议见 `docs/alicloud-oss-cdn-plan.md`）

## Authentication & Identity

**Auth Provider:**
- Not detected（站点为公开静态内容，无登录系统实现）
  - Implementation: Not applicable

## Monitoring & Observability

**Error Tracking:**
- None detected（无 Sentry/Datadog 等接入）

**Logs:**
- 本地脚本日志文件：审计失败写入 `logs/audit-site-<version>.log`，见 `scripts/audit-site.ps1`
- CLI 控制台输出：发布、刷新、生成元信息脚本通过 `Write-Host` 输出过程状态

## CI/CD & Deployment

**Hosting:**
- 阿里云 OSS + CDN（方案说明见 `docs/alicloud-oss-cdn-plan.md`）

**CI Pipeline:**
- Not detected（无 GitHub Actions/GitLab CI/Jenkins 配置）
- 当前为本地手动执行脚本式发布，流程见 `docs/release-workflow.md`

## Environment Configuration

**Required env vars:**
- `ICM_SITE_SOURCE_ROOT`（可选，供 `scripts/stage-site.ps1` 读取站点来源目录）

**Secrets location:**
- Not stored in repository（仓库仅包含 `config/*.example.json` 模板，不含真实密钥）
- OSS/CDN 凭据依赖本机 CLI 配置（`ossutil` 与 `aliyun`）

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None（无服务端 webhook 发送逻辑）

---

*Integration audit: 2026-04-22*
