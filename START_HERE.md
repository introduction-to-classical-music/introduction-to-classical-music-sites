# 互联网部署接手入口

这份文件面向新的维护者或合作开发者。

当前这个仓库已经完成了“公网部署前的本地收口”，剩余工作主要集中在域名、备案和阿里云线上操作。

## 当前状态

已经完成的部分：

- 站点按版本归档保存在 `site/`
- `site/current` 与 `site/v0.1.0` 已准备好
- 已有本地审计脚本，可检查：
  - `localhost`
  - `127.0.0.1`
  - `__local-resource`
  - 测试专栏与测试链接
  - 本地绝对路径
- 已有静态元文件生成脚本，可生成：
  - `robots.txt`
  - `sitemap.xml`
  - `404.html`
- 已有阿里云 `OSS` 上传脚本模板
- 已有 `CDN` 刷新脚本模板

## 仍未完成的部分

这些工作需要由掌握正式域名和阿里云环境的人完成：

- 域名购买或确认
- 备案
- `OSS Bucket` 创建与权限配置
- `CDN` 创建与回源配置
- `HTTPS` 证书申请和绑定
- 正式域名解析

## 推荐接手顺序

1. 阅读 [README.md](README.md)
2. 阅读 [docs/alicloud-oss-cdn-plan.md](docs/alicloud-oss-cdn-plan.md)
3. 复制并填写 `config/alicloud-deploy.example.json`
4. 运行站点审计
5. 用正式域名生成 `robots.txt / sitemap.xml / 404.html`
6. 通过 `scripts/publish-oss.ps1` 上传静态站点
7. 通过 `scripts/refresh-cdn.ps1` 刷新 `CDN`
8. 做公网抽样验收

## 关键边界

- 这个仓库只负责静态站点与互联网部署
- 不负责桌面应用源码
- 不负责安装版与便携版二进制分发
- 不保存个人资料库原始源数据
- 站点来源应通过脚本参数传入，不把个人路径写死在仓库中

## 建议验收点

- 首页
- 关于页
- 作曲家目录页
- 至少一条录音页
- `robots.txt`
- `sitemap.xml`
- `404.html`
- `HTTPS` 是否生效
- `CDN` 刷新后内容是否一致
