# TheosGUI Clone — Xcode 项目创建指南

## 快速开始

### 1. 创建 Xcode 项目
```
1. 打开 Xcode → New Project → iOS → App
2. Product Name: TheosGUI
3. Organization Identifier: com.iosbx
4. Interface: Storyboard (or SwiftUI — choose UIKit App Delegate)
5. Language: Swift
6. Minimum Deployment Target: iOS 15.0
```

### 2. 导入源文件
将 `TheosGUI/` 目录下的所有 `.swift` 文件拖入 Xcode 项目：
- `AppDelegate.swift` → 替换生成的 AppDelegate
- `TabBarController.swift`
- `Helpers.swift`
- `Info.plist` → 替换生成的 plist
- `Controllers/` 目录 (全部)
- `Models/` 目录 (全部)
- `Managers/` 目录 (全部)
- `Views/` 目录 (全部)

### 3. 删除默认文件
- 删除 Xcode 生成的 `ViewController.swift`
- 删除 `Main.storyboard` (这个项目用编程式 UI)
- 在 `Info.plist` 中删除 `UISceneSession` 相关条目 (如果用 AppDelegate 模式)

### 4. 项目设置
- Build Settings → Swift Language Version: Swift 5.0+
- Targets → Signing & Capabilities: 选自己的 Team
- 可选: 卸载 SceneDelegate (uncheck "Supports multiple scenes")

---

## 项目结构

```
TheosGUI/
├── AppDelegate.swift              # 应用入口，URL 处理
├── TabBarController.swift         # 5 Tab 主界面
├── Helpers.swift                  # 全局工具函数
├── Info.plist                     # 应用配置
├── Controllers/
│   ├── MainRootViewController.swift    # Tab 0 - 文件浏览器 (150 methods)
│   ├── ToolViewController.swift        # Tab 1 - 工具列表
│   ├── ChatViewController.swift        # Tab 2 - AI 聊天 (110 methods)
│   ├── ConsoleViewController.swift     # Tab 3 - 终端控制台 (58 methods)
│   ├── SettingsViewController.swift    # Tab 4 - 设置 (39 methods)
│   ├── FileEditorViewController.swift  # 文本/plist 编辑器 (118 methods)
│   ├── FilePickerViewController.swift  # 文件选择器
│   ├── FilePropertiesViewController.swift  # 文件属性
│   ├── ChatHistoryViewController.swift # 聊天历史
│   ├── ChatSettingsViewController.swift # AI 提供商设置 (72 methods)
│   ├── AppListViewController.swift     # App 列表/解密
│   └── SupportingControllers.swift     # 辅助 VC (DecryptedList, Share, TG*, Alert)
├── Models/
│   └── Models.swift                    # FileItem, ChatMessage, ChatSession 等
├── Managers/
│   ├── TGPreferences.swift             # 偏好设置管理器
│   ├── TGArchiveManager.swift          # 压缩/解压
│   └── Managers.swift                  # TGInsertDylib, TGThumbnail, TDDecrypt 等
└── Views/
    └── Views.swift                     # ChatBubble, ShareAppCell, ConsoleTextView 等
```

---

## 架构说明

### 5 个标签页 (完全匹配原始 App)
| Tab | 名称 | ViewController | 功能 |
|-----|------|----------------|------|
| 0 | 文件 | MainRootViewController | 文件浏览/搜索/压缩/解压/Git/分享/多选 |
| 1 | 工具 | ToolViewController | App列表/解密/Dylib注入/Mach-O工具/Theos项目 |
| 2 | 聊天 | ChatViewController | AI 对话/Markdown/代码块/流式/多Provider |
| 3 | 控制台 | ConsoleViewController | Shell终端/ANSI/编译输出 |
| 4 | 设置 | SettingsViewController | Theos安装/缩放/主题/语言/编辑器配置 |

### 关键管理器
- `TGPreferences` — 基于 plist 的持久化设置 (对应原始 App 16 methods)
- `TGArchiveManager` — zip/unzip 操作 (对应原始 2 class methods)
- `TGInsertDylib` — Mach-O dylib 注入/移除 (对应原始 2 class methods)
- `TGThumbnailGenerator` — 图片/视频缩略图 (对应原始 12 methods)
- `ChatProviderManager` — AI 提供商管理
- `TDDecryptionTask` — IPA 解密任务

### 数据模型
- `FileItem` — 文件/文件夹
- `ChatMessage` — 聊天消息 (user/assistant/system)
- `ChatSession` — 聊天会话
- `ChatContext` — 聊天上下文 (文件引用等)
- `ChatProviderSettings` — AI 提供商配置
- `CompilationResult` — 编译结果

---

## 原始 App vs Clone 对照

| 指标 | 原始 (ObjC) | Clone (Swift) |
|------|-------------|---------------|
| 总类数 | 33,885 | 核心 ~40 类 |
| 总方法数 | 624,172 | 核心 ~500 方法 |
| MainRootVC | 150 methods | 完整实现 |
| ChatVC | 110 methods | 完整实现 |
| FileEditorVC | 118 methods | 完整实现 |
| ConsoleVC | 58 methods | 完整实现 |
| SettingsVC | 39 methods | 完整实现 |
| ChatSettingsVC | 72 methods | 完整实现 |

---

## 注意事项

### 联网权限 (已配置)
| 权限 Key | 用途 |
|----------|------|
| `NSAllowsArbitraryLoads` | 允许 HTTP/HTTPS 任意请求 (AI API / Git clone / Theos 下载) |
| `NSAllowsLocalNetworking` | 允许访问本地网络 (localhost 代理 / 本地编译服务) |
| `localhost` / `127.0.0.1` 例外 | 允许不安全 HTTP 连接到本地服务 |
| `NSLocalNetworkUsageDescription` | 连接本地编译服务和调试器 |
| `NSBonjourServices` | 发现本地 `_http._tcp` 和 `_ssh._tcp` 服务 |

### 文件沙盒权限 (已配置)
| 权限 Key | 用途 |
|----------|------|
| `UIFileSharingEnabled` | iTunes 文件共享 |
| `LSSupportsOpeningDocumentsInPlace` | 原地打开文档 (不复制) |
| `CFBundleDocumentTypes` | 支持打开 data/text/source-code/archive/plist |
| `NSDocumentsFolderUsageDescription` | 浏览文稿目录 |
| `NSDesktopFolderUsageDescription` | 浏览桌面目录 |
| `NSDownloadsFolderUsageDescription` | 浏览下载目录 |
| `NSPhotoLibraryUsageDescription` | 从相册导入图片 |
| `NSCameraUsageDescription` | 扫描二维码 |

### 越狱 vs 非越狱
| 功能 | 非越狱 (沙盒内) | 越狱 (全文件系统) |
|------|:---:|:---:|
| 文件浏览 | 仅沙盒内 | ✅ 全文件系统 |
| Git 操作 | ❌ | ✅ 需要安装 git |
| Dylib 注入 | ❌ | ✅ |
| IPA 解密 | ❌ | ✅ |
| Theos 编译 | ❌ | ✅ |
| Shell 终端 | ❌ | ✅ |
| AI 聊天 | ✅ | ✅ |
| 代码编辑器 | ✅ (沙盒内) | ✅ |
| 文件分享 | ✅ | ✅ |
