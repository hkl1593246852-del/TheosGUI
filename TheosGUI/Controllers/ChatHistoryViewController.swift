// MARK: - ChatHistoryViewController.swift
// TheosGUI Clone — 聊天历史管理

import UIKit

class ChatHistoryViewController: UIViewController {

    var chats: [ChatSession] = []
    var currentChatID: String = ""
    var sections: [(title: String, items: [ChatSession])] = []
    var onSelect: ((ChatSession) -> Void)?
    var onCreate: (() -> Void)?
    var onDelete: ((ChatSession) -> Void)?
    var groupedChats: [String: [ChatSession]] { [:] }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "聊天历史"
        view.backgroundColor = .systemGroupedBackground

        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
        view.addSubview(tableView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(createNew)
        )

        loadChatHistory()
    }

    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "chat_history"),
           let history = try? JSONDecoder().decode([ChatSession].self, from: data) {
            chats = history
            groupChats()
        }
    }

    private func groupChats() {
        let grouped = Dictionary(grouping: chats) { session -> String in
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            if Calendar.current.isDateInToday(session.createdAt) { return "今天" }
            if Calendar.current.isDateInYesterday(session.createdAt) { return "昨天" }
            if Calendar.current.isDate(session.createdAt, equalTo: Date(), toGranularity: .weekOfYear) { return "本周" }
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: session.createdAt)
        }
        sections = grouped.map { (title: $0.key, items: $0.value) }
            .sorted { $0.items.first?.createdAt ?? Date() > $1.items.first?.createdAt ?? Date() }
    }

    @objc func createNew() {
        onCreate?()
        dismiss(animated: true)
    }
}

extension ChatHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].items.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let session = sections[indexPath.section].items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = session.title
        config.secondaryText = DateFormatter.localizedString(from: session.createdAt, dateStyle: .short, timeStyle: .short)
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(sections[indexPath.section].items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let session = sections[indexPath.section].items[indexPath.row]
            onDelete?(session)
            sections[indexPath.section].items.remove(at: indexPath.row)
            if sections[indexPath.section].items.isEmpty { sections.remove(at: indexPath.section) }
            tableView.reloadData()
        }
    }
}
