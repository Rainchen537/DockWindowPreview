# DockWindowPreview

macOS 原生菜单栏 App，目标是尽量接近 Windows 任务栏悬浮窗口预览：鼠标悬停 Dock 中某个 App 图标时显示该 App 的窗口缩略图，点击缩略图后切换到对应窗口。

## 文件结构

```text
DockWindowPreview/
  DockWindowPreviewApp.swift
  AppSettings.swift
  PermissionsManager.swift
  MouseTracker.swift
  DockInspector.swift
  WindowCollector.swift
  WindowThumbnailProvider.swift
  PreviewPanel.swift
  WindowActivator.swift
  SettingsWindow.swift
  LaunchAtLoginManager.swift
  AppIconFactory.swift
  AppIcon.icns
  Info.plist
DockWindowPreview.xcodeproj/
README.md
```

## 功能阶段

1. 轻量常驻：菜单栏 App、权限提示、全局鼠标监听。
2. Dock 悬停：判断 Dock 区域、通过 Dock.app Accessibility 命中测试读取鼠标下方 Dock 图标，映射到运行中的 App。
3. 预览切换：半透明深色 `NSPanel`、圆角卡片、缩略图、标题、hover 高亮、点击缩略图切换窗口、移出 Dock/面板自动隐藏。
4. 窗口管理：支持关闭预览中的窗口；最小化窗口也会显示在预览中，点击后会尽力取消最小化并切换到该窗口。

## Xcode 创建/打开项目

本仓库已经包含可打开的 Xcode 工程：

```sh
open DockWindowPreview.xcodeproj
```

如果你想从空 Xcode 项目重建：

1. Xcode → File → New → Project。
2. 选择 macOS → App。
3. Interface 选 Storyboard 或 SwiftUI 都可以，但删除模板 UI；Language 选 Swift。
4. 将 `DockWindowPreview/` 下的 Swift 文件加入 target。
5. 将 target 的 Info.plist 指向 `DockWindowPreview/Info.plist`。
6. 保持 `LSUIElement = false`，让 App 在 Dock 和菜单栏都可见，方便用户重新打开设置。
7. 关闭 App Sandbox，或至少不要启用会阻断 Accessibility / screen capture 的沙盒配置。

## 权限

必须开启：

1. System Settings → Privacy & Security → Accessibility：读取 Dock.app UI、raise/focus 指定窗口。
2. System Settings → Privacy & Security → Screen & System Audio Recording：`CGWindowListCreateImage` 生成其他 App 窗口缩略图。

Accessibility 可以通过 `AXIsProcessTrustedWithOptions` 拉起系统提示；屏幕录制可以通过 `CGRequestScreenCaptureAccess` 请求，但开启后通常需要重启 App。

## Info.plist

关键配置在 `DockWindowPreview/Info.plist`：

```xml
<key>LSUIElement</key>
<false/>
<key>CFBundleIconFile</key>
<string>AppIcon</string>
<key>NSAppleEventsUsageDescription</key>
<string>用于辅助激活目标应用窗口。</string>
<key>NSPrincipalClass</key>
<string>NSApplication</string>
```

屏幕录制和 Accessibility 没有常规的 `NS...UsageDescription` plist key；权限在系统设置里控制。

## 运行和调试

命令行构建：

```sh
xcodebuild -project DockWindowPreview.xcodeproj -scheme DockWindowPreview -configuration Debug build
```

运行后 Dock 和菜单栏都会出现 DockWindowPreview。点击 Dock 图标或左键点击菜单栏图标会打开设置，并自动请求缺失的 Privacy & Security 权限；右键或 Control+点击菜单栏图标会打开菜单。

把鼠标移到 Dock 中正在运行的 App 图标上，悬停超过设置中的延迟时间后会显示该 App 的窗口缩略图。默认延迟为 100ms。

打开设置可调整悬停延迟、缩略图高度、窗口标题显示、开机启动、调试日志。调试日志输出到 Console.app 或 Xcode debug console，前缀为 `[DockWindowPreview]`。

## 已知限制

macOS 没有公开 Dock hover API，也没有公开 API 可以从 Dock 图标直接得到 bundle identifier。因此 `DockInspector` 是 best-effort：通过 Dock.app 的 Accessibility hit-test 读取 AXTitle / AXDescription / AXIdentifier，再用名称映射到 `NSWorkspace.runningApplications`。

公开 Accessibility API 也不可靠暴露 CGWindowID。`WindowActivator` 不使用私有 `_AXUIElementGetWindow`，而是通过标题、位置、尺寸匹配 AXWindow，然后执行 `kAXRaiseAction`、设置 `AXMain` 和 `AXFocused`。匹配失败时会至少激活目标 App。

`CGWindowListCopyWindowInfo(.optionOnScreenOnly)` 只能稳定拿到可见窗口。最小化窗口通过 Accessibility 的 `AXMinimized` best-effort 补充进列表；公开 API 无法截图最小化窗口，因此这类卡片会显示“已最小化”占位图，点击后会尝试将 `AXMinimized` 设为 `false` 并聚焦窗口。

Dock 自动隐藏、Dock 放大、多个显示器、Stage Manager、全屏 Space 会影响 Dock 区域推断和面板定位，后续可以增加 AX 树缓存、Dock 图标 frame 缓存、多屏坐标修正和更细的 debounce。
