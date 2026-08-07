// MARK: - SettingsViewController.swift
// TheosGUI Clone — 设置 (39 methods in original)
// 功能: Theos 安装 / 缩放 / 主题 / 语言 / 编辑器配置

import UIKit
import SafariServices

class SettingsViewController: UIViewController {

    // MARK: - Properties
    private var tableView: UITableView!

    private let sections: [(header: String, rows: [SettingRow])] = [
        ("开发环境", [
            SettingRow(title: "安装 Theos", subtitle: "下载 Theos 及 SDKs", action: .installTheos),
            SettingRow(title: "Theos 源 URL", subtitle: TGPreferences.shared.string(forKey: "theos_url") ?? "https://github.com/theos/theos", action: .setTheosUrl),
            SettingRow(title: "默认项目路径", subtitle: TGPreferences.shared.string(forKey: "project_path") ?? "/var/mobile", action: .setProjectPath),
            SettingRow(title: "在控制台编译", subtitle: "使用控制台显示编译输出", action: .toggleConsoleCompile),
        ]),
        ("编辑器", [
            SettingRow(title: "缩放比例", subtitle: "±", action: .zoomScale),
            SettingRow(title: "编辑器配置文件", subtitle: "使用 vim/emacs 配置文件", action: .editorConfig),
            SettingRow(title: "编辑时缩放", subtitle: nil, action: .editorZoomToggle),
            SettingRow(title: "快速文件切换", subtitle: nil, action: .quickFileToggle),
        ]),
        ("外观", [
            SettingRow(title: "主题", subtitle: TGPreferences.shared.string(forKey: "theme") ?? "Dark", action: .setTheme),
            SettingRow(title: "语言", subtitle: TGPreferences.shared.string(forKey: "lang") ?? "中文", action: .setLanguage),
        ]),
        ("项目管理", [
            SettingRow(title: "项目配置", subtitle: nil, action: .projectConfig),
        ]),
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWallpaper()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
        view.addSubview(tableView)
    }

    // MARK: - Actions
    private func handleAction(_ action: SettingAction) {
        switch action {
        case .installTheos:
            downloadTheosAndSDKs()
        case .setTheosUrl:
            showEditAlert(title: "Theos URL", key: "theos_url", placeholder: "https://github.com/theos/theos")
        case .setProjectPath:
            pickDefaultProjectFolder()
        case .toggleConsoleCompile:
            let current = TGPreferences.shared.bool(forKey: "console_compile")
            TGPreferences.shared.setBool(!current, forKey: "console_compile")
            tableView.reloadData()
        case .zoomScale:
            showZoomAlert()
        case .editorConfig:
            editorConfigSwitchChanged()
        case .editorZoomToggle:
            let current = TGPreferences.shared.bool(forKey: "editor_zoom")
            TGPreferences.shared.setBool(!current, forKey: "editor_zoom")
            tableView.reloadData()
        case .quickFileToggle:
            quickFileSwitchChanged()
        case .setTheme:
            showThemePicker()
        case .setLanguage:
            showLanguagePicker()
        case .projectConfig:
            projectConfigSwitchChanged()
        }
    }

    // MARK: - Theos
    func downloadTheosAndSDKs() {
        let alert = UIAlertController(title: "安装 Theos", message: "将从 GitHub 下载 Theos 及 SDKs", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "从 GitHub 下载", style: .default) { [weak self] _ in
            self?.downloadTheos(from: "https://github.com/theos/theos")
        })
        alert.addAction(UIAlertAction(title: "从本地导入", style: .default) { [weak self] _ in
            self?.importFromLocal()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func downloadTheos(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        showAlert("下载中", message: "正在下载 Theos...")
        // 实际下载逻辑
    }

    func importFromLocal() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.archive])
        picker.delegate = self
        present(picker, animated: true)
    }

    func cloneRepo(_ repo: String, toPath: String, alert: UIAlertController?) {
        let command = "git clone \(repo) \(toPath)"
        NotificationCenter.default.post(name: .executeCommand, object: command)
    }

    func startCloneTheos(url: String) {
        cloneRepo(url, toPath: "/var/mobile/theos", alert: nil)
    }

    func confirmPath(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    func pickDefaultProjectFolder() {
        let picker = FilePickerViewController(path: "/var/mobile") { [weak self] path in
            TGPreferences.shared.setObject(path, forKey: "project_path")
            self?.tableView.reloadData()
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    // MARK: - Zoom
    func increaseZoomScale() {
        var scale = TGPreferences.shared.integer(forKey: "zoom_scale")
        scale = min(scale + 1, 10)
        TGPreferences.shared.setInteger(scale, forKey: "zoom_scale")
    }

    func decreaseZoomScale() {
        var scale = TGPreferences.shared.integer(forKey: "zoom_scale")
        scale = max(scale - 1, 1)
        TGPreferences.shared.setInteger(scale, forKey: "zoom_scale")
    }

    func showZoomAlert() {
        let current = TGPreferences.shared.integer(forKey: "zoom_scale")
        let alert = UIAlertController(title: "缩放比例", message: "当前: \(current)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "+", style: .default) { [weak self] _ in self?.increaseZoomScale() })
        alert.addAction(UIAlertAction(title: "-", style: .default) { [weak self] _ in self?.decreaseZoomScale() })
        alert.addAction(UIAlertAction(title: "确定", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Config Toggles
    func editorConfigSwitchChanged() {
        let current = TGPreferences.shared.bool(forKey: "editor_config")
        TGPreferences.shared.setBool(!current, forKey: "editor_config")
    }

    func editorZoomSwitchChanged() {
        let current = TGPreferences.shared.bool(forKey: "editor_zoom")
        TGPreferences.shared.setBool(!current, forKey: "editor_zoom")
    }

    func projectConfigSwitchChanged() {
        let current = TGPreferences.shared.bool(forKey: "project_config")
        TGPreferences.shared.setBool(!current, forKey: "project_config")
    }

    func quickFileSwitchChanged() {
        let current = TGPreferences.shared.bool(forKey: "quick_file_switch")
        TGPreferences.shared.setBool(!current, forKey: "quick_file_switch")
    }

    // MARK: - Theme & Language
    func setTheme(_ theme: String) {
        TGPreferences.shared.setObject(theme, forKey: "theme")
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
    }

    func setLanguage(_ lang: String) {
        TGPreferences.shared.setObject(lang, forKey: "lang")
    }

    func showThemePicker() {
        let alert = UIAlertController(title: "选择主题", message: nil, preferredStyle: .actionSheet)
        for theme in ["Dark", "Light", "System", "Midnight", "Ocean"] {
            alert.addAction(UIAlertAction(title: theme, style: .default) { [weak self] _ in
                self?.setTheme(theme)
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = tableView
        present(alert, animated: true)
    }

    func showLanguagePicker() {
        let alert = UIAlertController(title: "选择语言", message: nil, preferredStyle: .actionSheet)
        for lang in ["中文", "English", "日本語"] {
            alert.addAction(UIAlertAction(title: lang, style: .default) { [weak self] _ in
                self?.setLanguage(lang)
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = tableView
        present(alert, animated: true)
    }

    // MARK: - Helpers
    func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    func showEditAlert(title: String, key: String, placeholder: String, isPathPicker: Bool = false) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = placeholder
            tf.text = TGPreferences.shared.string(forKey: key)
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            guard let text = alert.textFields?.first?.text else { return }
            TGPreferences.shared.setObject(text, forKey: key)
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func removeOverlay() {}

    // MARK: - Observer
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        // KVO 观察
    }

    func handleDeviceActivated(_ notification: Notification) {}

    func pingURL(_ url: String, action: @escaping (Bool) -> Void) {
        // URL 连通性检测
    }

    func runCommandInConsole(_ command: String, arguments: [String]) {
        NotificationCenter.default.post(name: .executeCommand, object: command)
    }

    func switcherResetIntervalDisplayName() -> String { "5 分钟" }
    func switcherResetOptions() -> [String] { ["1分钟", "5分钟", "15分钟", "30分钟", "1小时"] }
    func titleForResetInterval(_ interval: Int) -> String { "\(interval) 分钟" }

    func updateWallpaper() {
        view.backgroundColor = .systemGroupedBackground
    }

    func updateWallpaperBrightness() {}
}

// MARK: - Models
enum SettingAction {
    case installTheos, setTheosUrl, setProjectPath, toggleConsoleCompile
    case zoomScale, editorConfig, editorZoomToggle, quickFileToggle
    case setTheme, setLanguage
    case projectConfig
}

struct SettingRow {
    let title: String
    let subtitle: String?
    let action: SettingAction
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].header }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = row.title
        config.secondaryText = row.subtitle
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        // 开关类型
        if row.action == .toggleConsoleCompile {
            let sw = UISwitch()
            sw.isOn = TGPreferences.shared.bool(forKey: "console_compile")
            sw.addTarget(self, action: #selector(switcherChanged(_:)), for: .valueChanged)
            cell.accessoryView = sw
            cell.accessoryType = .none
        }

        return cell
    }

    @objc private func switcherChanged(_ sender: UISwitch) {
        TGPreferences.shared.setBool(sender.isOn, forKey: "console_compile")
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleAction(sections[indexPath.section].rows[indexPath.row].action)
    }
}

// MARK: - UIDocumentPickerDelegate
extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // 导入 Theos
        startCloneTheos(url: url.path)
    }
}
