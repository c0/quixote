import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ExportViewModel: ObservableObject {
    // MARK: - Export

    func export(
        table: ParsedTable,
        results: [String: PromptResult],
        resultColumns: [ResultsViewModel.ResultColumn],
        suggestedName: String
    ) {
        let csv = buildCSV(
            table: table,
            results: results,
            resultColumns: resultColumns
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedFilename(for: suggestedName)
        panel.prompt = "Save"
        panel.message = "Save results as CSV"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        write(csv: csv, to: url)
    }

    // MARK: - CSV building

    private func buildCSV(
        table: ParsedTable,
        results: [String: PromptResult],
        resultColumns: [ResultsViewModel.ResultColumn]
    ) -> String {
        var headerFields = table.columns.map { $0.name }
        for col in resultColumns {
            headerFields += [
                "\(col.header) — Output",
                "\(col.header) — Duration ms",
                "\(col.header) — Tokens",
                "\(col.header) — Cosine Similarity",
            ]
        }
        var lines = [headerFields.map(escape).joined(separator: ",")]

        // Rows — preserve original order
        for row in table.rows {
            var fields = table.columns.map { row.values[$0.name] ?? "" }

            for col in resultColumns {
                let key = "\(col.promptID.uuidString)-\(row.id.uuidString)-\(col.modelConfigID.uuidString)"
                if let r = results[key], r.modelConfigID == col.modelConfigID, r.status == .completed {
                    fields.append(r.responseText ?? "")
                    fields.append(r.durationMs.map(String.init) ?? "")
                    fields.append(r.tokenUsage.map { String($0.total) } ?? "")
                    fields.append(r.cosineSimilarity.map { String(format: "%.6f", $0) } ?? "")
                } else {
                    fields += ["", "", "", ""]
                }
            }

            lines.append(fields.map(escape).joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - RFC-4180 field escaping

    private func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"")
            || value.contains("\n") || value.contains("\r")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func suggestedFilename(for suggestedName: String) -> String {
        let trimmed = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "export.csv" }
        let ext = URL(fileURLWithPath: trimmed).pathExtension
        if ext.caseInsensitiveCompare("csv") == .orderedSame {
            return trimmed
        }
        let base = URL(fileURLWithPath: trimmed).deletingPathExtension().lastPathComponent
        return "\(base).csv"
    }

    private func write(csv: String, to url: URL) {
        let destinationURL: URL
        if url.pathExtension.isEmpty {
            destinationURL = url.appendingPathExtension(for: .commaSeparatedText)
        } else {
            destinationURL = url
        }

        do {
            try csv.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }
}
