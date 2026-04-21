# 不全书互联网部署仓库

这个仓库只负责两件事：

- 保存准备上线的静态站点版本
- 保存互联网部署所需的脚本、配置模板和操作文档

它**不包含**桌面应用源码、维护工具源码或版本检索服务源码。桌面应用仍然在主仓库维护；这里关注的是“已经构建完成、准备上传到互联网”的站点产物。

## 仓库边界

为了避免几个项目互相串扰，这个仓库遵守以下边界：

- 这里只接收“已经构建好的静态站点”
- 这里不直接从源码构建桌面应用
- 这里不保存便携版或安装版二进制文件
- 这里不保存个人资料库原始数据
- 这里不依赖任何固定的本机路径；站点来源路径需要在运行脚本时显式传入

## 当前目录结构

- `site/current`
  当前准备上线的站点副本
- `site/v0.1.0`
  按版本归档的站点副本
- `docs/`
  互联网部署说明、阿里云方案、回滚说明
- `scripts/`
  站点同步、上线前审计、静态元文件生成脚本
- `config/`
  部署配置模板

## 站点来源

这个仓库不直接生成站点。站点来源应由外部工作区提供，例如你自己的站点归档目录：

- 示例：`<site-source-root>`

实际同步时，用命令行参数把来源路径传入脚本，而不是把个人路径写死在仓库中。

## 常用命令

同步一个版本的站点到仓库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage-site.ps1 -Version v0.1.0 -SourceSitesRoot <site-source-root>
```

审计某个版本是否适合公网发布：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.0
```

生成 `robots.txt`、`sitemap.xml` 和 `404.html`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.0 -BaseUrl https://your-domain.example
```

## 阿里云推荐方案

建议使用：

- `OSS（Object Storage Service，对象存储）` 托管静态站点
- `CDN（Content Delivery Network，内容分发网络）` 做缓存和加速
- 独立域名
- `HTTPS（Hypertext Transfer Protocol Secure，安全超文本传输协议）`

详细说明见：

- [docs/alicloud-oss-cdn-plan.md](E:/Workspace/codex/introduction-to-classical-music-site-deploy/docs/alicloud-oss-cdn-plan.md)
- [docs/release-workflow.md](E:/Workspace/codex/introduction-to-classical-music-site-deploy/docs/release-workflow.md)

## 说明

- 站点中保留 QQ 联系方式，作为正式用户反馈渠道
- 公网站点默认不应暴露本地资源链接或本地磁盘路径
- 如果未来改成子路径部署，而不是域名根目录部署，需要额外补 `base path（基础路径）` 支持
