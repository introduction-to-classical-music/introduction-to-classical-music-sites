## 变更摘要

<!-- 简述改动、影响范围（脚本 / 文档 / 站点产物 / CI）与关联任务/Issue -->

## 检查清单（按需勾选，不适用的项写 N/A）

### 基础
- [ ] `git status` 干净；未把构建缓存、临时目录、个人路径带入仓库
- [ ] Windows 维护者已配置 `core.longpaths=true`（见 [docs/windows-long-paths.md](../docs/windows-long-paths.md)）
- [ ] 未提交密钥/令牌/个人私密信息（不打印、不截图、不写入 manifest/日志）
- [ ] `site/current`/`site/v0.1.0` 未被手工修改；如确需更新，说明来源的导出/发布流程与批准记录
- [ ] 提交/PR 描述包含回滚方式（revert 提交或命令）

### 脚本 / CI
- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-site-release.ps1` 通过（当前为 67 checks，exit 0）
- [ ] 若修改工作流：`on` 触发（push 任意分支 / pull_request / workflow_dispatch）、`windows-latest`、脚本存在性检查均有效；YAML 可解析

### 站点发布（涉及 `site/`、manifest、Pages/根站点时必填）
- [ ] 审计通过：`scripts/audit-site.ps1`（Pages 模式加 `-ExpectedSiteBase /introduction-to-classical-music-sites/ -SkipStaticMetadata`；根站点使用真实 `-BaseUrl` 且不跳过 sitemap/robots 检查）
- [ ] `site-release-manifest.json` 存在、可解析；`appVersion`/`siteBase` 正确
- [ ] 摘要语义已核对（见 [docs/site-release-digest.md](../docs/site-release-digest.md)）：`sourceDigest` 为 W10a 规范化值；`siteDigest` 仅对当次构建有效；记录 manifest SHA256
- [ ] 内部 base 链接检查通过（Pages 产物 0 缺 base；根站点 sitemap/robots 与 base 一致）
- [ ] 无本机绝对路径、`__local-resource`、`localhost`/`127.0.0.1`、测试专栏/测试链接
- [ ] 发布记录已新增/更新（`docs/releases/…`，含提交 SHA、diff 分类、build/抽样、回滚、是否取代旧记录）
- [ ] 涉及 `pages` 推送时：已获 root/用户批准；fast-forward；发布后验证 Pages build（commit 匹配）与线上抽样；回滚方案就绪
- [ ] 涉及根站点/OSS/CDN 时：确认 D6 正式域名/凭据与授权边界（当前根站点仍待 D6）

### 验证记录
- [ ] 本地命令与结果（命令、退出码、关键输出/日志路径）：
  ```
  # 例：
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-site-release.ps1   # exit 0, 67 checks
  ```

## 回滚

<!-- 回滚提交 SHA / revert 命令 / 产物恢复方式；若无需回滚写 N/A -->
