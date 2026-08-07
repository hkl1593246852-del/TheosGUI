// MARK: - Models.swift
// TheosGUI Clone — 所有数据模型

import Foundation

// ======================================================================
// MARK: - FileItem
// ======================================================================
struct FileItem: Codable {
    let name: String
    let path: String
    var isDirectory: Bool
    var size: UInt64
    var modificationDate: Date
    var isHidden: Bool
    var fileType: String

    init(name: String, path: String, isDirectory: Bool, size: UInt64, modificationDate: Date, isHidden: Bool, fileType: String) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
        self.isHidden = isHidden
        self.fileType = fileType
    }
}

// ======================================================================
// MARK: - ChatMessage
// ======================================================================
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var segments: [MessageSegment]?

    init(role: MessageRole, content: String, timestamp: Date = Date(), segments: [MessageSegment]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.segments = segments
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct MessageSegment: Codable {
    enum SegmentType: String, Codable {
        case text
        case code
        case image
        case file
    }
    let type: SegmentType
    let content: String
    let language: String?
    let path: String?

    init(type: SegmentType, content: String, language: String? = nil, path: String? = nil) {
        self.type = type
        self.content = content
        self.language = language
        self.path = path
    }
}

// ======================================================================
// MARK: - ChatSession
// ======================================================================
struct ChatSession: Codable, Identifiable {
    let id: String
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date

    init(id: String = UUID().uuidString, title: String, messages: [ChatMessage] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
    }
}

// ======================================================================
// MARK: - ChatContext
// ======================================================================
struct ChatContext: Codable {
    let title: String
    let content: String
    let path: String?
    let type: String
}

// ======================================================================
// MARK: - ChatProviderSettings
// ======================================================================
struct ChatProviderSettings: Codable {
    var name: String
    var baseURL: String
    var apiKey: String
    var model: String
    var stream: Bool
    var confirmExec: Bool
    var confirmRead: Bool
    var confirmWrite: Bool
    var systemPrompt: String

    static var `default`: ChatProviderSettings {
        ChatProviderSettings(
            name: "OpenAI",
            baseURL: "https://api.openai.com",
            apiKey: "",
            model: "gpt-4",
            stream: true,
            confirmExec: true,
            confirmRead: true,
            confirmWrite: true,
            systemPrompt: ""
        )
    }
}

// ======================================================================
// MARK: - CompilationResult
// ======================================================================
struct CompilationResult {
    let success: Bool
    let output: String
    let error: String?
    let exitCode: Int32
    let duration: TimeInterval
}
