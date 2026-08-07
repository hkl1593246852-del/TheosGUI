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
            var args = ["-r", dest]
            if let password = password, !password.isEmpty {
                args.insert("-P", at: 0)
                args.insert(password, at: 1)
            }
            args.append(contentsOf: paths)

            let result = spawnCommand("/usr/bin/zip", arguments: args)
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    completion(.success(dest))
                } else {
                    completion(.failure(ArchiveError.compressionFailed))
                }
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
            var args = ["-o", path]
            if let password = password, !password.isEmpty {
                args.insert("-P", at: 0)
                args.insert(password, at: 1)
            }

            let result = spawnCommand("/usr/bin/unzip", arguments: args)
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    completion(.success(dest))
                } else {
                    completion(.failure(ArchiveError.decompressionFailed))
                }
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
