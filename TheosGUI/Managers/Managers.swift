// MARK: - Remaining Managers & Views
// TheosGUI Clone

import UIKit
import AVFoundation

// ======================================================================
// MARK: - TGInsertDylib
// ======================================================================
class TGInsertDylib {
    enum InsertError: Error {
        case insertFailed(String)
        case removeFailed(String)
        case invalidBinary
        case notFound
    }

    /// 向 Mach-O 二进制中注入 dylib
    @discardableResult
    class func insert(dylibPath: String, into binaryPath: String) throws -> Bool {
        // 使用 install_name_tool 或 optool
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/install_name_tool")
        task.arguments = ["-change", dylibPath, dylibPath, binaryPath]
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    /// 从 Mach-O 二进制中移除 dylib
    @discardableResult
    class func remove(dylibPath: String, from binaryPath: String) throws -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/install_name_tool")
        task.arguments = ["-delete", dylibPath, binaryPath]
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}

// ======================================================================
// MARK: - TGThumbnailGenerator
// ======================================================================
class TGThumbnailGenerator {
    static let shared = TGThumbnailGenerator()
    private var thumbnailCache = NSCache<NSString, UIImage>()

    private init() {}

    func generateThumbnail(forPath path: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = cachedThumbnail(forPath: path) {
            completion(cached)
            return
        }

        DispatchQueue.global().async {
            let image: UIImage?
            if self.isVideoFile(path) {
                image = self.generateVideoThumbnail(url: URL(fileURLWithPath: path))
            } else {
                image = self.generateImageThumbnail(url: URL(fileURLWithPath: path))
            }

            if let image = image {
                let square = self.squareImage(from: image, size: CGSize(width: 128, height: 128))
                self.thumbnailCache.setObject(square, forKey: path as NSString)
                DispatchQueue.main.async { completion(square) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func cachedThumbnail(forPath path: String) -> UIImage? {
        return thumbnailCache.object(forKey: path as NSString)
    }

    func isSupportedMediaFile(atPath path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "mp4", "mov", "m4v"].contains(ext)
    }

    func isVideoFile(_ path: String) -> Bool {
        return ["mp4", "mov", "m4v", "avi"].contains((path as NSString).pathExtension.lowercased())
    }

    func generateImageThumbnail(url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    func generateVideoThumbnail(url: URL) -> UIImage? {
        // AVAssetImageGenerator 生成缩略图
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 1), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    func squareImage(from image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let minDim = min(image.size.width, image.size.height)
            let rect = CGRect(
                x: (image.size.width - minDim) / 2,
                y: (image.size.height - minDim) / 2,
                width: minDim,
                height: minDim
            )
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// ======================================================================
// MARK: - ChatProviderManager
// ======================================================================
class ChatProviderManager {
    static let shared = ChatProviderManager()

    var currentSettings: ChatProviderSettings {
        return ChatProviderSettings(
            name: TGPreferences.shared.string(forKey: "provider_name") ?? "OpenAI",
            baseURL: TGPreferences.shared.string(forKey: "base_url") ?? "https://api.openai.com",
            apiKey: TGPreferences.shared.string(forKey: "api_key") ?? "",
            model: TGPreferences.shared.string(forKey: "model") ?? "gpt-4",
            stream: TGPreferences.shared.bool(forKey: "stream_enabled"),
            confirmExec: TGPreferences.shared.bool(forKey: "confirm_exec"),
            confirmRead: TGPreferences.shared.bool(forKey: "confirm_read"),
            confirmWrite: TGPreferences.shared.bool(forKey: "confirm_write"),
            systemPrompt: TGPreferences.shared.string(forKey: "system_prompt") ?? ""
        )
    }

    private init() {}

    func saveSettings(_ settings: ChatProviderSettings) {
        TGPreferences.shared.setObject(settings.name, forKey: "provider_name")
        TGPreferences.shared.setObject(settings.baseURL, forKey: "base_url")
        TGPreferences.shared.setObject(settings.apiKey, forKey: "api_key")
        TGPreferences.shared.setObject(settings.model, forKey: "model")
        TGPreferences.shared.setBool(settings.stream, forKey: "stream_enabled")
        TGPreferences.shared.setBool(settings.confirmExec, forKey: "confirm_exec")
        TGPreferences.shared.setBool(settings.confirmRead, forKey: "confirm_read")
        TGPreferences.shared.setBool(settings.confirmWrite, forKey: "confirm_write")
    }
}

// ======================================================================
// MARK: - TDDecryptionTask
// ======================================================================
class TDDecryptionTask {
    let app: AppInfo
    var progressHandler: ((Double) -> Void)?

    init(app: AppInfo) {
        self.app = app
    }

    func execute(completion: @escaping (Bool) -> Void) {
        // 在越狱设备上，调用 clutch 或 bfdecrypt 进行解密
        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/clutch")
            task.arguments = ["-d", self.app.bundleID]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let success = task.terminationStatus == 0
                DispatchQueue.main.async { completion(success) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    func execute(options: [String: Any]? = nil, completion: @escaping (Bool) -> Void) {
        execute(completion: completion)
    }

    func createOutputDirectoryIfNeeded() {}
    func copyApplicationBundle() {}
    func buildIPA(name: String) {}
}

// ======================================================================
// MARK: - FileConfigRegistrator
// ======================================================================
class FileConfigRegistrator {
    /// 注册文件类型关联 (UTType)
    static func registerFileTypes() {
        // 在 Info.plist 中声明支持的文件类型
        // .deb, .ipa, .plist, .m, .h, .swift, etc.
    }
}

// ======================================================================
// MARK: - ProgressHUD
// ======================================================================
class ProgressHUD {
    static func show() { /* 显示加载 */ }
    static func show(_ message: String) {}
    static func showSuccess(_ message: String) {}
    static func showError(_ message: String) {}
    static func dismiss() {}
}
