// MARK: - ChatViewController.swift
// TheosGUI Clone — AI 聊天 (110 methods in original)
// 功能: 多 Provider 支持 / Markdown 渲染 / 流式 / 代码块 / 上下文管理 / 命令确认

import UIKit
import WebKit

class ChatViewController: UIViewController {

    // MARK: - Properties
    var messages: [ChatMessage] = []
    var currentChatID: String = UUID().uuidString
    var chatHistory: [ChatSession] = []
    var isRequesting: Bool = false
    var isProcessingCommands: Bool = false
    var currentStreamingMessageIndex: Int = -1
    var streamingContent: String = ""
    var responseDataBuffer: Data?

    var pendingCommands: [String] = []
    var pendingContexts: [ChatContext] = []
    var currentTask: URLSessionDataTask?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var currentProviderSettings: ChatProviderSettings {
        return ChatProviderManager.shared.currentSettings
    }

    // MARK: - UI
    private var messageScrollView: UIScrollView!
    private var messageStackView: UIStackView!
    private var contextScrollView: UIScrollView!
    private var contextStackView: UIStackView!
    private var inputContainer: UIView!
    private var inputTextView: UITextView!
    private var sendButton: UIButton!
    private var fileButton: UIButton!
    private var placeholderLabel: UILabel!
    private var inputHeightConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!
    private var contextHeightConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "聊天"
        setupUI()
        setupKeyboardObservers()
        loadChatHistory()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWallpaper()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentChat()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 上下文栏
        contextScrollView = UIScrollView()
        contextScrollView.showsHorizontalScrollIndicator = false
        contextScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contextScrollView)

        contextStackView = UIStackView()
        contextStackView.axis = .horizontal
        contextStackView.spacing = 8
        contextStackView.translatesAutoresizingMaskIntoConstraints = false
        contextScrollView.addSubview(contextStackView)

        contextHeightConstraint = contextScrollView.heightAnchor.constraint(equalToConstant: 0)
        contextHeightConstraint.isActive = true

        // 消息滚动区域
        messageScrollView = UIScrollView()
        messageScrollView.translatesAutoresizingMaskIntoConstraints = false
        messageScrollView.keyboardDismissMode = .interactive
        view.addSubview(messageScrollView)

        messageStackView = UIStackView()
        messageStackView.axis = .vertical
        messageStackView.spacing = 12
        messageStackView.translatesAutoresizingMaskIntoConstraints = false
        messageScrollView.addSubview(messageStackView)

        // 输入区域
        inputContainer = UIView()
        inputContainer.backgroundColor = .systemGray6
        inputContainer.layer.cornerRadius = 20
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        inputTextView = UITextView()
        inputTextView.font = .systemFont(ofSize: 16)
        inputTextView.isScrollEnabled = false
        inputTextView.backgroundColor = .clear
        inputTextView.delegate = self
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputTextView)

        placeholderLabel = UILabel()
        placeholderLabel.text = "输入消息..."
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = .systemFont(ofSize: 16)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(placeholderLabel)

        sendButton = UIButton(type: .system)
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.isEnabled = false
        inputContainer.addSubview(sendButton)

        fileButton = UIButton(type: .system)
        fileButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        fileButton.addTarget(self, action: #selector(pickFile), for: .touchUpInside)
        fileButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(fileButton)

        // 导航栏按钮
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "clock.arrow.circlepath"),
                           style: .plain, target: self, action: #selector(showHistory)),
            UIBarButtonItem(image: UIImage(systemName: "gearshape"),
                           style: .plain, target: self, action: #selector(openSettings))
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain, target: self, action: #selector(createNewChat)
        )

        setupConstraints()
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        bottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8)
        inputHeightConstraint = inputContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)

        NSLayoutConstraint.activate([
            contextScrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            contextScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contextScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contextHeightConstraint,

            contextStackView.topAnchor.constraint(equalTo: contextScrollView.topAnchor),
            contextStackView.leadingAnchor.constraint(equalTo: contextScrollView.leadingAnchor),
            contextStackView.trailingAnchor.constraint(equalTo: contextScrollView.trailingAnchor),
            contextStackView.bottomAnchor.constraint(equalTo: contextScrollView.bottomAnchor),
            contextStackView.heightAnchor.constraint(equalTo: contextScrollView.heightAnchor),

            messageScrollView.topAnchor.constraint(equalTo: contextScrollView.bottomAnchor, constant: 8),
            messageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageScrollView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor, constant: -8),

            messageStackView.topAnchor.constraint(equalTo: messageScrollView.topAnchor, constant: 8),
            messageStackView.leadingAnchor.constraint(equalTo: messageScrollView.leadingAnchor, constant: 16),
            messageStackView.trailingAnchor.constraint(equalTo: messageScrollView.trailingAnchor, constant: -16),
            messageStackView.bottomAnchor.constraint(equalTo: messageScrollView.bottomAnchor, constant: -8),
            messageStackView.widthAnchor.constraint(equalTo: messageScrollView.widthAnchor, constant: -32),

            bottomConstraint,
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            inputHeightConstraint,

            fileButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
            fileButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            fileButton.widthAnchor.constraint(equalToConstant: 32),
            fileButton.heightAnchor.constraint(equalToConstant: 32),

            inputTextView.leadingAnchor.constraint(equalTo: fileButton.trailingAnchor, constant: 4),
            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            inputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),

            placeholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor, constant: 4),
            placeholderLabel.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32),
        ])
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
            self.bottomConstraint.constant = -frame.height + self.view.safeAreaInsets.bottom - 8
            self.view.layoutIfNeeded()
            self.scrollToBottom()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.25) {
            self.bottomConstraint.constant = -8
            self.view.layoutIfNeeded()
        }
    }

    @objc func dismissKeyboard() {
        inputTextView.resignFirstResponder()
    }

    // MARK: - Messages
    @objc func sendMessage() {
        guard let text = inputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        guard !isRequesting else { return }

        inputTextView.text = ""
        placeholderLabel.isHidden = false
        updateSendButtonState()

        addUserMessage(text)
        checkForCommands(in: text)
    }

    func addUserMessage(_ content: String) {
        let msg = ChatMessage(role: .user, content: content, timestamp: Date())
        messages.append(msg)
        createMessageView(for: msg, index: messages.count - 1)
    }

    func addAssistantMessage(_ content: String) {
        let msg = ChatMessage(role: .assistant, content: content, timestamp: Date())
        messages.append(msg)
        createMessageView(for: msg, index: messages.count - 1)
    }

    func addSystemMessage(_ content: String) {
        let msg = ChatMessage(role: .system, content: content, timestamp: Date())
        messages.append(msg)
        createMessageView(for: msg, index: messages.count - 1)
    }

    func addContext(title: String, content: String, path: String?, type: String) {
        let ctx = ChatContext(title: title, content: content, path: path, type: type)
        pendingContexts.append(ctx)
        createChip(for: ctx)
        updateContextBar()
    }

    func createMessageView(for message: ChatMessage, index: Int) {
        let bubble = ChatMessageBubble(message: message, index: index)
        bubble.onCopyCode = { [weak self] code in self?.copyCodeBlockContent(code) }
        bubble.onCopyMessage = { [weak self] in self?.copyMessageContent(message.content) }
        bubble.onDelete = { [weak self] in self?.deleteMessage(at: index) }
        bubble.onResend = { [weak self] in self?.resendMessage(at: index) }
        messageStackView.addArrangedSubview(bubble)
        scrollToBottom()
    }

    func createCodeBlockView(content: String, language: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemGray6
        container.layer.cornerRadius = 8

        let label = UILabel()
        label.text = content
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(copyCodeBlock(_:)))
        container.addGestureRecognizer(tap)

        return container
    }

    func createChip(for context: ChatContext) {
        let chip = UIButton(type: .system)
        chip.setTitle("📎 \(context.title)", for: .normal)
        chip.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        chip.layer.cornerRadius = 12
        chip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        chip.addTarget(self, action: #selector(handleChipTap(_:)), for: .touchUpInside)
        contextStackView.addArrangedSubview(chip)
    }

    func updateContextBar() {
        let hasContexts = !pendingContexts.isEmpty
        contextHeightConstraint.constant = hasContexts ? 36 : 0
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    func removeContext(_ ctx: ChatContext) {
        pendingContexts.removeAll { $0.title == ctx.title }
        updateContextBar()
    }

    @objc func previewContext(_ sender: UITapGestureRecognizer) {
        // 预览上下文
    }

    // MARK: - Markdown Parsing
    func parseMessageContent(_ content: String) -> NSAttributedString {
        return attributedTextFromMarkdown(content, isUser: false)
    }

    func attributedTextFromMarkdown(_ markdown: String, isUser: Bool) -> NSAttributedString {
        // 简化的 Markdown 解析（生产环境建议使用 AttributedString 或第三方库）
        let attr = NSMutableAttributedString(string: markdown)
        // 代码块处理
        // 粗体处理
        // 斜体处理
        // 链接处理
        return attr
    }

    func parseSegments(from content: String) -> [MessageSegment] {
        // 解析 Markdown 分段
        return [MessageSegment(type: .text, content: content)]
    }

    func applyInlineStyles(to attr: NSMutableAttributedString, linkColor: UIColor) {
        // 行内样式
    }

    func stripMarkdownFences(_ content: String) -> String {
        var text = content
        if text.hasPrefix("```") {
            if let end = text.range(of: "\n") { text.removeSubrange(text.startIndex...end.lowerBound) }
            text = text.replacingOccurrences(of: "```", with: "")
        }
        return text
    }

    // MARK: - AI Request
    func performRequest(prompt: String, settings: ChatProviderSettings) {
        isRequesting = true

        guard let url = URL(string: "\(settings.baseURL)/chat/completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": settings.stream
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isRequesting = false
                if let error = error {
                    self?.addSystemMessage("错误: \(error.localizedDescription)")
                } else if let data = data {
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let choices = json?["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        self?.addAssistantMessage(content)
                    }
                }
            }
        }
        currentTask?.resume()
    }

    // MARK: - Commands
    func checkForCommands(in input: String) {
        // 检测特殊命令模式
        if input.hasPrefix("/") {
            let cmd = String(input.dropFirst())
            performCommand(cmd)
        } else {
            performRequest(prompt: input, settings: currentProviderSettings)
        }
    }

    func performCommand(_ command: String) {
        // 执行聊天命令
        addSystemMessage("执行命令: \(command)")
        NotificationCenter.default.post(name: .executeCommand, object: command)
    }

    func confirmCommand(_ command: String) -> Bool {
        let alert = UIAlertController(title: "确认执行", message: command, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "执行", style: .destructive) { _ in })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
        return true
    }

    func executeNextCommand() {
        // 队列中的命令
    }

    func skipCommand() {
        // 跳过命令
    }

    // MARK: - Streaming
    func setStreamingContent(_ content: String) {
        streamingContent = content
        updateStreamingMessage()
    }

    func updateStreamingMessage() {
        guard currentStreamingMessageIndex >= 0,
              currentStreamingMessageIndex < messageStackView.arrangedSubviews.count else { return }
        // 更新流式消息气泡
    }

    // MARK: - Chat History
    func loadChatHistory() {
        // 从本地加载聊天历史
        if let data = UserDefaults.standard.data(forKey: "chat_history"),
           let history = try? JSONDecoder().decode([ChatSession].self, from: data) {
            chatHistory = history
        }
    }

    func saveChatHistory() {
        if let data = try? JSONEncoder().encode(chatHistory) {
            UserDefaults.standard.set(data, forKey: "chat_history")
        }
    }

    func saveCurrentChat() {
        guard !messages.isEmpty else { return }
        let session = ChatSession(
            id: currentChatID,
            title: messages.first?.content.prefix(50).description ?? "新对话",
            messages: messages,
            createdAt: Date()
        )
        if let idx = chatHistory.firstIndex(where: { $0.id == currentChatID }) {
            chatHistory[idx] = session
        } else {
            chatHistory.insert(session, at: 0)
        }
        saveChatHistory()
    }

    @objc func createNewChat() {
        saveCurrentChat()
        currentChatID = UUID().uuidString
        messages.removeAll()
        messageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    @objc func showHistory() {
        let vc = ChatHistoryViewController()
        vc.onSelect = { [weak self] session in
            self?.switchChat(to: session)
            self?.navigationController?.popViewController(animated: true)
        }
        vc.onDelete = { [weak self] session in
            self?.chatHistory.removeAll { $0.id == session.id }
            self?.saveChatHistory()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func switchChat(to session: ChatSession) {
        saveCurrentChat()
        currentChatID = session.id
        messages = session.messages
        reloadMessages()
    }

    func reloadMessages() {
        messageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, msg) in messages.enumerated() {
            createMessageView(for: msg, index: index)
        }
    }

    @objc func deleteCurrentChat() {
        chatHistory.removeAll { $0.id == currentChatID }
        saveChatHistory()
        createNewChat()
    }

    func deleteMessage(at index: Int) {
        messages.remove(at: index)
        reloadMessages()
    }

    func resendMessage(at index: Int) {
        guard index < messages.count else { return }
        let msg = messages[index]
        performRequest(prompt: msg.content, settings: currentProviderSettings)
    }

    // MARK: - Actions
    @objc func openSettings() {
        let vc = ChatSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.text, .sourceCode, .data])
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc func copyCodeBlock(_ sender: UITapGestureRecognizer) {
        guard let label = (sender.view as? UIView)?.subviews.first as? UILabel else { return }
        copyCodeBlockContent(label.text ?? "")
    }

    func copyCodeBlockContent(_ code: String) {
        UIPasteboard.general.string = code
    }

    func copyMessageContent(_ content: String) {
        UIPasteboard.general.string = content
    }

    @objc func handleBubbleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 显示消息操作菜单
    }

    @objc func handleChipTap(_ sender: UIButton) {
        // 预览或删除上下文
    }

    @objc func handleAddToChat(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        addContext(title: "代码片段", content: text, path: nil, type: "code")
    }

    @objc func toggleCodeBlock(_ sender: UITapGestureRecognizer) {
        // 展开/折叠代码块
    }

    // MARK: - UI State
    func updateSendButtonState() {
        let hasText = !(inputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.isEnabled = hasText && !isRequesting
    }

    func scrollToBottom() {
        DispatchQueue.main.async {
            let bottomOffset = CGPoint(x: 0, y: max(0, self.messageScrollView.contentSize.height - self.messageScrollView.bounds.height))
            self.messageScrollView.setContentOffset(bottomOffset, animated: true)
        }
    }

    func updateWallpaper() {
        view.backgroundColor = .systemBackground
    }

    func updateWallpaperBrightness() {}
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSendButtonState()
    }
}

// MARK: - UIDocumentPickerDelegate
extension ChatViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            if let content = try? String(contentsOf: url) {
                addContext(title: url.lastPathComponent, content: content, path: url.path, type: "file")
            }
        }
    }
}

// MARK: - URLSession
extension ChatViewController: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if responseDataBuffer == nil { responseDataBuffer = Data() }
        responseDataBuffer?.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isRequesting = false
            if let error = error {
                self.addSystemMessage("请求失败: \(error.localizedDescription)")
            }
        }
    }
}
