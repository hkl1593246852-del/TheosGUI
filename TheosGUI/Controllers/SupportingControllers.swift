// MARK: - Supporting Controllers (DecryptedList, Share, TG*, Alert, etc.)

import UIKit
import SafariServices
import WebKit

// ======================================================================
// MARK: - DecryptedListViewController
// ======================================================================
class DecryptedListViewController: UIViewController {
    var rootPath: String = "/var/mobile/Documents/decrypted"
    var ipaFiles: [String] = []
    var appFiles: [String] = []
    var expandedSections: Set<Int> = [0, 1]
    private var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "已解密列表"
        view.backgroundColor = .systemBackground
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DecryptedCell")
        view.addSubview(tableView)
        loadFiles()
    }

    func loadFiles() {
        let fm = FileManager.default
        ipaFiles = (try? fm.contentsOfDirectory(atPath: rootPath))?.filter { $0.hasSuffix(".ipa") } ?? []
        appFiles = (try? fm.contentsOfDirectory(atPath: rootPath))?.filter { $0.hasSuffix(".app") } ?? []
        tableView.reloadData()
    }
}

extension DecryptedListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "IPA 文件" : "App 文件"
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? ipaFiles.count : appFiles.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DecryptedCell", for: indexPath)
        let name = indexPath.section == 0 ? ipaFiles[indexPath.row] : appFiles[indexPath.row]
        cell.textLabel?.text = name
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let name = indexPath.section == 0 ? ipaFiles[indexPath.row] : appFiles[indexPath.row]
        let path = (rootPath as NSString).appendingPathComponent(name)
        if let fileVC = (tabBarController?.viewControllers?[0] as? UINavigationController)?.viewControllers.first as? MainRootViewController {
            fileVC.navigateTo(path)
            tabBarController?.selectedIndex = 0
        }
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let name = indexPath.section == 0 ? ipaFiles[indexPath.row] : appFiles[indexPath.row]
            try? FileManager.default.removeItem(atPath: (rootPath as NSString).appendingPathComponent(name))
            loadFiles()
        }
    }
}

// ======================================================================
// MARK: - ShareViewController
// ======================================================================
class ShareViewController: UIViewController {
    var filePath: String = ""
    var apps: [AppInfo] = []
    var documentController: UIDocumentInteractionController?
    private var collectionView: UICollectionView!
    private var containerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "分享"
        view.backgroundColor = .systemBackground

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 80, height: 100)
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ShareAppCell.self, forCellWithReuseIdentifier: "ShareAppCell")
        view.addSubview(collectionView)

        loadApps()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭", style: .done, target: self, action: #selector(dismiss)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !filePath.isEmpty {
            documentController = UIDocumentInteractionController(url: URL(fileURLWithPath: filePath))
            documentController?.delegate = self
            documentController?.presentOptionsMenu(from: view.bounds, in: view, animated: true)
        }
    }

    func loadApps() { /* 加载可分享的应用列表 */ }
    @objc func dismiss() { self.dismiss(animated: true) }
}

extension ShareViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { apps.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ShareAppCell", for: indexPath)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 打开文件到选中的 app
    }
}

extension ShareViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController { self }
}

extension ShareViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { true }
}

// ======================================================================
// MARK: - TGProcessPickerViewController
// ======================================================================
class TGProcessPickerViewController: UIViewController {
    var processes: [ProcessInfo] = []
    var filteredProcesses: [ProcessInfo] = []
    var completion: ((ProcessInfo) -> Void)?
    var searchController: UISearchController!
    private var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择进程"
        view.backgroundColor = .systemBackground

        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProcessCell")
        view.addSubview(tableView)

        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain, target: self, action: #selector(cancel)
        )

        loadProcesses()
    }

    func loadProcesses() {
        // 在越狱设备上使用 sysctl 获取进程列表
        processes = []
        filteredProcesses = processes
        tableView.reloadData()
    }

    @objc func cancel() { dismiss(animated: true) }
}

struct ProcessInfo {
    let pid: Int32
    let name: String
    let path: String?
}

extension TGProcessPickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredProcesses.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProcessCell", for: indexPath)
        let proc = filteredProcesses[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = proc.name
        config.secondaryText = "PID: \(proc.pid)"
        cell.contentConfiguration = config
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        completion?(filteredProcesses[indexPath.row])
        dismiss(animated: true)
    }
}

extension TGProcessPickerViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.lowercased() ?? ""
        filteredProcesses = query.isEmpty ? processes : processes.filter { $0.name.lowercased().contains(query) }
        tableView.reloadData()
    }
}

// ======================================================================
// MARK: - TGQuickDirPickerViewController
// ======================================================================
class TGQuickDirPickerViewController: UIViewController {
    var items: [String] = ["/var/mobile", "/var/root", "/Applications", "/var/mobile/Documents", "/var/mobile/TheosProject"]
    var didSelectBlock: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "快速目录"
        view.backgroundColor = .systemGroupedBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        for item in items {
            let btn = UIButton(type: .system)
            btn.setTitle("📁 \(item)", for: .normal)
            btn.contentHorizontalAlignment = .leading
            btn.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(btn)
        }
    }

    func reloadData() {}
    @objc func itemTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal), let range = title.range(of: "📁 ") else { return }
        let path = String(title[range.upperBound...])
        didSelectBlock?(path)
        navigationController?.popViewController(animated: true)
    }
}

// ======================================================================
// MARK: - TGWebViewController
// ======================================================================
class TGWebViewController: UIViewController {
    var url: URL?
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "网页"
        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成", style: .done, target: self, action: #selector(done)
        )

        if let url = url {
            webView.load(URLRequest(url: url))
        }
    }

    @objc func done() { dismiss(animated: true) }
}
