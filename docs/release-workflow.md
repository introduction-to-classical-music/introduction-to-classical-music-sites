# 站点发布工作流

> 最新发布记录：[2026-11-17 GitHub Pages 0.1.1](releases/2026-11-17-v0.1.1-pages.md)。
> 当前边界（D6-B）：暂无正式域名，只更新 GitHub Pages；根站点 `site/v0.1.1`/`site/current`、OSS/CDN 等正式域名决议后再做。

## 一次完整发布的顺序

1. 在安装版工作副本中完成内容更新
2. 用 `export-site-release.mjs` 导出根路径站点（产出目录中必须带 `site-release-manifest.json`）
3. 用本仓库同步该版本站点到 `site/v*` 和 `site/current`
4. 用正式 base 生成 `robots.txt / sitemap.xml / 404.html`
5. 运行本地审计（`audit-site.ps1`），失败必须修复后重跑
6. 用本地静态服务器模拟检查
7. 在临时 library 副本中生成 Pages 子路径站点
8. 使用 `publish-pages.ps1` 预览并显式推送 `pages`
9. 上传根路径站点到阿里云 `OSS`（`publish-oss.ps1` 会先自动审计）
10. 刷新 `CDN`
11. 做公网抽样验收
12. 在 `docs/releases/<日期>-<版本>-<目标>.md` 记录本次发布（提交/差分、manifest 字段、build/线上验证、已知限制、回滚），并更新 README/START_HERE/本文件的链接

> 根站点相关步骤（2–6、9–10）当前被 D6-B 正式域名阻塞；Pages 已在 2026-11-17 完成一次 **provenance-only** 更新（见 `docs/releases/2026-11-17-v0.1.1-pages.md`）。

## Pages provenance 发布（D6-B）

Pages 子路径站点（base=`/introduction-to-classical-music-sites/`）的发布流程（2026-11-17 已执行一次）：

1. 在**隔离环境**用已验收的软件提交 + 官方库导出 Pages 站点：
   ```powershell
   node scripts/export-site-release.mjs --source <官方库> --out <work>\pages-v<版本> --base /introduction-to-classical-music-sites/
   ```
   - 必须在 PowerShell 中执行，避免 Git-Bash/MSYS 把 `/base/` 参数改写为 Windows 路径。
2. 校验 manifest：`appVersion`、`siteBase`、`sourceDigest`/`siteDigest` 可复算（`hashDirectory`），中文 `libraryName` 在 Windows PowerShell 5.1 下可读。
3. 运行 Pages 模式审计：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v<版本> -SiteDir <work>\pages-v<版本> -ExpectedSiteBase /introduction-to-classical-music-sites/ -SkipStaticMetadata
   ```
   Pages 构建不生成根站点专属的 `robots.txt/sitemap.xml`，所以跳过静态元文件断言；manifest/base、禁止内容、本机路径等仍需通过。
4. 用临时 worktree（从 `origin/pages` 检出）替换站点内容、保留/生成 `.nojekyll`，**先预览 diff**；预期仅 provenance 类文件变化（`.icm-build-meta.json` + 新增 `site-release-manifest.json`），若出现未预期 HTML/资源变化必须先评审。
5. 在临时 worktree 中创建 commit（示例信息 `deploy: publish v<版本>`），确认 commit 的 parent = 当前 `origin/pages`、主工作树/`site/current` 未被修改。
6. root/用户批准后 **fast-forward** 推送：`git push origin <local-ref>:pages`；禁止未批准的 force-push。
7. 推送后验证：GitHub Pages build 状态为 `built` 且 commit 匹配、线上抽样 200、`/site-release-manifest.json` 与 `/.icm-build-meta.json` 可访问且字段/哈希与发布证据一致。
8. 回滚：默认在 `pages` 上 revert 发布提交并推送（新提交，安全）；应急 force-push 回上一线上 SHA 需明确批准。详见发布记录。

### Pages 已知限制（后续工作项）

- **W10a `sourceDigest` EOL**：官方库 `core.autocrlf=true` 且无 `.gitattributes`，导出哈希绑定 CRLF 工作树，LF checkout/CI 无法复算；W7a 前必须修复（官方库 `eol=lf` + renormalize，或哈希按规范化文本/git blob），修复后重新导出并再次做 provenance-only Pages 更新。
- **W10b 根绝对链接**：149 个实体页共 607 处 `/works/...`、`/recordings/...` 缺 Pages base（在 Pages 子路径下 404，既有缺陷）；修复导出侧 href 生成后重建 Pages 并抽样。
- **W10c 站点仓库 EOL/长路径治理**：补 `.gitattributes`、从 blob 复算 digest、`core.longpaths` 说明（later）。
- `siteDigest` 为**当次构建**复算值（包含 `.icm-build-meta.json` 的 builtAt 与 `.nojekyll`），不是跨构建稳定值。

## 静态元文件要求

生成命令（`-BaseUrl` 必填）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
```

- `-BaseUrl` 必须使用真实公网域名；`example.com`、`your-domain.example`、`localhost` 等占位域名会被拒绝。
- 只有临时 fixture 测试可以显式传 `-AllowTestDomain`；该开关同时禁止写入仓库 `site/` 目录，避免测试产物混入发布归档。
- `sitemap.xml` 必须是合法 XML：每个内容页对应一个 `<url><loc>…</loc></url>`；`404.html` 是错误页，不计入 sitemap。
- 生成脚本在写盘后会重新解析 `sitemap.xml` 并断言 `<loc>` 数量等于 HTML 页面数，断言失败直接报错（不会留下“生成成功”的假象）。
- `robots.txt` 的 `Sitemap:` 行必须指向 `-BaseUrl` 对应的 `sitemap.xml`。

## 发布清单（`site-release-manifest.json`）

根路径站点与 Pages 站点的发布目录中都必须带 `site-release-manifest.json`，由导出脚本（`scripts/export-site-release.mjs`）生成。示例字段：

```json
{
  "libraryId": "…",
  "libraryName": "…",
  "appVersion": "0.1.1",
  "builtAt": "2026-01-01T00:00:00.000Z",
  "siteBase": "/",
  "siteOutputMode": "public",
  "strippedLocalLinks": 0,
  "sourceLocalResourceLinks": 0,
  "sourceDigest": "…",
  "siteDigest": "…"
}
```

- `siteBase` 是站点部署的路径 base：根路径部署为 `/`，GitHub Pages 子路径部署为 `/introduction-to-classical-music-sites/`。
- `siteOutputMode`/`strippedLocalLinks`/`sourceLocalResourceLinks` 由 W5 public 导出逻辑写入：公开产物不包含 `/__local-resource` 或本机绝对路径，官方库当前剥离数为 0。
- 审计时会用 `-BaseUrl`（或 `-ExpectedSiteBase`）推导期望 base，再与 manifest 的 `siteBase` 比对：
  - `-BaseUrl https://<域名>` → 期望 base `/`
  - `-BaseUrl https://<域名>/<子路径>/` → 期望 base `/<子路径>/`
- 需要重新生成 release 时，manifest 必须随站点一起重新导出，不要手工伪造 digest。
- Pages 发布后 `site-release-manifest.json` 与 `.icm-build-meta.json` 会**公开可访问**（仅库 id/名称/版本/digest，无敏感信息）；发布前确认可披露。

## 审计项与失败处理

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
```

- 前置依赖：`ripgrep`（`rg`）必须在 `PATH` 中；缺失时脚本直接失败（不会静默跳过扫描）。
- 固定检查项：
  - `sitemap.xml` 可被 XML 解析，`<loc>` 数等于 HTML 页面数（`404.html` 不计入），URL 均在 base 内
  - `robots.txt` 存在，`Sitemap:` 为绝对 http(s) URL，域名、路径与 base 一致
  - `site-release-manifest.json` 存在、可 JSON 解析、`siteBase` 与期望 base 一致
  - 禁止内容：`example.com`、`System.Object[]`、`__local-resource`、`localhost`、`127.0.0.1`、测试专栏/测试链接、本机盘符绝对路径
- 失败时：打印明细、以非零退出码结束，并把完整明细写入 `logs/audit-site-<version>.log`（`logs/` 已被仓库忽略）。
- `publish-oss.ps1` 在调用 `ossutil` 前强制调用审计；审计失败即中止上传，没有跳过开关。
- `publish-pages.ps1` 也会调用审计；Pages 构建不含根路径专属的 `robots.txt / sitemap.xml`，因此 Pages 场景以 `-SkipStaticMetadata` 跳过静态元文件断言，但仍会校验 manifest/base 与禁止内容。

## 自动化测试与 CI

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-site-release.ps1
```

- 测试在系统临时目录构造正例/负例 fixture（含旧式损坏产物、占位域名、缺 manifest、base 不符、缺 `rg`、`publish-oss` 审计门禁等），结束后自动清理。
- 测试不会写入仓库 `site/` 目录，也不会触发任何网络上传（`publish-oss` 正例使用本地假 `ossutil`）。
- `.github/workflows/site-release-check.yml` 在 `push` 到 `main` 或提交 PR 时于 `windows-latest` 上运行同一测试脚本。

## 推荐命名

- 版本归档：`site/v0.1.1`
- 当前准备上线版本：`site/current`
- 发布记录：`docs/releases/<日期>-<版本>-<目标>.md`（如 `2026-11-17-v0.1.1-pages.md`）

## 每次发布至少检查

- 首页
- 关于页
- 作曲家目录页
- 指挥目录页
- 搜索页
- 至少一条录音页
- 样式和图片资源
- 404 页面
- `robots.txt` 与 `sitemap.xml`（用浏览器或 `audit-site.ps1` 复核；Pages 构建不提供这两个文件）
- Pages：`site-release-manifest.json`、`.icm-build-meta.json`、Pages build 状态与线上抽样
- 发布记录：提交 SHA、diff、manifest/digest、build/抽样结果、回滚方案、已知限制

## 禁止事项

- 不要把桌面应用源码放进这个仓库
- 不要把构建缓存和临时目录放进这个仓库
- 不要把本地磁盘路径暴露到公网站点
- 不要把测试专栏和测试链接一起带上线
- 不要用占位域名生成准备上线的 `robots.txt / sitemap.xml`
- 不要手工编辑 `site-release-manifest.json` 或手工拼 `sitemap.xml`
- 不要把根路径站点直接发布到 Pages 子路径
- 不要在未审计或未确认差异前传入 `-Publish`，也不要在未通过审计时上传 `OSS`
- 不要在未经 root/用户批准时推送 `pages`，也不要使用未经批准的 force-push（发布必须 fast-forward）
- 不要把 `siteDigest` 当作跨构建稳定值，也不要在 LF/CRLF 工作树之间直接比对 `sourceDigest`（W10a 修复前以当次工作树复算为准）
- 不要在发布后跳过 Pages build 状态与线上抽样验证；发布记录必须包含回滚步骤
