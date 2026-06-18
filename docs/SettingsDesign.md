# macOS 轻量工具设置面板规范

这套设置面板用于 menu bar utility。默认交互是点击菜单栏图标弹出 popover，不使用独立设置窗口。

## 结构

1. Header：App Icon、产品名、短描述和版本号。
2. Section Card：按功能分组，例如预览、系统、权限、关于。
3. Row：左侧是设置项名称，右侧是控件或状态。

## 尺寸

- Popover：408 x 640，可滚动。
- 内容宽度：372。
- 外边距：18。
- Section 间距：16。
- 卡片圆角：17。
- 卡片内边距：18。
- Header 图标：52 x 52。
- 状态胶囊高度：24。

## 组件

- `SettingsHeaderView`：统一 Header。
- `SettingsCardView`：统一分组卡片。
- `SettingsSectionHeaderView`：Section 标题和 SF Symbol。
- `SettingsPill`：数值和状态胶囊，支持 neutral、accent、success、warning、danger。
- `SettingsUI`：面板尺寸、间距、按钮、开关、分割线和基础标签工厂。

## 视觉

- 背景使用 `NSVisualEffectView` 的 `.popover` material。
- Section 使用半透明卡片和统一边框。
- 主强调色使用系统 accent color。
- 成功状态使用绿色胶囊。
- 禁用状态交给 AppKit 控件原生 disabled 样式，并保持按钮尺寸不变。

## 复用方式

新项目可以复制 `SettingsComponents.swift`，然后让自己的设置控制器只负责业务状态绑定、按钮 action、权限或更新逻辑。不要把底层功能逻辑写进组件层。
