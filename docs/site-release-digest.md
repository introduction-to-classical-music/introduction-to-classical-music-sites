# 站点发布摘要语义（sourceDigest / siteDigest）

本文说明部署仓库中 `site-release-manifest.json` 的摘要字段语义、复算方法和边界。摘要算法与 W10a EOL 规范化由软件仓库 `scripts/lib/library-ops.mjs` 实现（软件侧文档见 `<software>/docs/site-release-digest.md`）；本文件面向站点发布/验收/回滚操作。

## 字段

| 字段 | 内容 |
|---|---|
| `sourceDigest` | 来源资料库的目录摘要：`library.manifest.json` + `content/` + `assets/` |
| `siteDigest` | 导出站点目录的摘要（**排除** `site-release-manifest.json` 自身） |
| manifest SHA256 | `site-release-manifest.json` 文件本身的 SHA-256（用于确认线上文件与构建证据一致） |

摘要算法：对每个文件计算 SHA-256（文本文件先做 EOL 规范化），把 `path\0sha256\n` 按相对路径排序拼接后再做一次 SHA-256。

## W10a：sourceDigest 的 EOL 规范化（CRLF/LF 可复算）

- 官方库仓库 `core.autocrlf=true` 且无 `.gitattributes`，Windows 工作树中的文本文件为 CRLF；W10a 之前 `sourceDigest` 直接哈希工作树字节，因此同一 commit 在 LF checkout/CI 上会得到不同值（旧值 `7e1a2316…31620` 属于此类，**已废弃**）。
- W10a 起：`.json/.md/.txt/.yml/.yaml/.css/.html/.js/.mjs/.xml/.csv/.tsv/.svg` 等文本文件在哈希前先做 `CRLF/CR → LF` 规范化；二进制（图片/音频等）仍按原始字节哈希。
- 结果：官方库 `Salon_library@c47f519` 的 `sourceDigest` 在 Windows CRLF 工作树与 LF checkout/CI 上**一致**，当前值为：

```
sourceDigest = cfa59423542c6df8089059c09a22275e4256a8398850bc6d5a3fc2378463b333
```

- 该规范化只影响摘要计算，不修改库内容、不写 `.gitattributes`，也不要求维护者改变 checkout 方式；W10a 前已存在的 LF 快照摘要不变。

## siteDigest 仍受 `builtAt` 影响（构建内有效，不是跨构建稳定值）

- `siteDigest` 覆盖导出目录中除 manifest 外的全部文件，**包含** `.icm-build-meta.json`；该文件含每次构建的 `builtAt` 时间戳，因此 `siteDigest` 每次构建都会变化。
- 正确语义：**完整性封条**（确认某次构建的产物未被篡改/与记录一致），不是可复现构建证明。
- 当前 Pages 发布（`c6e42a4`）的值：

```
siteDigest = 7a63349259952ccf3ca4cd1e755a3ddb7b42ec75c4c2573d78957cfd64d2eb68
manifest SHA256 = 1AB7D3D4A7F20EC5BB5FF1042375C7200542A009D7A6553A8C98C8FF1EB7CE0C
```

- 发布记录必须同时记录 `siteDigest` 与 manifest SHA256；验收时对**同一份产物**复算一致即可，不能拿不同时间构建的 `siteDigest` 互比。

## Pages 0.1.1 W10c 产物的文件构成（569 files）

| 类别 | 数量 | 说明 |
|---|---|---|
| HTML | 462 | 页面（404.html 不存在于 Pages 构建） |
| `library-assets/` | 100 | 45 legacy + 55 managed（来自官方库 assets） |
| `_astro/` | 2 | `about.Zfhg6SaR.css`、`SearchPanel.astro_astro_type_script_index_0_lang.DP1T1OlE.js` |
| 根文件 | 2 | `favicon.ico`、`favicon.svg` |
| 其他 | 2 | `.nojekyll`、`.icm-build-meta.json` |
| **siteDigest 覆盖文件** | **568** | 上述合计（不含 manifest） |
| `site-release-manifest.json` | 1 | 不参与 siteDigest |
| **目录文件总数** | **569** | |

- 相对上一发布（`e498eb3`，568 files）**+1** 为 `_astro/SearchPanel…DP1T1OlE.js`：W10b 索引/搜索链接生成改动后的 Astro 客户端 chunk；其余文件集不变、无删除。
- 旧记录中的 `sourceDigest=7e1a…`（W2b `e498eb3`）已被 W10a 规范化值 `cfa594…` 取代；见 [releases/2026-11-17-v0.1.1-pages-w10.md](releases/2026-11-17-v0.1.1-pages-w10.md)。

## 复算方法

> 复算需要与发布时匹配的软件仓库检出版本（`9adfd93` 或更新且含 W10a 的提交）与官方库 `c47f519`。

```powershell
# 1) sourceDigest：官方库目录（manifest + content + assets）
cd <software-repo>
node --input-type=module -e @'
import { hashDirectory } from "./scripts/lib/library-ops.mjs";
const r = await hashDirectory("<official-library>", { includePrefixes: ["library.manifest.json", "content", "assets"] });
console.log(r.digest, r.files.length);
'@
# 期望：cfa59423542c6df8089059c09a22275e4256a8398850bc6d5a3fc2378463b333（111 个源文件）

# 2) siteDigest：导出站点目录（排除 manifest；需用同一批产物）
node --input-type=module -e @'
import { hashDirectory } from "./scripts/lib/library-ops.mjs";
const r = await hashDirectory("<exported-pages-dir>", { exclude: ["site-release-manifest.json"] });
console.log(r.digest, r.files.length);
'@
# 期望：7a63349259952ccf3ca4cd1e755a3ddb7b42ec75c4c2573d78957cfd64d2eb68（568 个文件，针对 c6e42a4 当次产物）

# 3) manifest 文件本身
Get-FileHash "<exported-pages-dir>\site-release-manifest.json" -Algorithm SHA256
# 期望：1AB7D3D4A7F20EC5BB5FF1042375C7200542A009D7A6553A8C98C8FF1EB7CE0C（c6e42a4）
```

线上验证：下载 `/introduction-to-classical-music-sites/site-release-manifest.json`，比对字段与 SHA256 即可；`sourceDigest` 需结合官方库复算，`siteDigest` 仅作当次产物封条。

## 边界与注意事项

- 摘要用于**完整性/可追溯**，不是可复现构建证明：`builtAt`、构建顺序等仍会影响 `siteDigest`。
- `sourceDigest` 的规范化只对已知文本扩展名生效；新增二进制/未知扩展名仍按字节哈希（跨平台一致）。
- 不要手工编辑 `site-release-manifest.json` 或手工拼 digest；产物必须由 `export-site-release.mjs` 生成。
- 摘要不包含部署配置（`config/`）、脚本或 git 历史；发布记录中的提交 SHA/Pages build 记录用于补充追溯。
- 相关：发布流程见 [release-workflow.md](release-workflow.md)，最新发布记录见 [releases/2026-11-17-v0.1.1-pages-w10.md](releases/2026-11-17-v0.1.1-pages-w10.md)。
