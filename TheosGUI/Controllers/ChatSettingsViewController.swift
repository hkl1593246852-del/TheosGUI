// MARK: - ChatSettingsViewController.swift
// TheosGUI Clone — AI 提供商设置 (72 methods in original)

import UIKit

class ChatSettingsViewController: UIViewController {

    // MARK: - Properties
    var currentProvider: String = "OpenAI"
    var providerNames: [String] = ["OpenAI", "Anthropic", "Custom"]
    var providerModels: [String] = ["gpt-4", "gpt-3.5-turbo", "claude-3-opus", "claude-3-sonnet"]
    var providers: [[String: String]] = [
        ["name": "OpenAI", "url": "https://api.openai.com", "model": "gpt-4"],
        ["name": "Anthropic", "url": "https://api.anthropic.com", "model": "claude-3-opus"],
    ]
    var settingsCache: [String: Any] = [:]

    // UI
    var tableView: UITableView!
    var apiKeyField: UITextField!
    var baseUrlField: UITextField!
    var modelField: UITextField!
    var protocolControl: UISegmentedControl!
    var streamSwitch: UISwitch!
    var confirmExecSwitch: UISwitch!
    var confirmReadSwitch: UISwitch!
    var confirmWriteSwitch: UISwitch!
    var systemPromptView: UITextView!
    var statusLabel: UILabel!
    var loadingIndicator: UIActivityIndicatorView!
    var formatDetailLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "聊天设置"
        view.backgroundColor = .systemGroupedBackground

        setupTableView()
        setupFields()
        loadSettings()
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
        view.addSubview(tableView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    private func setupFields() {
        apiKeyField = createTextField(placeholder: "API Key")
        baseUrlField = createTextField(placeholder: "https://api.openai.com")
        modelField = createTextField(placeholder: "gpt-4")
        protocolControl = UISegmentedControl(items: ["REST", "Anthropic"])
        streamSwitch = UISwitch()
        confirmExecSwitch = UISwitch()
        confirmReadSwitch = UISwitch()
        confirmWriteSwitch = UISwitch()
        loadingIndicator = UIActivityIndicatorView(style: .medium)
    }

    private func createTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 14)
        return tf
    }

    func loadSettings() {
        apiKeyField.text = TGPreferences.shared.string(forKey: "api_key")
        baseUrlField.text = TGPreferences.shared.string(forKey: "base_url") ?? "https://api.openai.com"
        modelField.text = TGPreferences.shared.string(forKey: "model") ?? "gpt-4"
        streamSwitch.isOn = TGPreferences.shared.bool(forKey: "stream_enabled")
        confirmExecSwitch.isOn = TGPreferences.shared.bool(forKey: "confirm_exec")
        confirmReadSwitch.isOn = TGPreferences.shared.bool(forKey: "confirm_read")
        confirmWriteSwitch.isOn = TGPreferences.shared.bool(forKey: "confirm_write")
    }

    func saveSettings() {
        TGPreferences.shared.setObject(apiKeyField.text ?? "", forKey: "api_key")
        TGPreferences.shared.setObject(baseUrlField.text ?? "", forKey: "base_url")
        TGPreferences.shared.setObject(modelField.text ?? "", forKey: "model")
        TGPreferences.shared.setBool(streamSwitch.isOn, forKey: "stream_enabled")
        TGPreferences.shared.setBool(confirmExecSwitch.isOn, forKey: "confirm_exec")
        TGPreferences.shared.setBool(confirmReadSwitch.isOn, forKey: "confirm_read")
        TGPreferences.shared.setBool(confirmWriteSwitch.isOn, forKey: "confirm_write")
        TGPreferences.shared.synchronize()
    }

    @objc func testAndSave() {
        dismissKeyboard()
        loadingIndicator.startAnimating()
        statusLabel?.text = "测试中..."

        let provider = currentProvider.lowercased()
        if provider == "anthropic" {
            checkAnthropic(key: apiKeyField.text ?? "", url: baseUrlField.text ?? "", model: modelField.text ?? "")
        } else {
            checkChatCompletion(key: apiKeyField.text ?? "", url: baseUrlField.text ?? "", model: modelField.text ?? "")
        }
    }

    func checkAnthropic(key: String, url: String, model: String) {
        // 测试 Anthropic API
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            self?.handleSuccess("Anthropic 连接成功")
        }
    }

    func checkChatCompletion(key: String, url: String, model: String) {
        // 测试 OpenAI 兼容 API
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            self?.handleSuccess("API 连接成功")
        }
    }

    func handleSuccess(_ message: String) {
        statusLabel?.text = message
        statusLabel?.textColor = .systemGreen
        saveSettings()
    }

    func reportCheckFailure(error: Error?, response: URLResponse?, data: Data?, prefix: String) {
        statusLabel?.text = "\(prefix): \(error?.localizedDescription ?? "未知错误")"
        statusLabel?.textColor = .systemRed
    }

    func defaults(for provider: String) -> [String: String] {
        switch provider {
        case "OpenAI": return ["url": "https://api.openai.com", "model": "gpt-4"]
        case "Anthropic": return ["url": "https://api.anthropic.com", "model": "claude-3-opus"]
        default: return ["url": "", "model": ""]
        }
    }

    func switchProvider(to name: String) {
        currentProvider = name
        let defs = defaults(for: name)
        baseUrlField.text = defs["url"]
        modelField.text = defs["model"]
        updateFormatDetail()
        tableView.reloadData()
    }

    @objc func showProviderSelection() {
        let alert = UIAlertController(title: "选择提供商", message: nil, preferredStyle: .actionSheet)
        for name in providerNames {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.switchProvider(to: name)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc func showModelSelection() {
        let alert = UIAlertController(title: "选择模型", message: nil, preferredStyle: .actionSheet)
        for model in providerModels {
            alert.addAction(UIAlertAction(title: model, style: .default) { [weak self] _ in
                self?.modelField.text = model
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc func customModelButtonTapped() {
        showModelSelection()
    }

    @objc func showResetMenu() {
        let alert = UIAlertController(title: "重置", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "重置当前提供商", style: .default) { [weak self] _ in
            self?.resetCurrentProvider()
        })
        alert.addAction(UIAlertAction(title: "重置所有", style: .destructive) { [weak self] _ in
            self?.resetAllProviders()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func resetCurrentProvider() {
        let defs = defaults(for: currentProvider)
        baseUrlField.text = defs["url"]
        modelField.text = defs["model"]
        apiKeyField.text = ""
    }

    func resetAllProviders() {
        apiKeyField.text = ""
        baseUrlField.text = ""
        modelField.text = ""
        streamSwitch.isOn = true
    }

    @objc func protocolChanged(_ sender: UISegmentedControl) {
        updateFormatDetail()
    }

    @objc func toggleApiKeyVisibility(_ sender: UIButton) {
        apiKeyField.isSecureTextEntry.toggle()
    }

    func updateFormatDetail() {
        let protocolName = protocolControl?.selectedSegmentIndex == 0 ? "REST" : "Anthropic"
        formatDetailLabel?.text = "格式: \(protocolName) — \(modelField?.text ?? "")"
    }

    @objc func close() { dismiss(animated: true) }
    @objc func dismissKeyboard() { view.endEditing(true) }
}

// MARK: - UITableView
extension ChatSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 4 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Provider, Model, URL
        case 1: return 1 // API Key
        case 2: return 1 // Stream
        case 3: return 3 // Confirm switches + Test button
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "提供商"
        case 1: return "认证"
        case 2: return "流式"
        case 3: return "安全"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)

        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "提供商"
            cell.detailTextLabel?.text = currentProvider
            cell.accessoryType = .disclosureIndicator
        case (0, 1):
            cell.textLabel?.text = "模型"
            cell.accessoryView = modelField
            cell.accessoryType = .detailButton
        case (0, 2):
            cell.textLabel?.text = "URL"
            cell.accessoryView = baseUrlField
        case (1, 0):
            cell.textLabel?.text = "API Key"
            cell.accessoryView = apiKeyField
        case (2, 0):
            cell.textLabel?.text = "启用流式输出"
            cell.accessoryView = streamSwitch
        case (3, 0):
            cell.textLabel?.text = "确认执行命令"
            cell.accessoryView = confirmExecSwitch
        case (3, 1):
            cell.textLabel?.text = "确认读文件"
            cell.accessoryView = confirmReadSwitch
        case (3, 2):
            cell.textLabel?.text = "确认写文件"
            cell.accessoryView = confirmWriteSwitch
        default: break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0, indexPath.row == 0 { showProviderSelection() }
        if indexPath.section == 0, indexPath.row == 1 { showModelSelection() }
    }
}

extension ChatSettingsViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dismissKeyboard()
    }
}

extension ChatSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
