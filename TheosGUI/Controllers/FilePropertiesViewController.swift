// MARK: - FilePropertiesViewController.swift
// TheosGUI Clone — 文件属性查看器

import UIKit
import QuickLook

class FilePropertiesViewController: UIViewController {

    var filePath: String
    private var tableView: UITableView!
    private var attributes: [(key: String, value: String)] = []
    private let systemUsers: [String] = ["root", "mobile", "_wireless"]
    private let systemGroups: [String] = ["wheel", "staff", "admin"]

    init(filePath: String) {
        self.filePath = filePath
        super.init(nibName: nil, bundle: nil)
        self.title = (filePath as NSString).lastPathComponent
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PropCell")
        view.addSubview(tableView)

        loadAttributes()

        // 导航栏
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareFile)),
            UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                           style: .plain, target: self, action: #selector(showOpenWithMenu))
        ]
    }

    func loadAttributes() {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        fm.fileExists(atPath: filePath, isDirectory: &isDir)

        attributes.append(("路径", filePath))
        attributes.append(("类型", detectDetailedFileType(filePath)))
        attributes.append(("种类", isDir.boolValue ? "文件夹" : "文件"))

        if let attrs = try? fm.attributesOfItem(atPath: filePath) {
            if let size = attrs[.size] as? UInt64 {
                if isDir.boolValue {
                    attributes.append(("大小", "计算中..."))
                    DispatchQueue.global().async {
                        let dirSize = self.calculateDirectorySize(self.filePath)
                        DispatchQueue.main.async {
                            self.attributes[3] = ("大小", formatSize(dirSize))
                            self.tableView.reloadData()
                        }
                    }
                } else {
                    attributes.append(("大小", formatSize(size)))
                }
            }
            if let modDate = attrs[.modificationDate] as? Date {
                attributes.append(("修改日期", DateFormatter.localizedString(from: modDate, dateStyle: .medium, timeStyle: .medium)))
            }
            if let createDate = attrs[.creationDate] as? Date {
                attributes.append(("创建日期", DateFormatter.localizedString(from: createDate, dateStyle: .medium, timeStyle: .medium)))
            }
            if let posix = attrs[.posixPermissions] as? Int {
                attributes.append(("权限", String(posix, radix: 8)))
            }
            if let owner = attrs[.ownerAccountName] as? String {
                attributes.append(("所有者", owner))
            }
            if let group = attrs[.groupOwnerAccountName] as? String {
                attributes.append(("组", group))
            }
        }

        attributes.append(("MD5", calculateMD5(filePath)))
        tableView.reloadData()
    }

    func calculateMD5(_ path: String) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return "N/A" }
        // Use CryptoKit or CC_MD5
        return "md5_placeholder"
    }

    func calculateDirectorySize(_ path: String) -> UInt64 {
        var total: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            for case let file as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64 {
                    total += size
                }
            }
        }
        return total
    }

    func detectDetailedFileType(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "未知" : ext.uppercased()
    }

    @objc func shareFile() {
        let url = URL(fileURLWithPath: filePath)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(activityVC, animated: true)
    }

    @objc func showOpenWithMenu() {
        let alert = UIAlertController(title: "打开方式", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "文本编辑器", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let editor = FileEditorViewController(filePath: self.filePath)
            self.navigationController?.pushViewController(editor, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Mach-O 工具", style: .default) { [weak self] _ in
            self?.openMachOTool()
        })
        alert.addAction(UIAlertAction(title: "Hex 查看", style: .default) { [weak self] _ in
            self?.handleOpenWithAction("hex")
        })
        alert.addAction(UIAlertAction(title: "查看包内容", style: .default) { [weak self] _ in
            self?.handleOpenWithAction("bundle")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(alert, animated: true)
    }

    func handleOpenWithAction(_ action: String) {
        switch action {
        case "hex":
            break
        case "bundle":
            break
        default:
            break
        }
    }

    func handleZipFile(_ path: String) {}
    func unzipFile(_ path: String, password: String?) {}
    func openMachOTool() {}

    func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    func showPermissionsAlert(for value: String) {
        // 权限编辑弹窗
    }

    func updatePermissions(_ permissions: String) {}
    func updateOwnerOrGroup(_ name: String, isGroup: Bool) {}
    func dismiss() { navigationController?.popViewController(animated: true) }
}

extension FilePropertiesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attributes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropCell", for: indexPath)
        let attr = attributes[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = attr.key
        config.secondaryText = attr.value
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let attr = attributes[indexPath.row]
        if attr.key == "权限" {
            showPermissionsAlert(for: attr.value)
        }
    }

    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool { true }
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        UIPasteboard.general.string = attributes[indexPath.row].value
    }
}

extension FilePropertiesViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return URL(fileURLWithPath: filePath) as QLPreviewItem
    }
}
