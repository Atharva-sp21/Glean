import Foundation
import PrivateActionCore

// This is the only application component with network capability. It never receives user content.
actor ModelDownloadService {
    let root: URL
    private var busy = false
    init(root: URL) throws { self.root = root; try SecureFiles.directory(root) }
    func directory(_ manifest: ModelManifest) -> URL { root.appendingPathComponent(manifest.directoryName, isDirectory: true) }
    func installed(_ manifest: ModelManifest) -> Bool { FileManager.default.fileExists(atPath: directory(manifest).path) }
    func install(_ manifest: ModelManifest, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !busy else { throw PrivateActionError.busy }; busy = true; defer { busy = false }
        let final = directory(manifest)
        if installed(manifest) { try ModelAssetVerifier.verifyDirectory(final, manifest: manifest); return }
        let staging = root.appendingPathComponent(".download-" + manifest.directoryName, isDirectory: true)
        try SecureFiles.directory(staging)
        // Verified completed files survive cancellation; a retry resumes at the next file.
        var completed: Int64 = 0
        for asset in manifest.files {
            try Task.checkCancellation()
            guard !asset.path.contains("/"), !asset.path.contains(".."), manifest.revision.count == 40,
                  manifest.repo.hasPrefix("mlx-community/") else { throw PrivateActionError.corruptModel }
            let destination = staging.appendingPathComponent(asset.path)
            if (try? ModelAssetVerifier.verify(destination, asset: asset)) == nil {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                let url = URL(string: "https://huggingface.co/\(manifest.repo)/resolve/\(manifest.revision)/\(asset.path)")!
                let base = completed
                let transfer = BoundedModelTransfer(url: url, destination: destination, expectedBytes: asset.size) { bytes in
                    progress(Double(base + bytes) / Double(manifest.totalBytes))
                }
                try await transfer.run()
                try ModelAssetVerifier.verify(destination, asset: asset)
            }
            completed += asset.size; progress(Double(completed) / Double(manifest.totalBytes))
        }
        try ModelAssetVerifier.verifyDirectory(staging, manifest: manifest)
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: staging, to: final)
    }
    func delete(_ manifest: ModelManifest) throws {
        guard !busy else { throw PrivateActionError.busy }
        for path in [directory(manifest), root.appendingPathComponent(".download-" + manifest.directoryName)] where FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
    func storageBytes(_ manifest: ModelManifest) -> Int64 {
        [directory(manifest), root.appendingPathComponent(".download-" + manifest.directoryName)].reduce(0) { total, folder in
            total + manifest.files.reduce(0) { sum, asset in
                sum + ((try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(asset.path).path)[.size] as? NSNumber)?.int64Value ?? 0)
            }
        }
    }
}

private final class BoundedModelTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let url: URL
    private let destination: URL
    private let expectedBytes: Int64
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var cancelled = false
    init(url: URL, destination: URL, expectedBytes: Int64, progress: @escaping @Sendable (Int64) -> Void) {
        self.url = url; self.destination = destination; self.expectedBytes = expectedBytes; self.progress = progress
    }
    func run() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock(); defer { lock.unlock() }
                if cancelled { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
                config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 3600
                config.waitsForConnectivity = false
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                self.session = session
                var request = URLRequest(url: url); request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                task = session.downloadTask(with: request); task?.resume()
            }
        } onCancel: {
            self.lock.lock(); self.cancelled = true; let task = self.task; self.lock.unlock(); task?.cancel()
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let host = request.url?.host?.lowercased() ?? ""
        let allowed = request.url?.scheme == "https" && (host == "huggingface.co" || host.hasSuffix(".huggingface.co") || host.hasSuffix(".hf.co"))
        completionHandler(allowed ? request : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > expectedBytes || (totalBytesExpectedToWrite > 0 && totalBytesExpectedToWrite != expectedBytes) { downloadTask.cancel(); return }
        progress(totalBytesWritten)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else { throw PrivateActionError.corruptModel }
            let size = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value
            guard size == expectedBytes else { throw PrivateActionError.corruptModel }
            try FileManager.default.moveItem(at: location, to: destination); try SecureFiles.protect(destination)
            finish(.success(()))
        } catch { finish(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }
    private func finish(_ result: Result<Void, Error>) {
        lock.lock(); let continuation = self.continuation; self.continuation = nil; let session = self.session; self.session = nil; self.task = nil; lock.unlock()
        session?.invalidateAndCancel(); continuation?.resume(with: result)
    }
}
