// MARK: - Helpers.swift
// TheosGUI Clone — 全局工具函数

import Foundation
import UIKit

/// 格式化文件大小
func formatSize(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

/// 获取文件详细类型描述
func detectFileType(_ path: String) -> String {
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
        "log": "Log File", "sqlite": "SQLite DB", "db": "Database",
    ]
    return types[ext] ?? ext.uppercased()
}

/// 获取进程列表 (越狱设备)
func getProcessList() -> [(pid: Int32, name: String)] {
    var processes: [(pid: Int32, name: String)] = []
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    var size: Int = 0

    if sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) != 0 { return processes }

    let count = size / MemoryLayout<kinfo_proc>.size
    var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)

    if sysctl(&mib, UInt32(mib.count), &procs, &size, nil, 0) != 0 { return processes }

    for proc in procs {
        let pid = proc.kp_proc.p_pid
        let name = withUnsafePointer(to: proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                String(cString: $0)
            }
        }
        if pid > 0 { processes.append((pid: pid, name: name)) }
    }
    return processes.sorted { $0.name < $1.name }
}

/// 简单的代码语法高亮
func highlightSyntax(_ source: String, fileExtension: String) -> NSAttributedString {
    let attr = NSMutableAttributedString(string: source)
    let fullRange = NSRange(location: 0, length: attr.length)
    attr.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
    attr.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

    let patterns: [(String, UIColor)] = [
        ("//.*", .systemGray),
        ("/\\*[\\s\\S]*?\\*/", .systemGray),
        ("@interface|@implementation|@protocol|@property|@end|@synthesize|@dynamic", .systemPurple),
        ("#import|#include|#define|#ifdef|#ifndef|#endif|#pragma|#error", .systemOrange),
        ("@\"[^\"]*\"", .systemRed),
        ("\"[^\"]*\"", .systemRed),
        ("\\b(void|int|char|float|double|long|short|BOOL|id|instancetype|SEL|Class|IMP|NSInteger|NSUInteger|CGFloat|bool)\\b", .systemBlue),
        ("\\b(if|else|for|while|do|switch|case|break|continue|return|typedef|struct|enum|static|extern|const|sizeof)\\b", .systemTeal),
        ("\\b(%hook|%end|%orig|%log|%new|%ctor|%dtor|%group|%init)\\b", .systemPink),
    ]

    for (pattern, color) in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            for match in regex.matches(in: source, range: fullRange) {
                attr.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
    }
    return attr
}

/// 判断是否为二进制文件
func isBinaryFile(_ path: String) -> Bool {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]) else { return false }
    let magic = data.prefix(4)
    // Mach-O magic numbers
    let machoMagics: [[UInt8]] = [
        [0xCF, 0xFA, 0xED, 0xFE], // 64-bit LE
        [0xCE, 0xFA, 0xED, 0xFE], // 32-bit LE
        [0xFE, 0xED, 0xFA, 0xCF], // 64-bit BE
        [0xFE, 0xED, 0xFA, 0xCE], // 32-bit BE
        [0xCA, 0xFE, 0xBA, 0xBE], // Universal binary
    ]
    return machoMagics.contains { $0.elementsEqual(magic) }
}

// Required for Process listing
#if os(iOS)
import Darwin
#endif
