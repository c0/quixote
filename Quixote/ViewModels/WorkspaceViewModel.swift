import Foundation
import AppKit
import Combine

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var files: [WorkspaceFile] = []
    @Published var selectedFileID: UUID? = nil

    var selectedFile: WorkspaceFile? {
        files.first { $0.id == selectedFileID }
    }

    // Parser registry — add new parsers here as they are implemented
    private let parsers: [any FileParser] = [CSVParser()]

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
        panel.allowedContentTypes = [.commaSeparatedText, .data]
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

    func removeFile(_ file: WorkspaceFile) {
        parsedTables.removeValue(forKey: file.id)
        files.removeAll { $0.id == file.id }
        if selectedFileID == file.id {
            selectedFileID = files.first?.id
        }
        saveWorkspace()
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
        return String(data.hashValue)
    }

    // MARK: - Persistence (simple JSON)

    private func saveWorkspace() {
        let data = try? JSONEncoder().encode(files)
        try? data?.write(to: persistenceURL, options: .atomic)
    }

    private func loadWorkspace() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let saved = try? JSONDecoder().decode([WorkspaceFile].self, from: data) else { return }

        // Re-parse files that still exist on disk
        var live: [WorkspaceFile] = []
        for var file in saved {
            guard FileManager.default.fileExists(atPath: file.url.path) else { continue }
            if let parser = parser(for: file.url),
               let table = try? parser.parse(url: file.url) {
                file.contentHash = contentHash(of: file.url)
                parsedTables[file.id] = table
                live.append(file)
            }
        }
        files = live
        selectedFileID = live.first?.id
    }
}
