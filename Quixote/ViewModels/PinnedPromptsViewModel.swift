import Foundation

@MainActor
final class PinnedPromptsViewModel: ObservableObject {
    @Published private(set) var prompts: [PinnedPrompt] = []

    private let promptsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Quixote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pinned-prompts.json")
    }()

    private var saveTask: Task<Void, Never>?

    init() {
        load()
    }

    func addPrompt(name: String = "New prompt", systemMessage: String = "", template: String = "") -> UUID {
        let prompt = PinnedPrompt(name: normalizedName(name), systemMessage: systemMessage, template: template)
        prompts.append(prompt)
        save()
        return prompt.id
    }

    func update(_ prompt: PinnedPrompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        var updated = prompt
        updated.name = normalizedName(updated.name)
        updated.updatedAt = Date()
        prompts[index] = updated
        save()
    }

    func rename(id: UUID, name: String) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].name = normalizedName(name)
        prompts[index].updatedAt = Date()
        save()
    }

    func delete(id: UUID) {
        prompts.removeAll { $0.id == id }
        save()
    }

    func duplicate(id: UUID) -> UUID? {
        guard let prompt = prompt(for: id) else { return nil }
        var copy = PinnedPrompt(
            name: "\(prompt.name) copy",
            systemMessage: prompt.systemMessage,
            template: prompt.template
        )
        copy.updatedAt = copy.createdAt
        prompts.append(copy)
        save()
        return copy.id
    }

    func prompt(for id: UUID) -> PinnedPrompt? {
        prompts.first { $0.id == id }
    }

    private func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New prompt" : trimmed
    }

    private func save() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        let data = try? JSONEncoder().encode(prompts)
        try? data?.write(to: promptsURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: promptsURL) else {
            prompts = Self.defaultPrompts
            persist()
            return
        }
        prompts = (try? JSONDecoder().decode([PinnedPrompt].self, from: data)) ?? Self.defaultPrompts
    }

    private static let defaultPrompts: [PinnedPrompt] = [
        PinnedPrompt(
            name: "Summarize",
            systemMessage: "You are a concise summarizer. No preamble, no apology.",
            template: "Summarize the following in 3 bullet points:\n{{text}}"
        ),
        PinnedPrompt(
            name: "Classify sentiment",
            systemMessage: "Reply with one label and nothing else.",
            template: "Classify sentiment as: positive, neutral, negative.\n\n{{text}}"
        ),
        PinnedPrompt(
            name: "Extract entities",
            systemMessage: "Return JSON only.",
            template: "Extract entities as JSON array of {name, type}.\n\n{{text}}"
        ),
        PinnedPrompt(
            name: "Translate to English",
            systemMessage: "Translate faithfully. Preserve tone. Return only the translation.",
            template: "Translate to English:\n\n{{text}}"
        )
    ]
}
