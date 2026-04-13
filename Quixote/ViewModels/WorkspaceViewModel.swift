import Foundation
import AppKit
import Combine
import CryptoKit
import UniformTypeIdentifiers

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var files: [WorkspaceFile] = []
    @Published var selectedFileID: UUID? = nil
    @Published private(set) var changedFiles: [WorkspaceFile] = []

    var selectedFile: WorkspaceFile? {
        files.first { $0.id == selectedFileID }
    }

    // Parser registry — add new parsers here as they are implemented
    private let parsers: [any FileParser] = [CSVParser(), JSONParser(), ExcelParser()]

    // MARK: - Persistence

    private let persistenceURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspace.json")
    }()

    private var parsedTables: [UUID: ParsedTable] = [:]

    init() {
        loadWorkspace()
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
        // Prevent duplicates
        guard !files.contains(where: { $0.url == url }) else {
            selectedFileID = files.first(where: { $0.url == url })?.id
            return
        }

        guard let parser = parser(for: url) else { return }

        var file = WorkspaceFile(url: url)
        do {
            let table = try parser.parse(url: url)
            file.contentHash = contentHash(of: url)
            parsedTables[file.id] = table
        } catch {
            // Still add the file — user can see it's unreadable
        }

        files.append(file)
        selectedFileID = file.id
        saveWorkspace()
    }

    var onFileRemoved: ((WorkspaceFile) -> Void)?

    func removeFile(_ file: WorkspaceFile) {
        parsedTables.removeValue(forKey: file.id)
        files.removeAll { $0.id == file.id }
        if selectedFileID == file.id {
            selectedFileID = files.first?.id
        }
        saveWorkspace()
        onFileRemoved?(file)
    }

    func parsedTable(for file: WorkspaceFile) -> ParsedTable {
        parsedTables[file.id] ?? .empty
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

    // MARK: - Persistence (simple JSON)

    private func saveWorkspace() {
        let data = try? JSONEncoder().encode(files)
        try? data?.write(to: persistenceURL, options: .atomic)
    }

    private func loadWorkspace() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let saved = try? JSONDecoder().decode([WorkspaceFile].self, from: data)
        else { return }

        var live: [WorkspaceFile] = []
        var detected: [WorkspaceFile] = []

        for var file in saved {
            guard FileManager.default.fileExists(atPath: file.url.path) else { continue }
            guard let parser = parser(for: file.url),
                  let table = try? parser.parse(url: file.url)
            else { continue }

            let currentHash = contentHash(of: file.url)

            if !file.contentHash.isEmpty && file.contentHash != currentHash {
                // File changed since last save — keep old hash, record as changed
                detected.append(file)
            } else {
                // First open (empty hash) or unchanged — update to current hash
                file.contentHash = currentHash
            }

            parsedTables[file.id] = table
            live.append(file)
        }

        files = live
        changedFiles = detected
        selectedFileID = live.first?.id
    }

    /// Clears the changed-files list after the user has been notified.
    func acknowledgeChanges() {
        changedFiles = []
    }

    /// Advances stored content hashes to the current on-disk values.
    /// Call this after the user confirms they want to re-run on changed data.
    func refreshContentHashes() {
        for i in files.indices {
            let current = contentHash(of: files[i].url)
            if !current.isEmpty {
                files[i].contentHash = current
            }
        }
        saveWorkspace()
    }
}
