// MARK: - ConsoleViewController.swift
// TheosGUI Clone — 终端/控制台 (58 methods in original)
// 功能: Shell 执行 / ANSI 颜色 / 伪终端 / 本地编译模式

import UIKit
import Foundation

class ConsoleViewController: UIViewController {

    // MARK: - Properties
    private var textView: UITextView!
    private var toolbar: UIToolbar!
    private var toolbarBottomConstraint: NSLayoutConstraint!

    var shellPID: pid_t = 0
    var masterFD: Int32 = -1
    var fileHandle: FileHandle?
    var targetPath: String = "/"
    var isLocalCompileMode: Bool = false
    var isControlPressed: Bool = false
    var cursorAtLineStart: Bool = true
    var currentAttributes: [NSAttributedString.Key: Any] = [:]
    var pendingCommand: String?

    // 辅助键
    private var inputSymbol: UILabel!
    private var commandBuffer: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "控制台"
        setupTextView()
        setupAccessoryView()
        setupKeyboardObservers()
        startShell()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWallpaper()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        textView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: toolbar.bounds.height + 8, right: 0)
    }

    // MARK: - UI Setup
    private func setupTextView() {
        textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .black
        textView.textColor = .green
        textView.isEditable = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupAccessoryView() {
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        toolbarBottomConstraint = toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarBottomConstraint,
        ])

        let ctrlItem = UIBarButtonItem(title: "Ctrl", style: .plain, target: self, action: #selector(toggleControl(_:)))
        let upItem = UIBarButtonItem(image: UIImage(systemName: "arrow.up"), style: .plain, target: self, action: #selector(sendUp))
        let downItem = UIBarButtonItem(image: UIImage(systemName: "arrow.down"), style: .plain, target: self, action: #selector(sendDown))
        let leftItem = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(moveCursorLeft))
        let rightItem = UIBarButtonItem(image: UIImage(systemName: "arrow.right"), style: .plain, target: self, action: #selector(moveCursorRight))
        let escItem = UIBarButtonItem(title: "Esc", style: .plain, target: self, action: #selector(sendEsc))
        let clearItem = UIBarButtonItem(title: "清屏", style: .plain, target: self, action: #selector(clearLog))
        let copyItem = UIBarButtonItem(title: "复制", style: .plain, target: self, action: #selector(copyLog))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [ctrlItem, flex, escItem, flex, upItem, downItem, leftItem, rightItem, flex, clearItem, flex, copyItem]
    }

    // MARK: - Keyboard
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        UIView.animate(withDuration: 0.25) {
            self.toolbarBottomConstraint.constant = -frame.height + self.view.safeAreaInsets.bottom
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.25) {
            self.toolbarBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    @objc func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    // MARK: - Shell
    func startShell() {
        appendLog("[TheosGUI Console]", color: .yellow)
        appendLog("Type command and press Enter to execute", color: .gray)
        appendLog("---")
        updateWindowSize()
    }

    /// 执行命令 (统一入口)
    func executeCommand(_ command: String) {
        appendLog("$ \(command)", color: .white)
        commandBuffer = ""

        // 异步执行
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.executeShell(command: command)
            DispatchQueue.main.async {
                self.appendLog(output, color: .lightGray)
                self.appendLog("---")
            }
        }
    }

    /// 实际的 Shell 执行
    @discardableResult
    class func executeShellCommand(_ command: String, completion: ((String) -> Void)? = nil) -> Int32 {
        let result = spawnShell(command)
        completion?(result.output ?? "")
        return result.exitCode
    }

    private func executeShell(command: String) -> String {
        let cmd = "cd \"\(targetPath)\" && \(command)"
        let result = spawnShell(cmd)
        return result.output ?? "nil"
    }

    func executeExecutable(_ path: String, arguments: [String]) {
        let fullCmd = ([path] + arguments).joined(separator: " ")
        executeCommand(fullCmd)
    }

    // MARK: - Output
    func appendLog(_ text: String, color: UIColor = .green) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: color
        ]
        let attrStr = NSAttributedString(string: text + "\n", attributes: attr)
        let mutableText = textView.attributedText.mutableCopy() as? NSMutableAttributedString ?? NSMutableAttributedString()
        mutableText.append(attrStr)
        textView.attributedText = mutableText
        scrollToBottom()
    }

    func appendOutput(_ output: String, color: UIColor = .green) {
        appendLog(output, color: color)
    }

    func appendAnsiLog(_ raw: String) {
        // 简化版 ANSI 颜色处理
        let stripped = raw.replacingOccurrences(of: "\u{001B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
        appendLog(stripped)
    }

    func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    func updateAttributes(with params: [String: Any]) {
        // 字体大小/颜色调整
    }

    // MARK: - Actions
    @objc func clearLog() {
        textView.text = ""
        appendLog("[cleared]")
    }

    @objc func copyLog() {
        UIPasteboard.general.string = textView.text
    }

    @objc func sendUp() {
        // 发送 ↑ 箭头键
        appendLog("↑")
    }

    @objc func sendDown() {
        appendLog("↓")
    }

    @objc func sendEsc() {
        // 发送 ESC
    }

    @objc func moveCursorLeft() {
        if let range = textView.selectedTextRange {
            if let newPos = textView.position(from: range.start, offset: -1) {
                textView.selectedTextRange = textView.textRange(from: newPos, to: newPos)
            }
        }
    }

    @objc func moveCursorRight() {
        if let range = textView.selectedTextRange {
            if let newPos = textView.position(from: range.start, offset: 1) {
                textView.selectedTextRange = textView.textRange(from: newPos, to: newPos)
            }
        }
    }

    @objc func toggleControl(_ sender: UIBarButtonItem) {
        isControlPressed.toggle()
        sender.tintColor = isControlPressed ? .systemRed : .systemBlue
    }

    func updateWindowSize() {
        // 更新终端窗口大小
    }

    func updateWallpaper() {
        textView.backgroundColor = .black
    }

    func updateWallpaperBrightness() {}

    // MARK: - Scroll
    private func scrollToBottom() {
        let bottom = NSMakeRange(textView.attributedText.length - 1, 1)
        textView.scrollRangeToVisible(bottom)
    }
}

// MARK: - UITextViewDelegate
extension ConsoleViewController: UITextViewDelegate {
    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        if text == "\n" {
            // Enter → 执行命令
            guard let fullText = textView.text else { return false }

            // 获取当前行
            let nsText = fullText as NSString
            let lines = nsText.components(separatedBy: "\n")
            guard let lastLine = lines.last else { return false }

            // 找到 $ 提示符后的命令
            if let cmdRange = lastLine.range(of: "$ ") {
                let command = String(lastLine[cmdRange.upperBound...])
                if !command.trimmingCharacters(in: .whitespaces).isEmpty {
                    executeCommand(command)
                    return false
                }
            }
        }

        return true
    }
}
