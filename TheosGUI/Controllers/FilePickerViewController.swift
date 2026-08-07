// MARK: - FilePickerViewController.swift
// TheosGUI Clone — 文件/目录选择器

import UIKit

class FilePickerViewController: UIViewController {

    // MARK: - Properties
    var currentPath: String
    var completion: (String) -> Void
    var isDir: Bool = true
    var contents: [FileItem] = []
    var titleView: UIView?

    // MARK: - Init
    init(path: String, completion: @escaping (String) -> Void) {
        self.currentPath = path
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.title = (path as NSString).lastPathComponent
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        buildNavigationStack()
        loadContents()

        // 导航栏
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "选择此目录", style: .done,
            target: self, action: #selector(selectCurrentDirectory)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消", style: .plain,
            target: self, action: #selector(cancel)
        )

        // 标题点击 → 路径导航
        let titleTap = UITapGestureRecognizer(target: self, action: #selector(titleTapped))
        navigationItem.titleView?.addGestureRecognizer(titleTap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(titleLongPressed(_:)))
        navigationItem.titleView?.addGestureRecognizer(longPress)
    }

    func buildNavigationStack() {
        // 构建路径面包屑导航
    }

    func loadContents() {
        let fm = FileManager.default
        contents = []
        do {
            let items = try fm.contentsOfDirectory(atPath: currentPath)
            for name in items.sorted() {
                let fullPath = (currentPath as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                contents.append(FileItem(
                    name: name, path: fullPath, isDirectory: isDir.boolValue,
                    size: 0, modificationDate: Date(), isHidden: false, fileType: ""
                ))
            }
        } catch {}
    }

    func navigateToPath(_ path: String) {
        currentPath = path
        title = (path as NSString).lastPathComponent
        loadContents()
    }

    @objc func selectCurrentDirectory() {
        completion(currentPath)
        dismiss(animated: true)
    }

    @objc func cancel() {
        dismiss(animated: true)
    }

    @objc func titleTapped() {
        showPathMenu()
    }

    @objc func titleLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showPathMenu()
    }

    func showPathMenu() {
        // 显示路径导航菜单
    }

    func pathTextFieldDidChange(_ textField: UITextField) {
        // 手动输入路径
    }

    func updatePicker(forPath path: String) {}
}

// MARK: - UITableViewDataSource/Delegate
extension FilePickerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { contents.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let item = contents[indexPath.row]
        cell.textLabel?.text = item.name
        cell.imageView?.image = UIImage(systemName: item.isDirectory ? "folder.fill" : "doc")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = contents[indexPath.row]
        if item.isDirectory {
            navigateToPath(item.path)
        } else {
            completion(item.path)
            dismiss(animated: true)
        }
    }
}
