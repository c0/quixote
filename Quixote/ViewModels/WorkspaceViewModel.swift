import Foundation
import AppKit
import Combine
import CryptoKit
import UniformTypeIdentifiers

@MainActor
final class WorkspaceViewModel: ObservableObject {
    private enum RestoreAccessResult {
        case resolved(URL)
        case bookmarkMissing
        case bookmarkResolutionFailed
        case accessDenied
        case missing
    }

    struct PersistedWorkspaceStore: Codable {
        let version: Int
        var entries: [PersistedWorkspaceEntry]
        var selectedFileID: UUID?
    }

    struct PersistedWorkspaceEntry: Codable {
        var id: UUID
        var bookmarkData: Data?
        var fallbackURL: URL
        var displayName: String
        var fileType: FileType
        var addedAt: Date
        var contentHash: String
    }

    @Published private(set) var files: [WorkspaceFile] = []
    @Published var selectedFileID: UUID? = nil {
        didSet {
            guard oldValue != selectedFileID else { return }
            saveWorkspace()
        }
    }
    @Published private(set) var changedFiles: [WorkspaceFile] = []

    var selectedFile: WorkspaceFile? {
        files.first { $0.id == selectedFileID }
    }

    private let parsers: [any FileParser] = [CSVParser(), JSONParser(), ExcelParser()]

    private let persistenceURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspace.json")
    }()

    private var parsedTables: [UUID: ParsedTable] = [:]
    private var bookmarkDataByFileID: [UUID: Data] = [:]
    private var activeSecurityScopedURLs: [UUID: URL] = [:]

    init() {
        loadWorkspace()
    }

    deinit {
        for url in activeSecurityScopedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - File operations

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .json, UTType(filenameExtension: "xlsx")!]
        panel.message = "Open a data file"
        panel.prompt = "Open"

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            addFile(url: url)
        }
    }

    func addFile(url: URL) {
        if let existing = files.first(where: { $0.url == url }) {
            selectedFileID = existing.id
            return
        }

        var file = WorkspaceFile(url: url)
        let accessStarted = startAccessingSecurityScopedURL(url, for: file.id)

        if accessStarted {
            let bookmarkData = createBookmarkData(for: url)
            bookmarkDataByFileID[file.id] = bookmarkData
            if bookmarkData == nil {
                debugLog("bookmark creation failed for \(url.path)")
            }
        } else {
            bookmarkDataByFileID[file.id] = nil
        }

        if accessStarted,
           let parser = parser(for: url),
           let table = try? parser.parse(url: url) {
            file.contentHash = contentHash(of: url)
            file.restoreState = .available
            parsedTables[file.id] = table
        } else if !accessStarted {
            file.restoreState = .accessDenied
        } else {
            file.restoreState = .parseFailed
        }

        files.append(file)
        selectedFileID = file.id
        saveWorkspace()
    }

    var onFileRemoved: ((WorkspaceFile) -> Void)?

    func removeFile(_ file: WorkspaceFile) {
        stopAccessingSecurityScopedURL(for: file.id)
        parsedTables.removeValue(forKey: file.id)
        bookmarkDataByFileID.removeValue(forKey: file.id)
        changedFiles.removeAll { $0.id == file.id }
        files.removeAll { $0.id == file.id }
        if selectedFileID == file.id {
            selectedFileID = files.first(where: \.isAvailable)?.id ?? files.first?.id
        }
        saveWorkspace()
        onFileRemoved?(file)
    }

    func parsedTable(for file: WorkspaceFile) -> ParsedTable {
        guard file.isAvailable else { return .empty }
        return parsedTables[file.id] ?? .empty
    }

    // MARK: - Internal

    private func parser(for url: URL) -> (any FileParser)? {
        let ext = url.pathExtension.lowercased()
        return parsers.first { type(of: $0).supportedExtensions.contains(ext) }
    }

    private func contentHash(of url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func createBookmarkData(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            let nsError = error as NSError
            debugLog("bookmark creation error for \(url.path): \(nsError.domain) \(nsError.code) \(nsError.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    private func startAccessingSecurityScopedURL(_ url: URL, for fileID: UUID) -> Bool {
        stopAccessingSecurityScopedURL(for: fileID)
        let started = url.startAccessingSecurityScopedResource()
        if !started {
            debugLog("startAccessingSecurityScopedResource returned false for \(url.path)")
            return false
        }
        activeSecurityScopedURLs[fileID] = url
        return true
    }

    private func stopAccessingSecurityScopedURL(for fileID: UUID) {
        guard let url = activeSecurityScopedURLs.removeValue(forKey: fileID) else { return }
        url.stopAccessingSecurityScopedResource()
    }

    private func isAppOwnedURL(_ url: URL) -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let ownedRoots = appSupport + caches + [temp]
        let standardizedURL = url.standardizedFileURL
        return ownedRoots.contains { standardizedURL.path.hasPrefix($0.standardizedFileURL.path) }
    }

    // MARK: - Persistence

    private func saveWorkspace() {
        let store = PersistedWorkspaceStore(
            version: 1,
            entries: files.map { file in
                PersistedWorkspaceEntry(
                    id: file.id,
                    bookmarkData: bookmarkDataByFileID[file.id],
                    fallbackURL: file.url,
                    displayName: file.displayName,
                    fileType: file.fileType,
                    addedAt: file.addedAt,
                    contentHash: file.contentHash
                )
            },
            selectedFileID: selectedFileID
        )

        let data = try? JSONEncoder().encode(store)
        try? data?.write(to: persistenceURL, options: .atomic)
    }

    private func loadWorkspace() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }

        let store: PersistedWorkspaceStore
        if let decoded = try? JSONDecoder().decode(PersistedWorkspaceStore.self, from: data) {
            store = decoded
        } else if let legacyFiles = try? JSONDecoder().decode([WorkspaceFile].self, from: data) {
            store = PersistedWorkspaceStore(
                version: 1,
                entries: legacyFiles.map {
                    PersistedWorkspaceEntry(
                        id: $0.id,
                        bookmarkData: createBookmarkData(for: $0.url),
                        fallbackURL: $0.url,
                        displayName: $0.displayName,
                        fileType: $0.fileType,
                        addedAt: $0.addedAt,
                        contentHash: $0.contentHash
                    )
                },
                selectedFileID: legacyFiles.first?.id
            )
        } else {
            return
        }

        var restoredFiles: [WorkspaceFile] = []
        var detectedChangedFiles: [WorkspaceFile] = []

        for entry in store.entries {
            let restored = restoreFile(from: entry)
            if restored.file.isAvailable,
               !restored.didContentChange,
               let table = restored.table {
                parsedTables[restored.file.id] = table
            }
            if restored.didContentChange {
                detectedChangedFiles.append(restored.file)
            }
            if let bookmarkData = entry.bookmarkData {
                bookmarkDataByFileID[entry.id] = bookmarkData
            }
            restoredFiles.append(restored.file)
        }

        files = restoredFiles
        changedFiles = detectedChangedFiles

        let preferredSelection = store.selectedFileID.flatMap { id in
            restoredFiles.contains(where: { $0.id == id }) ? id : nil
        }
        selectedFileID = preferredSelection
            ?? restoredFiles.first(where: \.isAvailable)?.id
            ?? restoredFiles.first?.id

        saveWorkspace()
    }

    private func restoreFile(from entry: PersistedWorkspaceEntry) -> (file: WorkspaceFile, table: ParsedTable?, didContentChange: Bool) {
        var file = WorkspaceFile(
            id: entry.id,
            url: entry.fallbackURL,
            displayName: entry.displayName,
            fileType: entry.fileType,
            addedAt: entry.addedAt,
            contentHash: entry.contentHash,
            restoreState: .available
        )

        switch restoreAccess(for: entry, fileID: entry.id) {
        case .bookmarkMissing:
            file.restoreState = .bookmarkMissing
            return (file, nil, false)
        case .bookmarkResolutionFailed:
            file.restoreState = .bookmarkResolutionFailed
            return (file, nil, false)
        case .accessDenied:
            file.restoreState = .accessDenied
            return (file, nil, false)
        case .missing:
            file.restoreState = .missing
            return (file, nil, false)
        case .resolved(let resolvedURL):
            file.url = resolvedURL
            file.displayName = resolvedURL.deletingPathExtension().lastPathComponent
            file.fileType = FileType.detect(from: resolvedURL)
        }

        let resolvedURL = file.url
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            file.restoreState = .missing
            return (file, nil, false)
        }

        guard let parser = parser(for: resolvedURL) else {
            file.restoreState = .parseFailed
            return (file, nil, false)
        }

        guard let table = try? parser.parse(url: resolvedURL) else {
            file.restoreState = .parseFailed
            return (file, nil, false)
        }

        let currentHash = contentHash(of: resolvedURL)
        let didChange = !entry.contentHash.isEmpty && entry.contentHash != currentHash
        file.contentHash = didChange ? entry.contentHash : currentHash
        file.restoreState = .available
        return (file, table, didChange)
    }

    private func restoreAccess(for entry: PersistedWorkspaceEntry, fileID: UUID) -> RestoreAccessResult {
        guard let bookmarkData = entry.bookmarkData else {
            debugLog("bookmark missing for \(entry.fallbackURL.path)")
            guard isAppOwnedURL(entry.fallbackURL) else { return .bookmarkMissing }
            guard FileManager.default.fileExists(atPath: entry.fallbackURL.path) else { return .missing }
            return .resolved(entry.fallbackURL)
        }

        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            debugLog("bookmark resolution failed for \(entry.fallbackURL.path)")
            return .bookmarkResolutionFailed
        }

        guard startAccessingSecurityScopedURL(resolvedURL, for: fileID) else {
            debugLog("security scope start failed for \(resolvedURL.path)")
            return .accessDenied
        }

        if isStale {
            bookmarkDataByFileID[fileID] = createBookmarkData(for: resolvedURL)
            debugLog("bookmark stale and refreshed for \(resolvedURL.path)")
        }

        return .resolved(resolvedURL)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[WorkspaceBookmarks] \(message)")
        #endif
    }

    /// Clears the changed-files list after the user has been notified.
    func acknowledgeChanges() {
        changedFiles = []
    }

    /// Advances stored content hashes to the current on-disk values.
    /// Call this after the user confirms they want to re-run on changed data.
    func refreshContentHashes() {
        for i in files.indices where files[i].isAvailable {
            let current = contentHash(of: files[i].url)
            if !current.isEmpty {
                files[i].contentHash = current
            }
        }
        saveWorkspace()
    }
}

private extension WorkspaceFile {
    init(
        id: UUID,
        url: URL,
        displayName: String,
        fileType: FileType,
        addedAt: Date,
        contentHash: String,
        restoreState: FileRestoreState
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.fileType = fileType
        self.addedAt = addedAt
        self.contentHash = contentHash
        self.restoreState = restoreState
    }
}
