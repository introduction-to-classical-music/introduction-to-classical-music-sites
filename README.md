# 不全书互联网部署仓库

## 访问

https://introduction-to-classical-music.github.io/introduction-to-classical-music-sites/

2026-11-17：GitHub Pages 0.1.1 已完成两次更新，当前线上为 **W10c `c6e42a4`**（W10b 内部链接 base 修复 149 页/607 处、W10a 规范化 `sourceDigest`、W3 本地资源 bridge 惰性脚本、45 张 legacy 图核验）。发布记录见 [docs/releases/2026-11-17-v0.1.1-pages-w10.md](docs/releases/2026-11-17-v0.1.1-pages-w10.md)（此前 `e498eb3` 的 provenance-only 记录已作为历史保留）。

这个仓库只负责两件事：

- 保存准备上线的静态站点版本
- 保存互联网部署所需的脚本、配置模板和交接文档

它**不包含**桌面应用源码、维护工具源码或版本检索服务源码。桌面应用仍在主仓库维护；这里关注的是“已经构建完成、准备上传到互联网”的站点产物。

## 快速入口

- [START_HERE.md](START_HERE.md)
  面向新的维护者或合作开发者
- [docs/alicloud-oss-cdn-plan.md](docs/alicloud-oss-cdn-plan.md)
  阿里云 `OSS + CDN` 主方案
- [docs/release-workflow.md](docs/release-workflow.md)
  站点更新、审计、上传与回滚流程
- [docs/releases/2026-11-17-v0.1.1-pages-w10.md](docs/releases/2026-11-17-v0.1.1-pages-w10.md)
  最新一次 Pages 发布记录（`c6e42a4`：链接/digest/legacy 图/验证/回滚）
- [docs/releases/2026-11-17-v0.1.1-pages.md](docs/releases/2026-11-17-v0.1.1-pages.md)
  历史发布记录（`e498eb3`，provenance-only，已被取代）
- [docs/site-release-digest.md](docs/site-release-digest.md)
  `sourceDigest`/`siteDigest` 语义、EOL 规范化与复算方法
- [docs/windows-long-paths.md](docs/windows-long-paths.md)
  Windows 长路径说明（`core.longpaths`、路径长度校验、资产改名计划）

## 当前发布状态（2026-11-17）

- **GitHub Pages 0.1.1 已发布并验证（当前线上 `c6e42a4`）**：`pages` 分支提交 `c6e42a46e6176791260045d5054bc98e7b921f3e`（父 `e498eb3`），Pages build 状态 `built`（耗时约 37.7s）；产物 **462 HTML / 569 files**，新增 `_astro/SearchPanel…DP1T1OlE.js`，45 张 legacy 图片经真实文件核验。
  - 线上地址：https://introduction-to-classical-music.github.io/introduction-to-classical-music-sites/
  - 关键变化：W10b 修复 149 页/607 处缺 Pages base 的内部链接（线上抽样 200）；W10a `sourceDigest=cfa59423…b333`（CRLF/LF 可复算，取代旧 `7e1a…`）；W3 本地资源 bridge 在普通浏览器中**惰性提示**、不访问本地资源。
  - provenance 文件（公开可访问）：`/introduction-to-classical-music-sites/site-release-manifest.json`（`siteDigest=7a633492…eb68`，manifest SHA256 `1AB7D3D4…E0C`）、`/introduction-to-classical-music-sites/.icm-build-meta.json`
  - 发布记录：[docs/releases/2026-11-17-v0.1.1-pages-w10.md](docs/releases/2026-11-17-v0.1.1-pages-w10.md)
- **根站点（`site/v0.1.1`、`site/current`）仍等待正式域名**（D6-B）：未生成、未替换，`site/` 归档仍是旧产物；OSS/CDN 未执行。
- 已知限制 / 后续：
  - **W10a（已修复并随 `c6e42a4` 发布）**：`sourceDigest` 已按 W10a 规范化，跨 CRLF/LF 可复算；详见 [docs/site-release-digest.md](docs/site-release-digest.md)。
  - **W10b（已修复并随 `c6e42a4` 发布）**：149 页/607 处内部链接已带 Pages base，线上抽样通过。
  - **W10c（later）**：站点仓库 EOL/长路径治理（`.gitattributes`、从 blob 复算 digest、`core.longpaths` 说明）。
  - `siteDigest` 仍为当次构建值（包含 `.icm-build-meta.json` 的 builtAt），不是跨构建稳定值。

## 仓库边界

为了避免多个项目互相串扰，这个仓库遵守以下边界：

- 这里只接收“已经构建好的静态站点”
- 这里不直接从源码构建桌面应用
- 这里不保存安装版或便携版二进制
- 这里不保存个人资料库原始数据
- 这里不依赖固定本机路径；站点来源路径通过脚本参数传入

## 当前目录结构

- `site/current`
  当前准备上线的站点副本
- `site/v0.1.0`
  按版本归档的站点副本
- `docs/`
  互联网部署说明、阿里云方案、回滚说明、[发布记录](docs/releases/)、[摘要语义文档](docs/site-release-digest.md)，以及 [Windows 长路径说明](docs/windows-long-paths.md)
- `scripts/`
  站点同步、上线前审计、静态元文件生成、`OSS` 上传、`CDN` 刷新脚本，以及发布脚本回归测试
- `.github/`
  `workflows/site-release-check.yml`：在 `windows-latest` 上运行发布脚本回归测试；`pull_request_template.md`：PR 检查清单（审计/manifest/密钥/回滚等）
- `config/`
  部署配置模板

## 站点来源

这个仓库不直接生成站点。站点来源应由外部工作区提供，例如你自己的站点归档目录：

- `<site-source-root>`

实际同步时，把来源路径通过命令行参数传给脚本，而不是把个人路径写死在仓库中。

## 常用命令

同步一个版本的站点到仓库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage-site.ps1 -Version v0.1.1 -SourceSitesRoot <site-source-root>
```

也可以直接传入已经构建好的站点目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage-site.ps1 -Version v0.1.1 -SourceSiteDir <built-site-dir>
```

生成 `robots.txt`、`sitemap.xml` 和 `404.html`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
```

- `-BaseUrl` 为必填项，必须使用真实公网域名（根路径部署时填域名本身，子路径部署时带路径前缀）。
- `example.com`、`your-domain.example`、`localhost` 等占位域名会被直接拒绝；只有本地临时 fixture 测试才允许显式传 `-AllowTestDomain`，并且该开关拒绝写入仓库内的 `site/` 目录。
- 脚本生成后会重新解析 `sitemap.xml`，断言 `<loc>` 数量等于 HTML 页面数（`404.html` 是错误页，不计入），任何不一致都会直接报错。

审计某个版本是否适合公网发布：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
```

- 运行前必须先安装 `ripgrep`（`rg`）并加入 `PATH`；缺失时审计脚本会显式失败，不会静默跳过扫描。
- 站点目录中必须存在 `site-release-manifest.json`，且其中的 `siteBase` 与本次发布 base 一致。
- 审计项包括：`sitemap.xml` 可被 XML 解析且 `<loc>` 数等于 HTML 页数；`robots.txt` 的 `Sitemap` 域名/路径与 base 一致；禁止出现 `example.com`、`System.Object[]`、`__local-resource`、本机盘符绝对路径等缺陷特征。
- 审计失败会以非零退出码结束，并把明细写入 `logs/audit-site-<version>.log`（`logs/` 已被仓库忽略）。

上传站点到阿里云 `OSS`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-oss.ps1 -Version v0.1.1 -Bucket oss://<bucket-name> -Endpoint oss-cn-hangzhou.aliyuncs.com -BaseUrl https://<正式域名>
```

`publish-oss.ps1` 在调用 `ossutil` 之前会强制先执行 `audit-site.ps1`；审计不通过时上传立即中止，不存在跳过审计的开关。未传 `-BaseUrl` 时按 manifest 的 `siteBase` 做路径校验（无法校验域名）。

刷新阿里云 `CDN`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh-cdn.ps1 -Domain <正式域名> -Paths https://<正式域名>/index.html,https://<正式域名>/sitemap.xml
```

Pages 发布默认只预览差异；确认后才传入 `-Publish`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-pages.ps1 -Version v0.1.1 -SourceSiteDir <pages-site-dir>
powershell -ExecutionPolicy Bypass -File .\scripts\publish-pages.ps1 -Version v0.1.1 -SourceSiteDir <pages-site-dir> -Publish
```

运行发布脚本回归测试（本地与 CI 使用同一入口）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-site-release.ps1
```

测试在临时目录构造正例/负例 fixture，结束后自动清理，不会写入仓库；`push` 到 `main` 或提交 PR 时由 `.github/workflows/site-release-check.yml` 在 `windows-latest` 上运行。

## 阿里云推荐方案

建议使用：

- `OSS（Object Storage Service，对象存储）` 托管静态站点
- `CDN（Content Delivery Network，内容分发网络）` 做缓存和加速
- 独立域名
- `HTTPS（Hypertext Transfer Protocol Secure，安全超文本传输协议）`

详细说明见：

- [docs/alicloud-oss-cdn-plan.md](docs/alicloud-oss-cdn-plan.md)
- [docs/release-workflow.md](docs/release-workflow.md)

## 说明

- 站点中保留当前 `QQ` 联系方式，作为正式用户反馈渠道
- 公网站点默认不应暴露本地资源链接或本地磁盘路径
- Pages 根目录的 `site-release-manifest.json` / `.icm-build-meta.json` 是**公开** provenance 文件，仅含库 id/名称/版本/digest；发布前确认无敏感信息
- GitHub Pages 只发布 `pages` 分支；正式域名根站点、`site/current` 与 OSS/CDN 待 D6 正式域名决议后另行发布
- 每次 Pages/根站点发布后，必须按发布记录中的步骤验证 Pages build 状态、线上抽样与回滚可用性
- `sourceDigest` 已含 W10a EOL 规范化（CRLF/LF 可复算）；`siteDigest` 仍受 `.icm-build-meta.json` 的 `builtAt` 影响，只对当次产物有效——语义与复算方法见 [docs/site-release-digest.md](docs/site-release-digest.md)
- Windows 上 clone 本仓库后必须配置 `core.longpaths=true`（仓库本地配置不会随 clone 传播）；最长路径/校验与资产改名计划见 [docs/windows-long-paths.md](docs/windows-long-paths.md)
- 如果未来改成子路径部署，而不是域名根目录部署，需要额外补 `base path（基础路径）` 支持
