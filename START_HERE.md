# 互联网部署接手入口

这份文件面向新的维护者或合作开发者。

当前这个仓库已完成“公网部署前的本地收口”，并于 2026-11-17 完成 GitHub Pages 0.1.1 的 W10c 更新（链接修复 + 规范化 provenance）；剩余工作主要集中在正式域名、备案、根站点归档与阿里云线上操作。

## 当前状态

已经完成的部分：

- **GitHub Pages 0.1.1 已发布并验证（当前线上 `c6e42a4`，2026-11-17 W10c）**：`pages` 分支提交 `c6e42a46e6176791260045d5054bc98e7b921f3e`（父 `e498eb3`），Pages build 状态 `built`；产物 462 HTML / 569 files，新增 `_astro/SearchPanel…` chunk；W10b 修复 149 页/607 处缺 Pages base 的内部链接，W10a 规范化 `sourceDigest=cfa59423…b333`，W3 本地资源 bridge 在普通浏览器中为惰性提示，45 张 legacy 图片经真实文件核验。发布记录见 [docs/releases/2026-11-17-v0.1.1-pages-w10.md](docs/releases/2026-11-17-v0.1.1-pages-w10.md)（历史记录 [e498eb3 provenance-only](docs/releases/2026-11-17-v0.1.1-pages.md)）
- 站点按版本归档保存在 `site/`
- 已有本地审计脚本（`scripts/audit-site.ps1`），会在开头检查 `ripgrep`（`rg`），缺失即显式失败；并检查：
  - `sitemap.xml` 可被 XML 解析，且 `<loc>` 数量等于 HTML 页面数（`404.html` 不计入）
  - `robots.txt` 的 `Sitemap` 域名/路径与发布 base 一致
  - `site-release-manifest.json` 存在、可解析，且 `siteBase` 与发布 base 一致
  - `localhost`、`127.0.0.1`、`__local-resource`、测试专栏与测试链接、本机盘符绝对路径
  - `example.com`、`System.Object[]` 等历史缺陷特征
- 已有静态元文件生成脚本（`scripts/write-static-metadata.ps1`），可生成：
  - `robots.txt`
  - `sitemap.xml`（合法 XML，每个页面一个 `<loc>`）
  - `404.html`
  - `-BaseUrl` 必填；`example.com` 等占位域名默认被拒绝；`-AllowTestDomain` 仅供临时 fixture 测试，且不能写入仓库 `site/`
- 已有阿里云 `OSS` 上传脚本模板，上传前强制调用审计，审计失败即中止
- 已有 `CDN` 刷新脚本模板
- 已有发布脚本回归测试 `scripts/test-site-release.ps1`，并由 `.github/workflows/site-release-check.yml` 在 `windows-latest` 上运行

## 仍未完成的部分

这些工作需要由掌握正式域名和阿里云环境的人完成：

- 域名购买或确认（仓库当前还没有正式公网域名）
- 备案
- `OSS Bucket` 创建与权限配置
- `CDN` 创建与回源配置
- `HTTPS` 证书申请和绑定
- 正式域名解析
- 用正式 base 与官方库重新导出并生成 `site/v0.1.1`、`site/current` 根站点产物（当前归档产物仍是旧的损坏元文件，需要重新生成，不能手工伪造；Pages 0.1.1 已先行更新，根站点等待 D6-B 正式域名）

此外，以下站点已知限制/后续项（详见最新发布记录）：

- **W10a（已在 Pages 关闭，随 `c6e42a4` 发布）**：`sourceDigest` 已按 W10a 文本 EOL 规范化，跨 CRLF/LF 可复算（官方库 c47f519 为 `cfa59423…b333`），取代旧 `7e1a…`；语义见 [docs/site-release-digest.md](docs/site-release-digest.md)
- **W10b（已在 Pages 关闭，随 `c6e42a4` 发布）**：149 页/607 处 `/works/...`、`/recordings/...` 已带 Pages base，线上抽样通过
- **W10c（later）**：站点仓库 EOL/长路径治理（`.gitattributes`、从 blob 复算 digest、`core.longpaths` 说明）
- **根站点**：`site/v0.1.1`、`site/current`、`robots/sitemap`、OSS/CDN 等仍按 D6-B 等待正式域名决议；Pages 结论不能外推到根站点

## 推荐接手顺序

1. 阅读最新发布记录 [docs/releases/2026-11-17-v0.1.1-pages-w10.md](docs/releases/2026-11-17-v0.1.1-pages-w10.md) 与摘要语义 [docs/site-release-digest.md](docs/site-release-digest.md)；Windows 本地操作前先阅读 [Windows 长路径说明](docs/windows-long-paths.md) 并配置 `core.longpaths=true`
2. 阅读 [README.md](README.md)
3. 阅读 [docs/alicloud-oss-cdn-plan.md](docs/alicloud-oss-cdn-plan.md)
4. 先运行发布脚本回归测试，确认本机环境正常：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\test-site-release.ps1
   ```
5. 复制并填写 `config/alicloud-deploy.example.json`
6. 用正式 base 生成 `robots.txt / sitemap.xml / 404.html`：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
   ```
7. 运行站点审计（需要站点目录中已有 `site-release-manifest.json`）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
   ```
8. 通过 `scripts/publish-oss.ps1` 上传静态站点（脚本会先自动审计）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\publish-oss.ps1 -Version v0.1.1 -Bucket oss://<bucket-name> -Endpoint <oss-endpoint> -BaseUrl https://<正式域名>
   ```
9. 通过 `scripts/refresh-cdn.ps1` 刷新 `CDN`
10. 做公网抽样验收，并在 `docs/releases/` 新增发布记录

## 关键边界

- 这个仓库只负责静态站点与互联网部署
- 不负责桌面应用源码
- 不负责安装版与便携版二进制分发
- 不保存个人资料库原始源数据
- 站点来源应通过脚本参数传入，不把个人路径写死在仓库中
- 不手工编辑 `site/` 下的 `sitemap.xml`、`robots.txt`、`site-release-manifest.json`；产物应由导出/生成脚本产生
- 未通过审计的站点不允许上传到 `OSS` 或 Pages
- Pages 发布必须经 root/用户批准后以 **fast-forward** 方式推送 `pages`，并在发布后验证 build 与线上抽样；回滚步骤见最新发布记录
- Pages 根目录的 `site-release-manifest.json` / `.icm-build-meta.json` 是公开 provenance 文件（仅库 id/名称/版本/digest），发布前确认无敏感信息
- `sourceDigest` 已含 W10a EOL 规范化（CRLF/LF 可复算）；`siteDigest` 仍受 `.icm-build-meta.json` 的 `builtAt` 影响，只对当次产物有效；语义见 [docs/site-release-digest.md](docs/site-release-digest.md)
- Windows 维护者 clone 后需配置 `core.longpaths=true`（仓库本地配置不随 clone 传播）；最长路径、校验命令与资产改名计划见 [docs/windows-long-paths.md](docs/windows-long-paths.md)
- 提交 PR 请使用 [.github/pull_request_template.md](.github/pull_request_template.md) 的检查清单（审计/manifest/digest/base 链接/无密钥/回滚等）

## 建议验收点

- 首页
- 关于页
- 作曲家目录页
- 至少一条录音页
- `robots.txt`（`Sitemap` 指向正式域名）
- `sitemap.xml`（可解析，`<loc>` 数等于页面数）
- `404.html`
- `HTTPS` 是否生效
- `CDN` 刷新后内容是否一致
