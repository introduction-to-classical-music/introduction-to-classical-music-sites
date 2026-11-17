# 不全书互联网部署仓库

## 访问

https://introduction-to-classical-music.github.io/introduction-to-classical-music-sites/

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
  互联网部署说明、阿里云方案、回滚说明
- `scripts/`
  站点同步、上线前审计、静态元文件生成、`OSS` 上传、`CDN` 刷新脚本，以及发布脚本回归测试
- `.github/workflows/`
  `site-release-check.yml`：在 `windows-latest` 上运行发布脚本回归测试
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
- 如果未来改成子路径部署，而不是域名根目录部署，需要额外补 `base path（基础路径）` 支持
