// MARK: - TGArchiveManager.swift
// TheosGUI Clone — 压缩/解压管理

import Foundation
import Compression

class TGArchiveManager {

    enum ArchiveFormat: String {
        case zip, tar, gz, bz2, xz, sevenZ = "7z"
    }

    enum ArchiveError: Error {
        case compressionFailed
        case decompressionFailed
        case invalidPath
        case passwordRequired
    }

    typealias ProgressHandler = (Double) -> Void
    typealias CompletionHandler = (Result<String, Error>) -> Void

    // MARK: - Compress
    class func compressFiles(_ paths: [String],
                             toPath dest: String,
                             format: String,
                             password: String? = nil,
                             progress: ProgressHandler? = nil,
                             completion: @escaping CompletionHandler) {
        DispatchQueue.global().async {
            // 使用 Process 调用系统命令
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

            var args = ["-r", dest]
            if let password = password, !password.isEmpty {
                args.insert("-P", at: 0)
                args.insert(password, at: 1)
            }
            args.append(contentsOf: paths)

            task.arguments = args

            let pipe = Pipe()
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    DispatchQueue.main.async { completion(.success(dest)) }
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        completion(.failure(ArchiveError.compressionFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Decompress
    class func decompressFile(_ path: String,
                              toPath dest: String,
                              password: String? = nil,
                              progress: ProgressHandler? = nil,
                              completion: @escaping CompletionHandler) {
        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            task.currentDirectoryURL = URL(fileURLWithPath: dest)

            var args = ["-o", path]
            if let password = password, !password.isEmpty {
                args.insert("-P", at: 0)
                args.insert(password, at: 1)
            }

            task.arguments = args
            let pipe = Pipe()
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 {
                    DispatchQueue.main.async { completion(.success(dest)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(ArchiveError.decompressionFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Streaming Unzip (from StreamingUnzipper)
    class func streamingUnzip(_ path: String,
                              toPath dest: String,
                              progress: @escaping ProgressHandler,
                              completion: @escaping CompletionHandler) {
        // 流式解压 - 大文件友好
        decompressFile(path, toPath: dest, progress: progress, completion: completion)
    }
}
