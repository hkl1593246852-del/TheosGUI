// MARK: - ToolViewController.swift
// TheosGUI Clone — 工具列表

import UIKit

class ToolViewController: UIViewController {

    // MARK: - Properties
    private var tableView: UITableView!

    private let tools: [(section: String, items: [ToolItem])] = [
        ("逆向工程", [
            ToolItem(name: "App 列表", icon: "app.badge", action: .appList),
            ToolItem(name: "已解密列表", icon: "lock.open", action: .decryptedList),
            ToolItem(name: "进程选择", icon: "cpu", action: .processPicker),
            ToolItem(name: "Dylib 注入", icon: "syringe", action: .dylibInject),
            ToolItem(name: "Mach-O 工具", icon: "hammer", action: .machOTool),
        ]),
        ("开发", [
            ToolItem(name: "Theos 项目", icon: "gearshape.2", action: .theosProject),
            ToolItem(name: "编译项目", icon: "play.circle", action: .compileProject),
            ToolItem(name: "清理项目", icon: "trash.circle", action: .cleanProject),
            ToolItem(name: "创建 Deb", icon: "archivebox", action: .createDeb),
        ]),
        ("实用工具", [
            ToolItem(name: "快速目录", icon: "folder.badge.person.crop", action: .quickDir),
            ToolItem(name: "网页浏览", icon: "safari", action: .webView),
            ToolItem(name: "缩略图生成", icon: "photo", action: .thumbnailGen),
        ]),
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "工具"
        setupUI()
    }

    private func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ToolCell")
        view.addSubview(tableView)
    }
}

// MARK: - Model
enum ToolAction {
    case appList, decryptedList, processPicker, dylibInject, machOTool
    case theosProject, compileProject, cleanProject, createDeb
    case quickDir, webView, thumbnailGen
}

struct ToolItem {
    let name: String
    let icon: String
    let action: ToolAction
}

// MARK: - UITableViewDataSource
extension ToolViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { tools.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tools[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToolCell", for: indexPath)
        let item = tools[indexPath.section].items[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.name
        config.image = UIImage(systemName: item.icon)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tools[section].section
    }
}

// MARK: - UITableViewDelegate
extension ToolViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = tools[indexPath.section].items[indexPath.row]
        handleAction(item.action)
    }

    private func handleAction(_ action: ToolAction) {
        switch action {
        case .appList:
            let vc = AppListViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .decryptedList:
            let vc = DecryptedListViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .processPicker:
            let vc = TGProcessPickerViewController()
            vc.completion = { process in
                print("Selected process: \(process)")
            }
            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true)
        case .dylibInject:
            showDylibInjectAlert()
        case .machOTool:
            let vc = FilePickerViewController(path: "/") { path in
                let props = FilePropertiesViewController(filePath: path)
                self.navigationController?.pushViewController(props, animated: true)
            }
            navigationController?.pushViewController(vc, animated: true)
        case .theosProject:
            // 跳转到文件的 TheosProject 目录
            if let fileVC = (tabBarController?.viewControllers?[0] as? UINavigationController)?.viewControllers.first as? MainRootViewController {
                fileVC.navigateTo("/var/mobile/TheosProject")
                tabBarController?.selectedIndex = 0
            }
        case .compileProject:
            NotificationCenter.default.post(name: .executeCommand, object: "make")
            tabBarController?.selectedIndex = 3
        case .cleanProject:
            NotificationCenter.default.post(name: .executeCommand, object: "make clean")
            tabBarController?.selectedIndex = 3
        case .createDeb:
            NotificationCenter.default.post(name: .executeCommand, object: "make package")
            tabBarController?.selectedIndex = 3
        case .quickDir:
            let vc = TGQuickDirPickerViewController()
            vc.didSelectBlock = { [weak self] path in
                if let fileVC = (self?.tabBarController?.viewControllers?[0] as? UINavigationController)?.viewControllers.first as? MainRootViewController {
                    fileVC.navigateTo(path)
                    self?.tabBarController?.selectedIndex = 0
                }
            }
            navigationController?.pushViewController(vc, animated: true)
        case .webView:
            let vc = TGWebViewController()
            vc.url = URL(string: "https://theos.dev")
            navigationController?.pushViewController(vc, animated: true)
        case .thumbnailGen:
            break
        }
    }

    private func showDylibInjectAlert() {
        let alert = UIAlertController(title: "Dylib 注入", message: "选择目标二进制和 dylib", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}
