// MARK: - MainRootViewController.swift
// TheosGUI Clone — 文件浏览器 (150 methods in original)
// 功能: 浏览/搜索/压缩/解压/Git/粘贴/分享/编辑/属性

import UIKit
import UniformTypeIdentifiers
import QuickLook

class MainRootViewController: UIViewController {

    // MARK: - Properties (匹配原始 App 的 ivar)
    var currentPath: String = "/"
    var files: [FileItem] = []
    var originalFiles: [FileItem] = []         // 搜索前备份
    var previewPath: String?
    var isSearching: Bool = false
    var isSearchOptionsVisible: Bool = false
    var activeTextField: UITextField?

    // 右键菜单
    var menuOverlay: UIView?
    var actionsVC: UIViewController?

    // 上传/压缩进度
    var compressProgressAlert: UIAlertController?
    var uploadProgressAlert: UIAlertController?
    var uploadResponseData: Data?
    var uploadZipPath: String?

    // 搜索组件
    var searchBar: UISearchBar!
    var searchContainer: UIView!
    var searchOptionsView: UIView!
    var toggleOptionsButton: UIButton!
    var contentSearchSwitch: UISwitch!
    var recursiveSearchSwitch: UISwitch!
    var regexSearchSwitch: UISwitch!

    // 压缩组件
    var compressionPicker: UIPickerView?
    var compressionFormats: [String] = ["zip", "tar", "tar.gz", "tar.bz2", "tar.xz", "7z"]
    var compressionLevels: [String] = ["最快", "标准", "最佳"]
    var formatField: UITextField?
    var levelField: UITextField?

    // 多选
    var originalRightBarButtonItems: [UIBarButtonItem]?
    var originalTitleView: UIView?
    var pasteButton: UIBarButtonItem?

    // 子 VC
    var consoleVC: ConsoleViewController?

    // MARK: - TableView
    private var tableView: UITableView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = currentPath
        setupUI()
        setupSearchUI()
        loadFiles()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWallpaper()
        navigationController?.setToolbarHidden(false, animated: false)
        updateToolbarState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissMenu()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // TableView
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FileCell")
        tableView.allowsMultipleSelectionDuringEditing = true
        view.addSubview(tableView)

        // 长按手势 → 多选
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPress)

        // 标题长按 → 路径跳转
        let titleTap = UILongPressGestureRecognizer(target: self, action: #selector(handleTitleLongPress(_:)))
        navigationController?.navigationBar.addGestureRecognizer(titleTap)

        // 导航栏按钮
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"),
                           style: .plain, target: self, action: #selector(showSearchBar)),
            UIBarButtonItem(image: UIImage(systemName: "plus"),
                           style: .plain, target: self, action: #selector(showAddMenu)),
            UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                           style: .plain, target: self, action: #selector(showActions))
        ]

        // 键盘手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - File Loading
    func loadFiles() {
        let fm = FileManager.default
        var items: [FileItem] = []

        do {
            let contents = try fm.contentsOfDirectory(atPath: currentPath)
            for name in contents {
                let fullPath = (currentPath as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                let attrs = try fm.attributesOfItem(atPath: fullPath)
                let size = (attrs[.size] as? UInt64) ?? 0
                let modDate = (attrs[.modificationDate] as? Date) ?? Date()
                let isHidden = name.hasPrefix(".")
                let type = detectDetailedFileType(fullPath)

                items.append(FileItem(
                    name: name,
                    path: fullPath,
                    isDirectory: isDir.boolValue,
                    size: size,
                    modificationDate: modDate,
                    isHidden: isHidden,
                    fileType: type
                ))
            }
        } catch {
            showAlert("错误", message: error.localizedDescription)
        }

        // 排序: 文件夹优先 → 按名称排序
        items.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        files = items
        originalFiles = items
        tableView.reloadData()
        title = currentPath
    }

    // MARK: - File Type Detection
    func detectDetailedFileType(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        let types: [String: String] = [
            "swift": "Swift Source", "m": "ObjC Source", "mm": "ObjC++ Source",
            "c": "C Source", "cpp": "C++ Source", "h": "Header",
            "plist": "Property List", "json": "JSON", "xml": "XML",
            "deb": "Debian Package", "ipa": "iOS App", "dylib": "Dynamic Library",
            "framework": "Framework", "png": "PNG Image", "jpg": "JPEG Image",
            "pdf": "PDF", "zip": "ZIP Archive", "tar": "TAR Archive",
            "gz": "GZip", "bz2": "BZip2", "xz": "XZ Archive",
            "sh": "Shell Script", "py": "Python Script", "rb": "Ruby Script",
            "lua": "Lua Script", "js": "JavaScript", "html": "HTML",
            "css": "CSS", "md": "Markdown", "txt": "Plain Text",
            "log": "Log File", "sqlite": "SQLite DB", "db": "Database"
        ]
        return types[ext] ?? ext.uppercased()
    }

    // MARK: - Navigation
    func navigateTo(_ path: String) {
        currentPath = path
        loadFiles()
        tableView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Actions
    @objc func showActions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "新建文件", style: .default) { [weak self] _ in self?.createNewFile() })
        alert.addAction(UIAlertAction(title: "新建文件夹", style: .default) { [weak self] _ in self?.createNewFolder() })
        alert.addAction(UIAlertAction(title: "导入文件", style: .default) { [weak self] _ in self?.importFile() })
        alert.addAction(UIAlertAction(title: "导入文件夹", style: .default) { [weak self] _ in self?.importFolder() })
        alert.addAction(UIAlertAction(title: "Git 克隆", style: .default) { [weak self] _ in self?.cloneGitRepository() })
        alert.addAction(UIAlertAction(title: "编译项目", style: .default) { [weak self] _ in self?.compileLocalProject() })
        alert.addAction(UIAlertAction(title: "打包项目", style: .default) { [weak self] _ in self?.packageLocalProject() })
        alert.addAction(UIAlertAction(title: "复制路径", style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.currentPath
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(alert, animated: true)
    }

    @objc func showAddMenu() {
        let alert = UIAlertController(title: "新建", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "新建文件", style: .default) { [weak self] _ in self?.createNewFile() })
        alert.addAction(UIAlertAction(title: "新建文件夹", style: .default) { [weak self] _ in self?.createNewFolder() })
        alert.addAction(UIAlertAction(title: "从相册导入", style: .default) { [weak self] _ in self?.importFile() })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?[1]
        present(alert, animated: true)
    }

    // MARK: - File Operations
    func createNewFile() {
        showRenameAlertForPath(currentPath, currentName: "") { [weak self] newName in
            guard let self = self else { return }
            let path = (self.currentPath as NSString).appendingPathComponent(newName)
            FileManager.default.createFile(atPath: path, contents: Data())
            self.loadFiles()
        }
    }

    func createNewFolder() {
        showRenameAlertForPath(currentPath, currentName: "") { [weak self] newName in
            guard let self = self else { return }
            let path = (self.currentPath as NSString).appendingPathComponent(newName)
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
            self.loadFiles()
        }
    }

    func importFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .archive, .text, .sourceCode])
        picker.delegate = self
        present(picker, animated: true)
    }

    func importFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        present(picker, animated: true)
    }

    func deleteFileAtPath(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
        loadFiles()
    }

    func deletePaths(_ paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
        loadFiles()
    }

    func shareFileAtPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(activityVC, animated: true)
    }

    // MARK: - Compression
    func compressPaths(_ paths: [String]) {
        let alert = UIAlertController(title: "压缩", message: "选择格式", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "文件名"; self.formatField = tf }
        alert.addAction(UIAlertAction(title: "ZIP", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = self.formatField?.text ?? "archive"
            self.startCompression(paths: paths, name: name, format: "zip")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func startCompression(paths: [String], name: String, format: String) {
        // 使用 TGArchiveManager 进行压缩
        TGArchiveManager.compressFiles(
            paths,
            toPath: (currentPath as NSString).appendingPathComponent("\(name).\(format)"),
            format: format
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadFiles()
                switch result {
                case .success(let path):
                    self?.showAlert("完成", message: "已压缩: \(path)")
                case .failure(let error):
                    self?.showAlert("错误", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Git
    func cloneGitRepository() {
        let alert = UIAlertController(title: "Git 克隆", message: "输入仓库 URL", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "https://github.com/..." }
        alert.addAction(UIAlertAction(title: "克隆", style: .default) { [weak self] _ in
            guard let url = alert.textFields?.first?.text else { return }
            self?.manualGitClone(url: url)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func manualGitClone(url: String) {
        showAlert("克隆中...", message: "请使用控制台执行 git clone \(url)")
    }

    func compileLocalProject() {
        guard let makefilePath = findFile("Makefile", in: currentPath) else {
            showAlert("提示", message: "当前目录未找到 Makefile")
            return
        }
        runCommand("make -C \(currentPath)")
    }

    func packageLocalProject() {
        runCommand("make -C \(currentPath) package")
    }

    func cleanLocalProject() {
        runCommand("make -C \(currentPath) clean")
    }

    private func findFile(_ name: String, in path: String) -> String? {
        let fullPath = (path as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
    }

    func runCommand(_ command: String) {
        // 打开控制台执行命令
        if let console = consoleVC {
            console.executeCommand(command)
        } else {
            NotificationCenter.default.post(name: .executeCommand, object: command)
        }
        tabBarController?.selectedIndex = 3
    }

    // MARK: - Search
    func setupSearchUI() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "搜索文件..."
    }

    @objc func showSearchBar() {
        isSearching = true
        originalFiles = files
        navigationItem.titleView = searchBar
        searchBar.becomeFirstResponder()
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(hideSearchBar))
        ]
    }

    @objc func hideSearchBar() {
        isSearching = false
        navigationItem.titleView = originalTitleView
        navigationItem.rightBarButtonItems = originalRightBarButtonItems
        files = originalFiles
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }

    func toggleSearchOptions() {
        isSearchOptionsVisible.toggle()
        UIView.animate(withDuration: 0.3) {
            self.searchOptionsView?.isHidden = !self.isSearchOptionsVisible
        }
    }

    // MARK: - Multi-Selection
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        enterSelectionMode()
    }

    func enterSelectionMode() {
        tableView.setEditing(true, animated: true)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "压缩", style: .plain, target: self, action: #selector(actionMultiCompress)),
            UIBarButtonItem(title: "复制", style: .plain, target: self, action: #selector(actionMultiCopy)),
            UIBarButtonItem(title: "移动", style: .plain, target: self, action: #selector(actionMultiMove)),
            UIBarButtonItem(title: "删除", style: .plain, target: self, action: #selector(actionMultiDelete)),
            UIBarButtonItem(title: "取消", style: .done, target: self, action: #selector(exitSelectionMode))
        ]
    }

    @objc func exitSelectionMode() {
        tableView.setEditing(false, animated: true)
        setupUI() // 恢复导航栏按钮
    }

    @objc func actionMultiCompress() {
        let selected = getSelectedPaths()
        compressPaths(selected)
        exitSelectionMode()
    }

    @objc func actionMultiCopy() {
        let selected = getSelectedPaths()
        UIPasteboard.general.strings = selected
        exitSelectionMode()
    }

    @objc func actionMultiMove() {
        // 剪切到剪贴板
        let selected = getSelectedPaths()
        addToClipboard(selected, isCut: true)
        exitSelectionMode()
    }

    @objc func actionMultiDelete() {
        let selected = getSelectedPaths()
        let alert = UIAlertController(title: "删除 \(selected.count) 个项目?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deletePaths(selected)
            self?.exitSelectionMode()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func getSelectedPaths() -> [String] {
        guard let indexPaths = tableView.indexPathsForSelectedRows else { return [] }
        return indexPaths.map { files[$0.row].path }
    }

    func addToClipboard(_ paths: [String], isCut: Bool) {
        UIPasteboard.general.strings = paths
        if isCut {
            // 标记为剪切操作
            UserDefaults.standard.set(true, forKey: "clipboard_is_cut")
        }
    }

    func pasteFiles() {
        guard let paths = UIPasteboard.general.strings else { return }
        let isCut = UserDefaults.standard.bool(forKey: "clipboard_is_cut")
        for path in paths {
            let destName = (path as NSString).lastPathComponent
            let destPath = (currentPath as NSString).appendingPathComponent(destName)
            if isCut {
                try? FileManager.default.moveItem(atPath: path, toPath: destPath)
            } else {
                try? FileManager.default.copyItem(atPath: path, toPath: destPath)
            }
        }
        UserDefaults.standard.removeObject(forKey: "clipboard_is_cut")
        loadFiles()
    }

    // MARK: - Title Long Press
    @objc func handleTitleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let alert = UIAlertController(title: "跳转路径", message: currentPath, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = self.currentPath }
        alert.addAction(UIAlertAction(title: "前往", style: .default) { [weak self] _ in
            guard let path = alert.textFields?.first?.text else { return }
            self?.navigateTo(path)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Rename
    func showRenameAlertForPath(_ basePath: String, currentName: String, completion: ((String) -> Void)? = nil) {
        let title = currentName.isEmpty ? "新建" : "重命名"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = currentName; self.activeTextField = tf }
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            if currentName.isEmpty {
                completion?(newName)
            } else {
                let oldPath = (basePath as NSString).appendingPathComponent(currentName)
                let newPath = (basePath as NSString).appendingPathComponent(newName)
                try? FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
                self.loadFiles()
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func showFileOptionsForPath(_ path: String, fileName: String) {
        let alert = UIAlertController(title: fileName, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "打开", style: .default) { [weak self] _ in
            self?.openFile(path)
        })
        alert.addAction(UIAlertAction(title: "重命名", style: .default) { [weak self] _ in
            self?.showRenameAlertForPath((path as NSString).deletingLastPathComponent,
                                          currentName: (path as NSString).lastPathComponent)
        })
        alert.addAction(UIAlertAction(title: "属性", style: .default) { [weak self] _ in
            self?.showPropertiesForPath(path)
        })
        alert.addAction(UIAlertAction(title: "分享", style: .default) { [weak self] _ in
            self?.shareFileAtPath(path)
        })
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteFileAtPath(path)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = tableView
        present(alert, animated: true)
    }

    func showPropertiesForPath(_ path: String) {
        let vc = FilePropertiesViewController(filePath: path)
        navigationController?.pushViewController(vc, animated: true)
    }

    func openFile(_ path: String) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        if isDir.boolValue {
            navigateTo(path)
        } else {
            let ext = (path as NSString).pathExtension.lowercased()
            if ["zip", "tar", "gz", "bz2", "xz", "7z"].contains(ext) {
                handleZipFile(path)
            } else if isArchiveFile(path) {
                // IPA, deb 等
                print("Archive file: \(path)")
            } else {
                // 文本/plist 编辑器
                let editor = FileEditorViewController(filePath: path)
                navigationController?.pushViewController(editor, animated: true)
            }
        }
    }

    func isArchiveFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["deb", "ipa", "framework", "bundle"].contains(ext)
    }

    func handleZipFile(_ path: String) {
        let alert = UIAlertController(title: "解压", message: (path as NSString).lastPathComponent, preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "密码 (可选)"; tf.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "解压", style: .default) { [weak self] _ in
            let password = alert.textFields?.first?.text
            self?.unzipFile(path, password: password)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func unzipFile(_ path: String, password: String?) {
        TGArchiveManager.decompressFile(
            path,
            toPath: (path as NSString).deletingLastPathComponent,
            password: password
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadFiles()
            }
        }
    }

    // MARK: - Wallpaper
    func updateWallpaper() {
        view.backgroundColor = .systemBackground
    }

    func updateWallpaperBrightness() {
        // 原始 App 根据壁纸亮度调整 UI 颜色
    }

    // MARK: - Helpers
    func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func dismissMenu() {
        menuOverlay?.removeFromSuperview()
        menuOverlay = nil
    }

    func updateToolbarState() {
        // 更新工具栏按钮状态
    }

    func checkCurrentPathPermission() -> Bool {
        return FileManager.default.isWritableFile(atPath: currentPath)
    }

    func performSearch(in path: String, query: String, recursive: Bool, content: Bool, regex: Bool) -> [String] {
        // 文件搜索实现
        return []
    }

    func createFatBinary(name: String, fromBinaries binaries: [String]) {
        var args = ["-create", "-output", name]
        args.append(contentsOf: binaries)
        runCommand("lipo \(args.joined(separator: " "))")
    }
}

// MARK: - UITableViewDataSource
extension MainRootViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath)
        let item = files[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.name
        config.secondaryText = "\(item.fileType) · \(formatSize(item.size))"
        config.image = item.isDirectory
            ? UIImage(systemName: "folder.fill")
            : UIImage(systemName: "doc")
        cell.contentConfiguration = config

        if item.isHidden { cell.alpha = 0.5 }
        cell.accessoryType = item.isDirectory ? .disclosureIndicator : .detailButton

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteFileAtPath(files[indexPath.row].path)
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.deleteFileAtPath(self?.files[indexPath.row].path ?? "")
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let item = files[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let rename = UIAction(title: "重命名") { _ in
                self?.showRenameAlertForPath((item.path as NSString).deletingLastPathComponent,
                                              currentName: item.name)
            }
            let delete = UIAction(title: "删除", attributes: .destructive) { _ in
                self?.deleteFileAtPath(item.path)
            }
            return UIMenu(children: [rename, delete])
        }
    }
}

// MARK: - UITableViewDelegate
extension MainRootViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing { return }
        tableView.deselectRow(at: indexPath, animated: true)
        openFile(files[indexPath.row].path)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        // 多选取消
    }

    func tableView(_ tableView: UITableView,
                   accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let item = files[indexPath.row]
        showFileOptionsForPath(item.path, fileName: item.name)
    }
}

// MARK: - UISearchBarDelegate
extension MainRootViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            files = originalFiles
        } else {
            files = originalFiles.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        hideSearchBar()
    }
}

// MARK: - UIDocumentPickerDelegate
extension MainRootViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let destPath = (currentPath as NSString).appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
        }
        loadFiles()
    }
}

// MARK: - UIPickerViewDataSource/Delegate
extension MainRootViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return compressionFormats.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return compressionFormats[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        formatField?.text = compressionFormats[row]
    }
}

// MARK: - UIPreviewController
extension MainRootViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewPath != nil ? 1 : 0
    }
    func previewController(_ controller: QLPreviewController,
                           previewItemAt index: Int) -> QLPreviewItem {
        return URL(fileURLWithPath: previewPath ?? "/") as QLPreviewItem
    }
}

// MARK: - UITextFieldDelegate
extension MainRootViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool { true }
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
    }
    func textFieldShouldClear(_ textField: UITextField) -> Bool { true }
}

// MARK: - Helpers
