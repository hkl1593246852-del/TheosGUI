// MARK: - AppListViewController.swift
// TheosGUI Clone — App 列表 / 解密

import UIKit

class AppListViewController: UIViewController {

    // MARK: - Properties
    var allApps: [AppInfo] = []
    var filteredApps: [AppInfo] = []
    var mode: AppListMode = .browse
    var allowMultipleSelection: Bool = false
    var selectedIdentifiers: Set<String> = []
    var completion: (([AppInfo]) -> Void)?
    var iconCache: [String: UIImage] = [:]
    var placeholderIcon: UIImage?
    var progressAlert: UIAlertController?

    private var tableView: UITableView!
    private var searchBar: UISearchBar!
    private var loadingIndicator: UIActivityIndicatorView!

    enum AppListMode {
        case browse
        case select
        case decrypt
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App 列表"
        view.backgroundColor = .systemBackground

        setupUI()
        loadApps()
    }

    private func setupUI() {
        searchBar = UISearchBar()
        searchBar.placeholder = "搜索应用..."
        searchBar.delegate = self
        navigationItem.titleView = searchBar

        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppCell")
        view.addSubview(tableView)

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        if allowMultipleSelection {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "完成", style: .done, target: self, action: #selector(doneSelecting)
            )
        }

        if mode == .select {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "取消", style: .plain, target: self, action: #selector(cancel)
            )
        }
    }

    // MARK: - Data
    func loadApps() {
        loadingIndicator.startAnimating()
        DispatchQueue.global().async {
            // 模拟加载已安装应用列表
            var apps: [AppInfo] = []
            // 在真实越狱设备上，这里会扫描 /Applications 和 /var/containers/Bundle/Application
            let appPaths = [
                "/Applications",
                "/var/containers/Bundle/Application"
            ]
            for basePath in appPaths {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                    for item in contents {
                        if item.hasSuffix(".app") {
                            let appPath = (basePath as NSString).appendingPathComponent(item)
                            let infoPlist = (appPath as NSString).appendingPathComponent("Info.plist")
                            if let plist = NSDictionary(contentsOfFile: infoPlist),
                               let bundleID = plist["CFBundleIdentifier"] as? String,
                               let name = plist["CFBundleDisplayName"] as? String
                                ?? plist["CFBundleName"] as? String {
                                apps.append(AppInfo(
                                    name: name,
                                    bundleID: bundleID,
                                    path: appPath,
                                    isDecrypted: isAppDecrypted(appPath)
                                ))
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.allApps = apps.sorted { $0.name < $1.name }
                self.filteredApps = self.allApps
                self.loadingIndicator.stopAnimating()
                self.tableView.reloadData()
            }
        }
    }

    func isAppDecrypted(_ path: String) -> Bool {
        let binaryName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let binaryPath = (path as NSString).appendingPathComponent(binaryName)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: binaryPath), options: [.mappedIfSafe]) else { return false }
        // 检查 LC_ENCRYPTION_INFO
        return data.count > 0 // 简化
    }

    func isUnityApp(_ path: String) -> Bool {
        let dataPath = (path as NSString).appendingPathComponent("Data")
        return FileManager.default.fileExists(atPath: dataPath)
    }

    func decryptApplicationProxy(_ app: AppInfo, options: [String: Any]? = nil) {
        let task = TDDecryptionTask(app: app)
        task.execute { [weak self] success in
            DispatchQueue.main.async {
                self?.loadApps()
            }
        }
    }

    // MARK: - Actions
    @objc func doneSelecting() {
        let selected = allApps.filter { selectedIdentifiers.contains($0.bundleID) }
        completion?(selected)
        dismiss(animated: true)
    }

    @objc func cancel() {
        dismiss(animated: true)
    }
}

// MARK: - Model
struct AppInfo {
    let name: String
    let bundleID: String
    let path: String
    let isDecrypted: Bool
}

// MARK: - UITableView
extension AppListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredApps.count }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 60 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath)
        let app = filteredApps[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = app.name
        config.secondaryText = app.bundleID
        config.image = iconCache[app.bundleID] ?? placeholderIcon ?? UIImage(systemName: "app.fill")
        cell.contentConfiguration = config

        cell.accessoryType = app.isDecrypted ? .checkmark : .none
        cell.accessoryView = app.isDecrypted
            ? UIImageView(image: UIImage(systemName: "lock.open.fill"))
            : UIImageView(image: UIImage(systemName: "lock.fill"))

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let app = filteredApps[indexPath.row]

        let alert = UIAlertController(title: app.name, message: app.bundleID, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "解密", style: .default) { [weak self] _ in
            self?.decryptApplicationProxy(app)
        })
        alert.addAction(UIAlertAction(title: "查看文件", style: .default) { [weak self] _ in
            if let fileVC = (self?.tabBarController?.viewControllers?[0] as? UINavigationController)?.viewControllers.first as? MainRootViewController {
                fileVC.navigateTo(app.path)
                self?.tabBarController?.selectedIndex = 0
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(alert, animated: true)
    }
}

extension AppListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredApps = allApps
        } else {
            filteredApps = allApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleID.localizedCaseInsensitiveContains(searchText)
            }
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension AppListViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
}
