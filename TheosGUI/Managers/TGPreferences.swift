// MARK: - TGPreferences.swift
// TheosGUI Clone — 基于 plist 的偏好设置管理器

import Foundation

class TGPreferences {
    static let shared = TGPreferences()

    private var preferences: [String: Any] = [:]
    private var plistPath: String = "/var/mobile/Library/Preferences/com.iosbx.theosgui.plist"

    private init() {
        // 尝试加载 plist
        if let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any] {
            preferences = plist
        }

        // 设置默认值
        let defaults: [String: Any] = [
            "theme": "Dark",
            "lang": "中文",
            "zoom_scale": 13,
            "editor_zoom": true,
            "editor_config": false,
            "quick_file_switch": true,
            "console_compile": true,
            "project_config": false,
            "stream_enabled": true,
            "confirm_exec": true,
            "confirm_read": true,
            "confirm_write": true,
            "switcher_reset_interval": 300,
        ]

        for (key, value) in defaults {
            if preferences[key] == nil {
                preferences[key] = value
            }
        }
    }

    // MARK: - Getters
    func bool(forKey key: String) -> Bool {
        return preferences[key] as? Bool ?? false
    }

    func integer(forKey key: String) -> Int {
        return preferences[key] as? Int ?? 0
    }

    func string(forKey key: String) -> String? {
        return preferences[key] as? String
    }

    func object(forKey key: String) -> Any? {
        return preferences[key]
    }

    // MARK: - Setters
    func setBool(_ value: Bool, forKey key: String) {
        preferences[key] = value
        synchronize()
    }

    func setInteger(_ value: Int, forKey key: String) {
        preferences[key] = value
        synchronize()
    }

    func setObject(_ value: Any?, forKey key: String) {
        if let value = value {
            preferences[key] = value
        } else {
            removeObject(forKey: key)
        }
        synchronize()
    }

    func removeObject(forKey key: String) {
        preferences.removeValue(forKey: key)
        synchronize()
    }

    func synchronize() {
        (preferences as NSDictionary).write(toFile: plistPath, atomically: true)
    }

    // 将所有值转为 JSON 用于网络同步
    func dictionaryRepresentation() -> [String: Any] {
        return preferences
    }
}
