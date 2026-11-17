# 互联网部署接手入口

这份文件面向新的维护者或合作开发者。

当前这个仓库已经完成了“公网部署前的本地收口”，剩余工作主要集中在域名、备案和阿里云线上操作。

## 当前状态

已经完成的部分：

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
- 用正式 base 与官方库重新导出并生成 `site/v0.1.1`、`site/current` 产物（当前归档产物仍是旧的损坏元文件，需要重新生成，不能手工伪造）

## 推荐接手顺序

1. 阅读 [README.md](README.md)
2. 阅读 [docs/alicloud-oss-cdn-plan.md](docs/alicloud-oss-cdn-plan.md)
3. 先运行发布脚本回归测试，确认本机环境正常：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\test-site-release.ps1
   ```
4. 复制并填写 `config/alicloud-deploy.example.json`
5. 用正式 base 生成 `robots.txt / sitemap.xml / 404.html`：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
   ```
6. 运行站点审计（需要站点目录中已有 `site-release-manifest.json`）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.1 -BaseUrl https://<正式域名>
   ```
7. 通过 `scripts/publish-oss.ps1` 上传静态站点（脚本会先自动审计）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\publish-oss.ps1 -Version v0.1.1 -Bucket oss://<bucket-name> -Endpoint <oss-endpoint> -BaseUrl https://<正式域名>
   ```
8. 通过 `scripts/refresh-cdn.ps1` 刷新 `CDN`
9. 做公网抽样验收

## 关键边界

- 这个仓库只负责静态站点与互联网部署
- 不负责桌面应用源码
- 不负责安装版与便携版二进制分发
- 不保存个人资料库原始源数据
- 站点来源应通过脚本参数传入，不把个人路径写死在仓库中
- 不手工编辑 `site/` 下的 `sitemap.xml`、`robots.txt`、`site-release-manifest.json`；产物应由导出/生成脚本产生
- 未通过审计的站点不允许上传到 `OSS` 或 Pages

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
