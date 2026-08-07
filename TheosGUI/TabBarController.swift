// MARK: - MainTabBarController.swift
// TheosGUI Clone — 5 Tab 主界面

import UIKit

class MainTabBarController: UITabBarController {

    // MARK: - View Controllers
    private lazy var filesNav: UINavigationController = {
        let vc = MainRootViewController()
        vc.tabBarItem = UITabBarItem(
            title: "文件",
            image: UIImage(systemName: "folder"),
            tag: 0
        )
        return UINavigationController(rootViewController: vc)
    }()

    private lazy var toolsNav: UINavigationController = {
        let vc = ToolViewController()
        vc.tabBarItem = UITabBarItem(
            title: "工具",
            image: UIImage(systemName: "wrench"),
            tag: 1
        )
        return UINavigationController(rootViewController: vc)
    }()

    private lazy var chatNav: UINavigationController = {
        let vc = ChatViewController()
        vc.tabBarItem = UITabBarItem(
            title: "聊天",
            image: UIImage(systemName: "bubble.left.and.bubble.right"),
            tag: 2
        )
        return UINavigationController(rootViewController: vc)
    }()

    private lazy var consoleNav: UINavigationController = {
        let vc = ConsoleViewController()
        vc.tabBarItem = UITabBarItem(
            title: "控制台",
            image: UIImage(systemName: "terminal"),
            tag: 3
        )
        return UINavigationController(rootViewController: vc)
    }()

    private lazy var settingsNav: UINavigationController = {
        let vc = SettingsViewController()
        vc.title = "设置"
        vc.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape"),
            tag: 4
        )
        return UINavigationController(rootViewController: vc)
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [
            filesNav,
            toolsNav,
            chatNav,
            consoleNav,
            settingsNav
        ]

        setupTabBarAppearance()
        updateWallpaper()
    }

    // MARK: - 主题 & 壁纸
    private func setupTabBarAppearance() {
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        let isDark = traitCollection.userInterfaceStyle == .dark
        tabBar.barTintColor = isDark ? .black : .white
    }

    func updateWallpaper() {
        // 从 TGPreferences 读取壁纸设置
        // 原始 App 使用 updateWallpaper / updateWallpaperBrightness
        // 这里简化为系统背景
        view.backgroundColor = .systemBackground
    }
}
