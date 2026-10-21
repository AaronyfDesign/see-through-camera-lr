# See-Through Camera — Lightroom Classic 插件

[English →](README.md)

一个 Lightroom Classic 插件：把选中的照片生成「回屏卡片」——照片出现在
相机机身 LCD 上，背景按所选模式虚化或填充，底部附机型 / 镜头 / 曝光参数
两行文字。实际渲染由
[see-through-camera](https://github.com/AaronyfDesign/see-through-camera)
的 CLI 完成，本插件提供 Lightroom 内的使用体验。

## 工作方式

```
菜单点击 → 选中照片 → 全分辨率 JPEG 导出（保留 EXIF）
        → 调用 CLI 渲染（--body auto --bg <模式>）→ Finder 中显示
```

- 导出走 Lightroom 标准导出管线，CLI 拿到的是带完整 EXIF 的真实 JPEG，
  机型 profile 由 CLI 自行匹配（`--body auto` 按
  `body_profiles/*/profile.json` 的 aliases），插件里不再维护机型表。
- 三种背景模式对应 **文件 → 增效工具额外信息** 下的三个菜单项：
  柔和虚化 / 径向模糊 / 纯色填充。

## 环境要求

- Lightroom Classic（在 15.4.1 / macOS arm64 上开发验证）
- Python 3 及 Pillow（CLI 的依赖）
- 本地有 [see-through-camera](https://github.com/AaronyfDesign/see-through-camera) 仓库

## 安装

1. 编辑 `src/SeeThroughCamera.lrplugin/Config.lua`，把 `cli` 指向你的
   see-through-camera 检出（`cli/watermark.py`），`python` 指向你的
   Python 3 解释器。
2. 运行：

   ```sh
   scripts/install.sh
   ```

   脚本会把插件复制到 `~/Library/Application Support/Adobe/Lightroom/
   Modules/` 并注册插件路径偏好，然后重启 Lightroom Classic。
3. 在 Lightroom 里选中一张照片 → **文件 → 增效工具额外信息 →
   See-Through: 生成回屏卡片（…）**，完成后卡片在 Finder 中打开。

## 卸载

```sh
scripts/uninstall.sh
```

## 输出与诊断

卡片和中间产物都在插件目录的 `output/` 下：`card_*.jpg`（成品）、
`debug.txt`（插件日志）、`cli.log`（渲染器 stderr），可随时删除。

## 目录结构

```
src/SeeThroughCamera.lrplugin/
  Info.lua            插件清单（声明式菜单项）
  Config.lua          本机路径（python / cli）——安装前先改
  SeeThroughCard.lua  共享实现（三个菜单项共用）
  card_{soft,radial,solid}.lua  薄入口
scripts/install.sh    复制到 LR Modules + 修正插件路径偏好
scripts/uninstall.sh  两处一并移除
```

## 开发备忘（实测结论）

以下是花了真实调试时间换来的事实，勿重新踩坑：

- `LrPhoto:requestJpegThumbnail` 回调第一参数是 **JPEG 二进制数据本身**
  而非路径；且产出的 JPEG **完全无 EXIF**、按传感器方向输出（竖拍是横
  图）。所以正式版改用 `LrExportSession` 导出（全分辨率、EXIF 与方向
  天然正确）。
- 元数据读取（`getFormattedMetadata`、`getRawMetadata`）内部会 yield，
  包在 `pcall` 里会报 "Yielding is not allowed within a C or metamethod
  call"。在异步任务里直接调用即可。
- `LrLogger` 在本机从未产出过日志；插件用普通 `io.open` 写
  `output/debug.txt`。
- `cameraModel` 报出的机型名（如 `NIKON Z6_3`）必须能在 CLI 的
  `body_profiles/*/profile.json` `aliases` 里匹配到。
- 菜单项用 `Info.lua` 的 `LrLibraryMenuItems` 声明；`LrInitPlugin` 方式
  注册菜单不可靠。
