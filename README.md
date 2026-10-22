# See-Through Camera — Lightroom Classic plugin

[中文版说明 →](README.zh-CN.md)

A Lightroom Classic plugin that turns the selected photo into a
"see-through camera" card: the photo appears on the camera body's LCD
screen, with blurred background, and a caption line with model / lens /
exposure. The actual rendering is done by the
[see-through-camera](https://github.com/AaronyfDesign/see-through-camera)
CLI; this plugin provides the in-Lightroom experience.

## How it works

```
menu click → selected photo → full-resolution JPEG export (keeps EXIF)
           → external CLI render (--body auto --bg <mode>) → reveal in Finder
```

- The export step is the standard Lightroom pipeline, so the CLI receives a
  real JPEG with full EXIF and resolves the body profile itself (`--body
  auto` matches `body_profiles/*/profile.json` aliases). No per-model table
  is maintained in the plugin.
- Three background modes are exposed as separate menu items under
  **File → Plugin Extras**: soft blur / radial blur / solid fill.

## Export integration

The plugin also hooks into Lightroom's standard export flow: in
**File → Export…**, pick **「机型预览卡片（See-Through）」** in the
"Export To" dropdown and choose a background mode in the panel. Every
rendered photo gets a card, collected in the plugin's `output/` folder
and revealed in Finder when the export finishes.

## Supported bodies

Kept in sync with `body_profiles/` of
[see-through-camera](https://github.com/AaronyfDesign/see-through-camera)
(EXIF model names and the matching profile):

| Body | Profile |
| --- | --- |
| Nikon Z 6III (NIKON Z6_3) | `z63` |
| Nikon ZR | `zr` |
| Nikon Z 5II / Z 5II C | `z52` / `z5iic` |
| Nikon Z 6 / Z 6II | `z6` / `z62` |
| Nikon Z 7 / Z 7II | `z7` / `z72` |
| Nikon Z 8 / Z 9 | `z8` / `z9` |
| Nikon Z f / Z fc | `zf` / `zfc` |
| Nikon Z 5 / Z 30 / Z 50II | `z5` / `z30` / `z502` |
| Nikon D850 | `d850` |
| LEGO camera (easter egg) | `lego` |

Unknown models fall back to the `lego` body. Adding a body only requires
a new profile in the CLI repo — no plugin change needed.

## Requirements

- Lightroom Classic (developed and verified on 15.4.1; macOS arm64 and Windows both supported)
- Python 3 with Pillow (the CLI's dependency)
- A local checkout of [see-through-camera](https://github.com/AaronyfDesign/see-through-camera)

## Install

> **Dependencies (read this first): the plugin is only a dispatcher —
> the card is actually rendered by an external Python CLI. Every
> install method requires:**
> 1. **Python 3** (3.9+) on PATH, or set explicitly via environment
>    variable;
> 2. **Pillow**: `python -m pip install Pillow` — without it card
>    generation will always fail;
> 3. **`cli/watermark.py` and `body_profiles/` of the
>    see-through-camera repo** (bundled in the Release ZIP; only
>    needed separately when installing from a clone). When
>    troubleshooting, start with `debug.txt` and `cli.log` in the
>    plugin's `output/` folder.

Prerequisites: a local clone of [see-through-camera](https://github.com/AaronyfDesign/see-through-camera) (a sibling directory is auto-detected) and Python 3 with Pillow (`python3 -m pip install Pillow`).

1. Run:

   ```sh
   scripts/install.sh
   ```

   The script detects your python3 and the see-through-camera checkout,
   generates a machine-specific `Config.lua`, copies the plugin into
   `~/Library/Application Support/Adobe/Lightroom/Modules/`, registers it
   in Lightroom's plugin-path preference — then restart Lightroom
   Classic.

   If your paths differ, override via environment variables:

   ```sh
   SEE_THROUGH_CAMERA_CLI=/path/to/see-through-camera/cli/watermark.py \
   SEE_THROUGH_CAMERA_PYTHON=/path/to/python3 \
   scripts/install.sh
   ```

2. In Lightroom: select a photo → **File → Plugin Extras → See-Through:
   生成回屏卡片（…）**. The card opens in Finder when done.

### Windows

**方式 A（推荐）：下载 Release ZIP，双击安装。** 到
[Releases](https://github.com/AaronyfDesign/see-through-camera-lr/releases)
下载 `SeeThroughCamera-windows.zip`，解压后双击 **install.cmd**。
ZIP 内已内置插件、CLI 和全部机型 profile，无需克隆任何仓库。也可以
把 `SeeThroughCamera.lrplugin` 文件夹直接拖到 install.cmd 图标上，
效果相同。装完重启 Lightroom Classic。

**方式 B：从仓库安装。** 克隆本仓库与 see-through-camera 仓库后运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

It copies the plugin into `%APPDATA%\Adobe\Lightroom\Modules\`
(Lightroom auto-loads plugins from there — no preference registration
needed) and generates `Config.lua` with your paths. Overrides are the
same two environment variables. Uninstall on Windows: delete the plugin
folder from `Modules`.

## Uninstall

```sh
scripts/uninstall.sh
```

## Output & diagnostics

Cards and intermediate files land in the plugin folder's `output/`
directory: `card_*.jpg` (result), `debug.txt` (plugin trace),
`cli.log` (renderer stderr). Delete them freely.

## Project layout

```
src/SeeThroughCamera.lrplugin/
  Info.lua            plugin manifest (declarative menu items + export service)
  Config.lua          local paths (python / cli) — generated by install.sh
  SeeThroughCard.lua  shared implementation (all three menu entries)
  ExportServiceProvider.lua  custom export destination "机型预览卡片"
  card_{soft,radial,solid}.lua  thin menu-entry shims
scripts/install.sh    copy into LR Modules + fix plugin-path preference
scripts/uninstall.sh  remove both
```

## Development notes (verified SDK facts)

These cost real debugging time — don't re-learn them:

- `LrPhoto:requestJpegThumbnail`'s callback receives the **JPEG bytes
  themselves** as its first argument, not a path; and the JPEG it produces
  carries **no EXIF at all** and comes in sensor orientation. That is why
  this plugin exports via `LrExportSession` instead (full resolution,
  correct EXIF/orientation for free).
- Metadata getters (`getFormattedMetadata`, `getRawMetadata`) yield
  internally: calling them inside `pcall` fails with "Yielding is not
  allowed within a C or metamethod call". Call them directly inside async
  tasks.
- `LrLogger` never produced output on this machine; the plugin logs via
  plain `io.open` to `output/debug.txt`.
- Camera model as reported by `cameraModel` (e.g. `NIKON Z6_3`) must match
  an entry in the CLI's `body_profiles/*/profile.json` `aliases`.
- Plugin menu items are declared in `Info.lua` (`LrLibraryMenuItems`); an
  `LrInitPlugin`-based approach did not register menus reliably.
- `LrDialogs` has no `showInFinder` (caused an error dialog after every
  successful render, see issue #1) — the correct API is
  `LrShell.revealInShell(path)`.
- Export destination only takes effect via the internal keys
  (`export_destinationType = 'specificFolder'` +
  `export_destinationPathPrefix`); the UI-preset `LR_export_*` keys are
  ignored by the session. `rendition:renderImage()` exists only in the
  export-provider context; the menu-item path must use
  `doExportOnCurrentTask()`.
