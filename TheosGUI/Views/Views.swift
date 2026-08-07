// MARK: - Views.swift
// TheosGUI Clone — 自定义 UI 组件

import UIKit
import WebKit

// ======================================================================
// MARK: - ChatMessageBubble
// ======================================================================
class ChatMessageBubble: UIView {
    let message: ChatMessage
    let index: Int

    var onCopyCode: ((String) -> Void)?
    var onCopyMessage: (() -> Void)?
    var onDelete: (() -> Void)?
    var onResend: (() -> Void)?

    private let bubbleView = UIView()
    private let contentLabel = UILabel()
    private let roleLabel = UILabel()

    init(message: ChatMessage, index: Int) {
        self.message = message
        self.index = index
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupView() {
        contentLabel.text = message.content
        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)

        roleLabel.text = message.role == .user ? "👤" : "🤖"
        roleLabel.font = .systemFont(ofSize: 12)

        switch message.role {
        case .user:
            bubbleView.backgroundColor = .systemBlue.withAlphaComponent(0.2)
            contentLabel.textAlignment = .right
        case .assistant:
            bubbleView.backgroundColor = .systemGray5
            contentLabel.textAlignment = .left
        case .system:
            bubbleView.backgroundColor = .systemYellow.withAlphaComponent(0.2)
            contentLabel.textAlignment = .center
        }

        bubbleView.layer.cornerRadius = 12
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleView)

        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(contentLabel)

        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(roleLabel)

        NSLayoutConstraint.activate([
            roleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            roleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),

            bubbleView.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
        ])

        // 长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress() {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "复制", style: .default) { [weak self] _ in self?.onCopyMessage?() })
        menu.addAction(UIAlertAction(title: "重新发送", style: .default) { [weak self] _ in self?.onResend?() })
        menu.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in self?.onDelete?() })
        menu.addAction(UIAlertAction(title: "取消", style: .cancel))
        // Find the view controller
        if let vc = findViewController() {
            vc.present(menu, animated: true)
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

// ======================================================================
// MARK: - ShareAppCell
// ======================================================================
class ShareAppCell: UICollectionViewCell {
    let iconView = UIImageView()
    let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 12
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
}

// ======================================================================
// MARK: - ConsoleTextView
// ======================================================================
class ConsoleTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(addToChat(_:)) { return true }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func addToChat(_ sender: Any?) {
        guard let selectedText = text(in: selectedTextRange ?? UITextRange()) else { return }
        NotificationCenter.default.post(name: .addToChat, object: selectedText)
    }

    override var textInputContextIdentifier: String? { return "console" }
}

extension Notification.Name {
    static let addToChat = Notification.Name("addToChat")
    static let executeCommand = Notification.Name("executeCommand")
}

// ======================================================================
// MARK: - FileEditorTextView
// ======================================================================
class FileEditorTextView: UITextView {
    var lineNumberView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()
        // 行号视图布局
    }
}

// ======================================================================
// MARK: - AlertViewController
// ======================================================================
class AlertViewController: UIViewController {
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let stackView = UIStackView()
    private var actions: [AlertAction] = []

    struct AlertAction {
        let title: String
        let image: UIImage?
        let style: UIAlertAction.Style
        let handler: (() -> Void)?
        let autoDismiss: Bool

        init(title: String, image: UIImage? = nil, style: UIAlertAction.Style = .default, autoDismiss: Bool = true, handler: (() -> Void)? = nil) {
            self.title = title
            self.image = image
            self.style = style
            self.autoDismiss = autoDismiss
            self.handler = handler
        }
    }

    func addAction(_ action: AlertAction) {
        actions.append(action)
    }

    func addActions(_ newActions: [AlertAction]) {
        actions.append(contentsOf: newActions)
    }
}

// ======================================================================
// MARK: - ActionsMenuViewController
// ======================================================================
class ActionsMenuViewController: UIViewController {
    private var tableView: UITableView!
    var actions: [UIAction] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 300, height: CGFloat(actions.count * 44))
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
    }
}

extension ActionsMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { actions.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let action = actions[indexPath.row]
        cell.textLabel?.text = action.title
        cell.imageView?.image = action.image
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true)
        actions[indexPath.row].performWithSender(nil, target: nil)
    }
}

// ======================================================================
// MARK: - PasscodeFieldCell
// ======================================================================
class PasscodeFieldCell: UITableViewCell {
    private let textField = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textField.isSecureTextEntry = true
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
}

// ======================================================================
// MARK: - SyntaxHighlightTextStorage
// ======================================================================
class SyntaxHighlightTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()

    override var string: String { backingStore.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        super.processEditing()
        // Apply syntax highlighting
        highlightSyntax()
    }

    private func highlightSyntax() {
        let fullRange = NSRange(location: 0, length: backingStore.length)
        backingStore.removeAttribute(.foregroundColor, range: fullRange)
        backingStore.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)

        let text = backingStore.string as NSString
        let patterns: [(String, UIColor)] = [
            ("@interface|@implementation|@protocol|@property|@end|@selector", .systemPurple),
            ("#import|#include|#define|#ifdef|#endif|#pragma", .systemOrange),
            ("void|int|char|float|double|long|BOOL|id|instancetype|SEL", .systemBlue),
            ("//.*", .systemGray),
            ("@\"[^\"]*\"", .systemRed),
        ]

        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: backingStore.string, range: fullRange)
                for match in matches {
                    backingStore.addAttribute(.foregroundColor, value: color, range: match.range)
                }
            }
        }
    }
}
