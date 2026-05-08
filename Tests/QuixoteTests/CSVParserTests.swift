import Foundation
import Testing
@testable import Quixote

struct CSVParserTests {
    @Test
    func parsesStandardCSVWithHeaderOnFirstLine() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = try makeCSVFile(in: tempDir, contents: """
        title,body
        One,Two
        """)

        let table = try CSVParser().parse(url: url)

        #expect(table.columns.map(\.name) == ["title", "body"])
        #expect(table.rows.count == 1)
        #expect(table.rows[0].values["title"] == "One")
        #expect(table.rows[0].values["body"] == "Two")
    }

    @Test
    func skipsUlineStylePreambleAndParsesOrderRows() throws {
        let csv = "\u{FEFF},,,,,As of Date:  12/15/2023\r\n" +
            "My Order History\r\n" +
            "LOOZIELOO CHILDRENS BOUTIQUE\r\n" +
            "From 12/15/2021 to 12/15/2023\r\n" +
            "Date,Order #,PO #,Category,Model #,Description,Qty,Ext. Price\r\n" +
            "12/9/2023,10061960,LOU,\"Boxes, Corrugated\",S-18337,\"10 x 8 x 6\"\" Lightweight 32 ECT Corrugated Boxes 25/bundle \",100,57\r\n" +
            "12/9/2023,10061960,LOU,Retail Packaging,S-10621,\"Deluxe Gift Boxes - 6 x 6 x 3\"\", White 50/case \",1,103\r\n"
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = try makeCSVFile(in: tempDir, contents: csv)

        let table = try CSVParser().parse(url: url)

        #expect(table.columns.map(\.name) == [
            "Date",
            "Order #",
            "PO #",
            "Category",
            "Model #",
            "Description",
            "Qty",
            "Ext. Price"
        ])
        #expect(table.rows.count == 2)
        #expect(table.rows[0].index == 0)
        #expect(table.rows[0].values["Date"] == "12/9/2023")
        #expect(table.rows[0].values["Order #"] == "10061960")
        #expect(table.rows[0].values["PO #"] == "LOU")
        #expect(table.rows[0].values["Category"] == "Boxes, Corrugated")
        #expect(table.rows[0].values["Model #"] == "S-18337")
        #expect(table.rows[0].values["Description"] == "10 x 8 x 6\" Lightweight 32 ECT Corrugated Boxes 25/bundle ")
        #expect(table.rows[0].values["Qty"] == "100")
        #expect(table.rows[0].values["Ext. Price"] == "57")
        #expect(table.rows[1].values["Description"] == "Deluxe Gift Boxes - 6 x 6 x 3\", White 50/case ")
    }

    private func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func makeCSVFile(in tempDir: URL, contents: String) throws -> URL {
        let url = tempDir.appendingPathComponent("fixture.csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
