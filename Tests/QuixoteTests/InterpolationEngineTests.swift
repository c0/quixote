import Testing
@testable import Quixote

struct InterpolationEngineTests {
    @Test
    func tokensTrimWhitespaceAndPreserveFirstSeenOrder() {
        let tokens = InterpolationEngine.tokens(
            in: "A {{ title }} B {{body}} C {{ title}} D {{ missing_value }}"
        )

        #expect(tokens == ["title", "body", "missing_value"])
    }

    @Test
    func expandReplacesKnownTokensAndLeavesUnknownTokensVisible() {
        let title = ColumnDef(name: "title", index: 0)
        let body = ColumnDef(name: "body", index: 1)
        let row = Row(index: 0, values: [
            "title": "One Hundred Years",
            "body": "Many years later"
        ])

        let expanded = InterpolationEngine.expand(
            template: "{{ title }}\n{{body}}\n{{unknown}}",
            row: row,
            columns: [title, body]
        )

        #expect(expanded.contains("One Hundred Years"))
        #expect(expanded.contains("Many years later"))
        #expect(expanded.contains("{{unknown}}"))
        #expect(expanded.contains("---\ntitle: One Hundred Years\nbody: Many years later\n"))
    }

    @Test
    func systemMessageExpansionUsesSameWhitespaceTokenSyntax() {
        let tone = ColumnDef(name: "tone", index: 0)
        let row = Row(index: 0, values: ["tone": "concise"])

        let expanded = InterpolationEngine.expandSystemMessage(
            "Reply in a {{ tone }} style.",
            row: row,
            columns: [tone]
        )

        #expect(expanded == "Reply in a concise style.")
    }

    @Test
    func missingTokensReportsTokensWithoutMatchingColumns() {
        let columns = [
            ColumnDef(name: "title", index: 0),
            ColumnDef(name: "body", index: 1)
        ]

        let missing = InterpolationEngine.missingTokens(
            in: ["title", "sentiment", "body", "summary"],
            columns: columns
        )

        #expect(missing == ["sentiment", "summary"])
    }

    @Test
    func previewReturnsTemplateWhenTableIsEmpty() {
        let preview = InterpolationEngine.preview(template: "{{title}}", table: .empty)

        #expect(preview == "{{title}}")
    }

    @Test
    func expansionAppendsStructuredDataInColumnOrder() {
        let second = ColumnDef(name: "second", index: 1)
        let first = ColumnDef(name: "first", index: 0)
        let row = Row(index: 0, values: ["first": "A", "second": "B"])

        let expanded = InterpolationEngine.expand(
            template: "Values",
            row: row,
            columns: [second, first]
        )

        #expect(expanded.hasSuffix("---\nsecond: B\nfirst: A\n"))
    }

    @Test
    func adjacentTokensExpandIndependently() {
        let first = ColumnDef(name: "first", index: 0)
        let second = ColumnDef(name: "second", index: 1)
        let row = Row(index: 0, values: ["first": "A", "second": "B"])

        let expanded = InterpolationEngine.expand(
            template: "{{ first }}{{second}}",
            row: row,
            columns: [first, second]
        )

        #expect(expanded.hasPrefix("AB\n\n---"))
    }
}
