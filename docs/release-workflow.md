# 站点发布工作流

> 最新发布记录：[2026-11-17 GitHub Pages 0.1.1 W10c](releases/2026-11-17-v0.1.1-pages-w10.md)（当前线上 `c6e42a4`）。
> 历史记录：[2026-11-17-v0.1.1-pages.md](releases/2026-11-17-v0.1.1-pages.md)（`e498eb3`，provenance-only，已被取代）。
> 摘要语义：见 [site-release-digest.md](site-release-digest.md)。
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

> 根站点相关步骤（2–6、9–10）当前被 D6-B 正式域名阻塞。Pages 已于 2026-11-17 完成两次发布：
> `e498eb3`（W2b provenance-only，已被取代）→ **`c6e42a4`（W10c：链接修复 + 规范化 provenance + 站点脚本更新，当前线上）**；
> 详见 [releases/2026-11-17-v0.1.1-pages-w10.md](releases/2026-11-17-v0.1.1-pages-w10.md)。

## Pages 发布历史（D6-B）

| 线上提交 | 日期 | 内容 | 状态 |
|---|---|---|---|
| `ec58b6b` | 2026-04-24 | 0.1.0 期站点 | 已被取代 |
| `e498eb3` | 2026-11-17 | W2b provenance-only（manifest + 0.1.1 meta） | 已被取代 |
| **`c6e42a4`** | 2026-11-17 | **W10c：W10b 链接修复（149 页/607 处）+ W10a 规范化 sourceDigest + W3 本地资源 bridge 惰性脚本 + 45 legacy 图核验（462 HTML/569 files）** | **当前线上** |

## Pages provenance 发布（D6-B）

Pages 子路径站点（base=`/introduction-to-classical-music-sites/`）的发布流程（2026-11-17 已按此流程执行两次：`e498eb3`、`c6e42a4`）：

1. 在**隔离环境**用已验收的软件提交 + 官方库导出 Pages 站点：
   ```powershell
   node scripts/export-site-release.mjs --source <官方库> --out <work>\pages-v<版本> --base /introduction-to-classical-music-sites/
   ```
   - 必须在 PowerShell 中执行，避免 Git-Bash/MSYS 把 `/base/` 参数改写为 Windows 路径。
2. 校验 manifest：`appVersion`、`siteBase`、`sourceDigest`/`siteDigest` 可复算（`hashDirectory`，算法见 [site-release-digest.md](site-release-digest.md)），中文 `libraryName` 在 Windows PowerShell 5.1 下可读。
   - `sourceDigest` 已含 W10a EOL 规范化（CRLF/LF 可复算）；`siteDigest` 仍受 `builtAt` 影响，只对当次产物复算有效，发布记录需同时记录 manifest SHA256。
3. 运行 Pages 模式审计：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v<版本> -SiteDir <work>\pages-v<版本> -ExpectedSiteBase /introduction-to-classical-music-sites/ -SkipStaticMetadata
   ```
   Pages 构建不生成根站点专属的 `robots.txt/sitemap.xml`，所以跳过静态元文件断言；manifest/base、禁止内容、本机路径等仍需通过。
4. 用临时 worktree（从 `origin/pages` 检出）替换站点内容、保留/生成 `.nojekyll`，**先预览 diff**；发布内容可能是 provenance-only（仅 `.icm-build-meta.json` + `site-release-manifest.json`），也可能包含软件侧已验收的站点行为修复（如 W3 本地资源 bridge 脚本、W10b 链接 base 修复）——必须逐类解释 diff（HTML 数量、新增/删除文件、链接计数）并经 E-VERIFY/root 评审。
   - 当前 Pages 产物基线：462 HTML / **569 files**（含 `_astro/SearchPanel…DP1T1OlE.js`；100 个 `library-assets`，其中 45 legacy、55 managed）。文件数变化必须可解释。
5. 在临时 worktree 中创建 commit（示例信息 `deploy: publish v<版本>`），确认 commit 的 parent = 当前 `origin/pages`、主工作树/`site/current` 未被修改。
6. root/用户批准后 **fast-forward** 推送：`git push origin <local-ref>:pages`；禁止未批准的 force-push。
7. 推送后验证：GitHub Pages build 状态为 `built` 且 commit 匹配、线上抽样 200、`/site-release-manifest.json` 与 `/.icm-build-meta.json` 可访问且字段/哈希与发布证据一致；按 [site-release-digest.md](site-release-digest.md) 复核 `sourceDigest`（规范化值）与 manifest SHA256。
8. 回滚：默认在 `pages` 上 revert 发布提交并推送（新提交，安全）；应急 force-push 回上一线上 SHA 需明确批准。详见发布记录。

### Pages 已知限制 / 已关闭项

- **W10a `sourceDigest` EOL（已修复，随 `c6e42a4` 发布）**：软件 W10a 对文本摘要做 CRLF/CR→LF 规范化，Windows CRLF 工作树与 LF checkout/CI 复算一致；官方库 `c47f519` 当前 `sourceDigest=cfa59423…b333`（取代旧 `7e1a2316…31620`）。见 [site-release-digest.md](site-release-digest.md)。
- **W10b 根绝对链接（已修复，随 `c6e42a4` 发布）**：149 页/607 处 `/works/...`、`/recordings/...` 已带 Pages base；发布前审计为 0 缺 base / 0 重复前缀，线上抽样通过。
- **W10c 站点仓库 EOL/长路径治理（later）**：补 `.gitattributes`、从 blob 复算 digest、`core.longpaths` 说明。
- `siteDigest` 仍为**当次构建**复算值（包含 `.icm-build-meta.json` 的 builtAt 与 `.nojekyll`），不是跨构建稳定值；发布记录应同时记录 manifest SHA256。
- 根站点（`site/current`/`site/v0.1.1`、`robots/sitemap`、OSS/CDN）仍待 D6 正式域名，本流程的 Pages 结论不能外推到根站点。
- **W8c 发布脚本演练**：发布脚本全链路（export→stage→audit→publish-pages）与安全 revert 回滚已在本地临时副本 + 本地 bare remote 演练（不触碰生产 `pages`），记录见 `_remediation-20261117/evidence/batch11-site-docs/`。

## site/current 与根站点归档状态（D6-B 前）

- **`site/current`/`site/v0.1.0` 是历史归档/未发布产物，不是当前线上内容，也不是发布源。**
  - `site/current/robots.txt` 仍指向占位域名 `example.com`；`site/current/sitemap.xml` 正文仍含历史损坏标记 `System.Object[]`；且没有 `site-release-manifest.json`（截至本次记录）。
  - **不得**把 `site/current` 直接复制/上传到 OSS、CDN 或 Pages，也**不得**手工修补这些元文件或伪造 manifest。
- D6-B 正式域名决议后，根站点必须按以下顺序重建并发布：
  1. `export-site-release.mjs` 用正式 base 导出（产物带 `site-release-manifest.json`）；
  2. `write-static-metadata.ps1 -BaseUrl https://<正式域名>` 生成 `robots.txt`/`sitemap.xml`/`404.html`；
  3. `audit-site.ps1 -BaseUrl https://<正式域名>` 审计通过（不得跳过静态元文件断言）；
  4. `stage-site.ps1` 归档到 `site/v<版本>` 与 `site/current`（换入新产物后才更新 current）；
  5. `publish-oss.ps1`（强制审计）上传 OSS，再刷新 CDN。
- 在此之前，`site/current` 仅作历史参考；任何“用 `site/current` 当发布源”的做法都会绕过 manifest 与审计门禁，必须拒绝。

### Pages-only 静态元文件例外（W2b 判据②口径）

- GitHub Pages 子路径站点（`pages` 分支，base `/introduction-to-classical-music-sites/`）**不提供**根站点专属的 `robots.txt`、`sitemap.xml`（线上访问为 404）以及自定义 `404.html`；这是 D6-B（根站点等正式域名）下的**预期例外**，不判为 Pages 发布失败。
- 因此 Pages 模式审计使用 `-SkipStaticMetadata`：跳过 sitemap/robots 断言，但仍校验 `site-release-manifest.json`/`siteBase`、禁止内容（`__local-resource`、本机路径、占位域名等）与页面集合。
- W2b 判据②的“含 sitemap/robots”按 D6-B 修正为：**根站点发布**（正式域名后）必须满足；**Pages-only 阶段**该子项不适用（n.a.），待 D6-B 到期再补并复核。
- Pages 发布记录与任务卡口径需明确此例外，避免把“线上 robots/sitemap 404”误判为回归；D6-B 决策后，正式域名根站点仍需生成并验证这两个文件。

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
- 摘要字段语义、EOL 规范化与复算方法详见 [site-release-digest.md](site-release-digest.md)；发布记录需同时记录 `sourceDigest`、`siteDigest` 与 manifest SHA256。当前 Pages（`c6e42a4`）为 `sourceDigest=cfa59423…b333`、`siteDigest=7a633492…eb68`、manifest SHA256 `1AB7D3D4…E0C`。

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
- 发布记录：`docs/releases/<日期>-<版本>-<目标>.md`（如 `2026-11-17-v0.1.1-pages.md`；后续修订/追加发布可加后缀，如 `2026-11-17-v0.1.1-pages-w10.md`）

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
- Pages：`site-release-manifest.json`（含 `sourceDigest` 规范化值/manifest SHA256）、`.icm-build-meta.json`、Pages build 状态（commit 匹配）与线上抽样
- 发布记录：提交 SHA、diff 分类、manifest/digest、build/抽样结果、回滚方案、已知限制；必须明确是否取代先前发布记录

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
- 不要把 `siteDigest` 当作跨构建稳定值；`sourceDigest` 在 W10a 后已规范化（CRLF/LF 可复算），但仍只在同一官方库 commit + 文本规范化算法下比对
- 不要把 `site/current`/`site/v0.1.0` 当作发布源直接上传 OSS/CDN/Pages，或在 D6-B 前手工修补其 `robots.txt`/`sitemap.xml`/manifest（必须走 export→audit→manifest 重建）
- 不要把 Pages-only 的 `robots.txt`/`sitemap.xml` 404 当作发布回归；该子项在 D6-B 下按例外处理，正式域名根站点发布时必须补齐
- 不要在发布后跳过 Pages build 状态与线上抽样验证；发布记录必须包含回滚步骤，并明确新发布是否取代旧发布记录
