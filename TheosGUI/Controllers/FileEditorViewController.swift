// MARK: - FileEditorViewController.swift
// TheosGUI Clone — 文件编辑器 (118 methods in original)
// 功能: 文本编辑 / Plist 编辑 / 语法高亮 / 代码补全 / 文件切换 / MD5 检测

import UIKit
import CryptoKit

class FileEditorViewController: UIViewController {

    // MARK: - Properties
    var filePath: String
    var isRoot: Bool = true
    var isPlistMode: Bool = false
    var forceTextMode: Bool = false
    var isKeyboardVisible: Bool = false

    // Content
    private var textView: UITextView!
    private var tableView: UITableView?      // for plist mode
    private var lineNumberView: UIView!
    var originalMD5: String = ""
    var initialFontSize: CGFloat = 13

    // Plist
    var plistRoot: Any?
    var currentPlistObject: Any?
    var sortedKeys: [String] = []

    // Search
    var searchBar: UISearchBar?
    var lastSearchRange: NSRange?

    // Suggestion
    var allKeywords: [String] = []
    var suggestionList: [String] = []
    var suggestionTableView: UITableView!

    // File Switcher (多文件标签切换)
    var fileSwitcherBar: UIScrollView!
    var fileSwitcherBarHeight: NSLayoutConstraint!
    var siblingFiles: [String] = []
    var hiddenSwitcherFiles: [String] = []
    var hiddenSwitcherMap: [String: Date] = [:]
    var switcherResetTimer: Timer?

    // Save button
    var saveButton: UIBarButtonItem!

    // MARK: - Init
    init(filePath: String) {
        self.filePath = filePath
        super.init(nibName: nil, bundle: nil)
        self.title = (filePath as NSString).lastPathComponent
        self.originalMD5 = calculateMD5(filePath)
    }

    init(plistObject: Any, root: Bool = true, path: String, title: String) {
        self.filePath = path
        self.isRoot = root
        self.isPlistMode = true
        self.plistRoot = plistObject
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        initKeywords()

        if isPlistMode && !forceTextMode {
            setupPlistMode()
        } else {
            loadFileContent()
            setupTextMode(content: textView?.text ?? "")
        }

        setupFileSwitcherBarIfNeeded()
        setupSuggestionView()

        // 保存按钮
        saveButton = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveFile))
        navigationItem.rightBarButtonItems = [
            saveButton,
            UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"),
                           style: .plain, target: self, action: #selector(toggleSearchBar))
        ]

        // 键盘
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        // 缩放
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchZoom(_:)))
        view.addGestureRecognizer(pinch)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWallpaper()
        handleQuickFileSwitchChanged()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateNoWrapWidthAsynchronously()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        switcherResetTimer?.invalidate()
    }

    // MARK: - File Load
    func loadFileContent() {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            if isPlist(filePath) && !forceTextMode {
                isPlistMode = true
                if let data = content.data(using: .utf8),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                    plistRoot = plist
                    setupPlistMode()
                    return
                }
            }
            // Load as text
        }
    }

    func loadSiblingFiles() {
        let dir = (filePath as NSString).deletingLastPathComponent
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        siblingFiles = files
            .filter { !hiddenSwitcherFiles.contains($0) }
            .sorted()
        rebuildFileSwitcherButtons()
    }

    // MARK: - Text Mode
    func setupTextMode(content: String) {
        textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: initialFontSize, weight: .regular)
        textView.text = content
        textView.delegate = self
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Plist Mode
    func isPlist(_ path: String) -> Bool {
        return (path as NSString).pathExtension.lowercased() == "plist"
    }

    func setupPlistMode() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.register(UITableViewCell.self, forCellReuseIdentifier: "PlistCell")
        view.addSubview(tableView!)

        refreshPlistData()
    }

    func refreshPlistData() {
        if let dict = plistRoot as? [String: Any] {
            sortedKeys = dict.keys.sorted()
        } else if let arr = plistRoot as? [Any] {
            sortedKeys = (0..<arr.count).map { "\($0)" }
        }
        tableView?.reloadData()
    }

    func editPlistItem(at indexPath: IndexPath) {
        // 编辑 plist 值
    }

    func addPlistItem() {
        // 添加新 key/value
    }

    func createNewItem(of type: String) {
        // 创建指定类型的新项目
    }

    // MARK: - File Switcher
    func setupFileSwitcherBarIfNeeded() {
        guard shouldShowFileSwitcherBar() else { return }
        loadSiblingFiles()
    }

    func shouldShowFileSwitcherBar() -> Bool {
        return TGPreferences.shared.bool(forKey: "quick_file_switch")
    }

    func rebuildFileSwitcherButtons() {
        fileSwitcherBar?.subviews.forEach { $0.removeFromSuperview() }
        for file in siblingFiles {
            let btn = UIButton(type: .system)
            btn.setTitle(file, for: .normal)
            btn.addTarget(self, action: #selector(fileSwitcherBarTapped(_:)), for: .touchUpInside)
        }
    }

    @objc func fileSwitcherBarTapped(_ sender: UIButton) {
        guard let name = sender.titleLabel?.text else { return }
        let dir = (filePath as NSString).deletingLastPathComponent
        let newPath = (dir as NSString).appendingPathComponent(name)
        switchToFile(newPath)
    }

    func switchToFile(_ path: String) {
        saveFile()
        filePath = path
        title = (path as NSString).lastPathComponent
        loadFileContent()
    }

    func hideFileFromSwitcher(_ file: String) {
        hiddenSwitcherFiles.append(file)
        hiddenSwitcherMap[file] = Date()
        saveHiddenSwitcherMap()
        loadSiblingFiles()
        scheduleSwitcherResetTimer()
    }

    func saveHiddenSwitcherMap() {
        // 持久化隐藏列表
    }

    func purgeExpiredHiddenFiles() {
        // 清理过期的隐藏文件
    }

    func scheduleSwitcherResetTimer() {
        switcherResetTimer?.invalidate()
        switcherResetTimer = Timer.scheduledTimer(withTimeInterval: switcherResetInterval(), repeats: false) { [weak self] _ in
            self?.switcherResetTimerFired()
        }
    }

    func switcherResetInterval() -> TimeInterval {
        return TGPreferences.shared.integer(forKey: "switcher_reset_interval") > 0
            ? TimeInterval(TGPreferences.shared.integer(forKey: "switcher_reset_interval")) : 300
    }

    func switcherResetTimerFired() {
        hiddenSwitcherFiles.removeAll()
        loadSiblingFiles()
    }

    var fileSwitcherBarPreferredHeight: CGFloat { return 32 }

    func handleQuickFileSwitchChanged() {}

    // MARK: - Save
    @objc func saveFile() {
        guard let text = textView?.text else { return }
        try? text.write(toFile: filePath, atomically: true, encoding: .utf8)
        originalMD5 = calculateMD5(filePath)
        updateSaveButtonState()
    }

    func updateSaveButtonState() {
        let currentMD5 = calculateMD5(filePath)
        saveButton?.isEnabled = currentMD5 != originalMD5
    }

    func calculateMD5(_ path: String) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return "" }
        // Use CryptoKit (iOS 13+)
        var hasher = Insecure.MD5()
        hasher.update(data: data)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Suggestion
    func initKeywords() {
        allKeywords = [
            // ObjC
            "@interface", "@implementation", "@protocol", "@property", "@synthesize", "@dynamic",
            "@end", "@private", "@protected", "@public", "@package", "@selector",
            // C
            "if", "else", "for", "while", "do", "switch", "case", "break", "continue",
            "return", "typedef", "struct", "enum", "union", "static", "extern", "const",
            "void", "int", "char", "float", "double", "long", "short", "unsigned", "signed",
            // Swift
            "import", "class", "func", "var", "let", "override", "super", "guard", "defer",
            // Theos
            "%hook", "%end", "%orig", "%log", "%new", "%ctor", "%dtor", "%group",
            "MSHookFunction", "MSHookMessageEx", "MSFindSymbol",
        ]
    }

    func setupSuggestionView() {
        suggestionTableView = UITableView()
        suggestionTableView.isHidden = true
        suggestionTableView.dataSource = self
        suggestionTableView.delegate = self
        suggestionTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
        view.addSubview(suggestionTableView)
    }

    func updateSuggestions() {
        guard let text = textView?.text, let selectedRange = textView?.selectedRange else { return }
        // 简单补全: 找当前单词
        let nsText = text as NSString
        let lineStart = nsText.lineRange(for: selectedRange)
        let currentLine = nsText.substring(with: NSRange(location: lineStart.location, length: selectedRange.location - lineStart.location))
        let words = currentLine.split(separator: " ")
        guard let lastWord = words.last else { suggestionList = []; return }

        suggestionList = allKeywords.filter { $0.hasPrefix(String(lastWord)) }
        suggestionTableView.isHidden = suggestionList.isEmpty
        suggestionTableView.reloadData()
    }

    func insertSuggestion(_ suggestion: String) {
        // 插入补全文本
    }

    // MARK: - Search
    @objc func toggleSearchBar() {
        if searchBar == nil {
            searchBar = UISearchBar()
            searchBar?.delegate = self
            navigationItem.titleView = searchBar
            searchBar?.becomeFirstResponder()
        } else {
            navigationItem.titleView = nil
            searchBar = nil
        }
    }

    func highlightSearchText(_ text: String, focusedRange: NSRange?) {
        // 高亮搜索结果
    }

    // MARK: - Edit Actions
    @objc func copyText() {
        UIPasteboard.general.string = textView?.text(in: textView?.selectedTextRange ?? UITextRange())
    }

    @objc func pasteText() {
        if let pasteStr = UIPasteboard.general.string {
            textView?.replace(textView?.selectedTextRange ?? UITextRange(), withText: pasteStr)
        }
    }

    @objc func selectAllText() {
        textView?.selectAll(nil)
    }

    @objc func undoText() {
        textView?.undoManager?.undo()
    }

    func selectNextPlaceholder() {
        // 选择下一个占位符
    }

    func scrollToCursor() {
        textView?.scrollRangeToVisible(textView?.selectedRange ?? NSRange())
    }

    func updateNoWrapWidthAsynchronously() {
        // 禁用自动换行
    }

    // MARK: - Zoom
    @objc func handlePinchZoom(_ gesture: UIPinchGestureRecognizer) {
        guard TGPreferences.shared.bool(forKey: "editor_zoom") else { return }
        let newSize = max(8, min(40, initialFontSize * gesture.scale))
        updateFontSize(newSize)
    }

    func handleZoomScaleChanged() {
        let scale = TGPreferences.shared.integer(forKey: "zoom_scale")
        updateFontSize(CGFloat(scale > 0 ? scale : 13))
    }

    func updateFontSize(_ size: CGFloat) {
        initialFontSize = size
        textView?.font = .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Keyboard
    @objc func keyboardWillShow(_ notification: Notification) {
        isKeyboardVisible = true
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        textView?.contentInset.bottom = frame.height
        textView?.verticalScrollIndicatorInsets.bottom = frame.height
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        isKeyboardVisible = false
        textView?.contentInset.bottom = 0
        textView?.verticalScrollIndicatorInsets.bottom = 0
    }

    @objc func dismissKeyboard() {
        textView?.resignFirstResponder()
    }

    // MARK: - Misc
    func updateWallpaper() { view.backgroundColor = .systemBackground }
    func updateWallpaperBrightness() {}
}

// MARK: - UITextViewDelegate
extension FileEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSaveButtonState()
        updateSuggestions()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateSuggestions()
    }
}

// MARK: - UITableView for Plist
extension FileEditorViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlistCell", for: indexPath)
        let key = sortedKeys[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = key
        if let dict = plistRoot as? [String: Any] {
            let val = dict[key]
            config.secondaryText = "\(val ?? "")"
        }
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let key = sortedKeys[indexPath.row]
            if var dict = plistRoot as? [String: Any] {
                dict.removeValue(forKey: key)
                plistRoot = dict
                refreshPlistData()
            }
        }
    }
}

extension FileEditorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView == suggestionTableView {
            insertSuggestion(suggestionList[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        editPlistItem(at: indexPath)
    }
}

// MARK: - UISearchBarDelegate
extension FileEditorViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // 实时搜索
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) { toggleSearchBar() }
}

// MARK: - UIScrollViewDelegate
extension FileEditorViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Line number sync
    }
}

// Note: MD5 needs CommonCrypto bridge header or use CryptoKit for iOS 13+
#if canImport(CryptoKit)
import CryptoKit

extension FileEditorViewController {
    func md5WithCryptoKit(_ path: String) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return "" }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
