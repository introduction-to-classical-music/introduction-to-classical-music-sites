# 不全书互联网部署仓库

这个仓库只负责 **站点产物与互联网部署**，不包含桌面应用源码、维护工具源码或版本检索服务源码。

## 仓库目的

- 保存每个版本的静态站点归档
- 为阿里云 `OSS（对象存储） + CDN（内容分发网络）` 部署提供脚本和文档
- 为后续公网更新、回滚、审查和多设备同步提供稳定工作区

## 当前目录结构

- `site/current`：当前准备上线的站点副本
- `site/v0.1.0`：`v0.1.0` 版本站点归档
- `docs/`：部署说明、回滚说明、发布检查清单
- `scripts/`：站点同步、上线前审计、静态元文件生成脚本
- `config/`：部署配置模板

## 数据来源

这个仓库不直接生成站点。站点源头固定为：

- `F:\personal\Sunhaoran\OneDrive\music\buquanshu\sites`

每次更新时，都从该目录复制最新站点到本仓库，再进行公网部署准备。

## 推荐部署方案

推荐使用：

- `Alibaba Cloud OSS（阿里云对象存储）` 托管静态文件
- `Alibaba Cloud CDN（阿里云内容分发网络）` 做缓存和加速
- 独立域名 + `HTTPS（加密传输）`

详细方案见：

- [docs/alicloud-oss-cdn-plan.md](E:/Workspace/codex/introduction-to-classical-music-site-deploy/docs/alicloud-oss-cdn-plan.md)
- [docs/release-workflow.md](E:/Workspace/codex/introduction-to-classical-music-site-deploy/docs/release-workflow.md)

## 本地常用命令

同步版本站点到仓库：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage-site.ps1 -Version v0.1.0
```

扫描公网发布风险：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\audit-site.ps1 -Version v0.1.0
```

在拿到正式域名后生成 `robots.txt / sitemap.xml / 404.html`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write-static-metadata.ps1 -Version v0.1.0 -BaseUrl https://your-domain.example
```

## 当前公网边界

- 站点按“域名根目录”部署设计，例如 `https://your-domain.example/`
- 站点中保留 QQ 联系方式，作为正式用户反馈渠道
- 公网站点默认不应暴露本地资源链接或本地磁盘路径
- 若后续改为子路径部署，需要额外补 `base path（基础路径）` 支持
