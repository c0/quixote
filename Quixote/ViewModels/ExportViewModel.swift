import Foundation
import AppKit

@MainActor
final class ExportViewModel: ObservableObject {
    // MARK: - Export

    func export(
        table: ParsedTable,
        results: [UUID: PromptResult],
        resultColumns: [ResultsViewModel.ResultColumn],
        prompt: Prompt?,
        model: ModelConfig?,
        suggestedName: String
    ) {
        let csv = buildCSV(
            table: table,
            results: results,
            resultColumns: resultColumns,
            prompt: prompt,
            model: model
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName.isEmpty
            ? "export_enriched.csv"
            : "\(suggestedName)_enriched.csv"
        panel.prompt = "Export"
        panel.message = "Save enriched CSV"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Surface via alert in a future pass; for now silently fail
        }
    }

    // MARK: - CSV building

    private func buildCSV(
        table: ParsedTable,
        results: [UUID: PromptResult],
        resultColumns: [ResultsViewModel.ResultColumn],
        prompt: Prompt?,
        model: ModelConfig?
    ) -> String {
        let promptName = prompt?.name ?? "Prompt"

        // Header — spec §14.2: "{Prompt Name} — Output ({model-id})"
        var headerFields = table.columns.map { $0.name }
        for col in resultColumns {
            headerFields += [
                "\(promptName) — Output (\(col.modelID))",
                "\(promptName) — Duration ms (\(col.modelID))",
                "\(promptName) — Tokens (\(col.modelID))",
            ]
        }
        var lines = [headerFields.map(escape).joined(separator: ",")]

        // Rows — preserve original order
        for row in table.rows {
            var fields = table.columns.map { row.values[$0.name] ?? "" }

            for col in resultColumns {
                // Match on col.modelID, not an outer variable
                if let r = results[row.id], r.modelID == col.modelID, r.status == .completed {
                    fields.append(r.responseText ?? "")
                    fields.append(r.durationMs.map(String.init) ?? "")
                    fields.append(r.tokenUsage.map { String($0.total) } ?? "")
                } else {
                    fields += ["", "", ""]
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
}
