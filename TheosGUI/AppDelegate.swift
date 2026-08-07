// MARK: - AppDelegate.swift
// TheosGUI Clone — 主入口

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var rootViewController: UIViewController?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let tabBarController = MainTabBarController()
        self.rootViewController = tabBarController
        updateTabsOrder()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }

    // MARK: - URL Handling
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleIncomingURL(url)
        return true
    }

    func application(_ application: UIApplication,
                     handleOpen url: URL) -> Bool {
        handleIncomingURL(url)
        return true
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        handleIncomingURL(url)
        return true
    }

    private func handleIncomingURL(_ url: URL) {
        // 处理从其他 App 传入的文件 URL
        print("[TheosGUI] handleIncomingURL: \(url)")
        // 导航到文件所在目录
        NotificationCenter.default.post(name: .openFilePath, object: url.path)
    }

    /// 更新 Tab 顺序 (可配置)
    func updateTabsOrder() {
        guard let tabBar = rootViewController as? UITabBarController else { return }
        // 可根据 TGPreferences 调整 tab 顺序
        let tabs = tabBar.viewControllers ?? []
        let order = TGPreferences.shared.integer(forKey: "tabs_order")
        if order > 0 && order <= tabs.count {
            tabBar.selectedIndex = 0
        }
    }
}

extension AppDelegate: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        return true
    }
}

// MARK: - 全局通知名称
extension Notification.Name {
    static let openFilePath = Notification.Name("openFilePath")
    static let consoleCommandExecuted = Notification.Name("consoleCommandExecuted")
    static let wallpaperDidChange = Notification.Name("wallpaperDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
}
