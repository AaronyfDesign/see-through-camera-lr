-- Info.lua — plugin manifest for See-Through Camera (Lightroom Classic)
return {
  LrSdkVersion = 6.0,
  LrSdkMinimumVersion = 6.0,

  LrPluginName = "See-Through Camera",
  LrToolkitIdentifier = "com.aaronyf.seethrough",
  LrPluginInfoUrl = "https://github.com/AaronyfDesign/see-through-camera-lr",
  LrPluginInfoProvider = "aaronyf",

  VERSION = { major = 0, minor = 2, revision = 0, build = 1 },

  LrLibraryMenuItems = {
    { title = "See-Through: 生成回屏卡片（柔和虚化）", file = "card_soft.lua" },
    { title = "See-Through: 生成回屏卡片（径向模糊）", file = "card_radial.lua" },
    { title = "See-Through: 生成回屏卡片（纯色填充）", file = "card_solid.lua" },
  },

  LrExportMenuItems = {
    { title = "See-Through: 生成回屏卡片（柔和虚化）", file = "card_soft.lua" },
    { title = "See-Through: 生成回屏卡片（径向模糊）", file = "card_radial.lua" },
    { title = "See-Through: 生成回屏卡片（纯色填充）", file = "card_solid.lua" },
  },

  LrExportServiceProvider = {
    title = "机型预览卡片（See-Through）",
    file = "ExportServiceProvider.lua",
  },

  -- (no LrInitPlugin: menu files are declarative and load on click)
}
