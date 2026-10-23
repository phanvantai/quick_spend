import Testing
import Foundation
@testable import QuickSpend

/// Release builds must not print what the user said, notes, or amounts to the
/// device console. Scans the app sources for `print(` calls that interpolate
/// user content outside an `#if DEBUG` block (previews are skipped: they never
/// run in the app).
@Suite("Release logging")
struct ReleaseLoggingTests {

    /// Interpolated names that hold user content. `.count` of them is fine.
    private static let sensitiveNames = [
        "text", "inputText", "trimmed", "transcription", "rawInput",
        "words", "note", "amount", "title",
    ]

    private static let sourceRoots = ["QuickSpend", "Shared", "QuickSpendWidgets"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("No user content is printed outside #if DEBUG")
    func noUserContentInReleasePrints() throws {
        let files = try Self.sourceRoots.flatMap { try swiftFiles(in: Self.repoRoot.appendingPathComponent($0)) }
        #expect(files.count > 50, "Source scan found too few files; is the repo root right?")

        var leaks: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (line, number) in releasePrintLines(in: source) where interpolations(in: line).contains(where: isSensitive) {
                leaks.append("\(file.lastPathComponent):\(number): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(leaks.isEmpty, "Wrap these in #if DEBUG:\n\(leaks.joined(separator: "\n"))")
    }

    @Test("The scanner flags user content and allows counts")
    func scannerRules() {
        #expect(isSensitive("trimmed"))
        #expect(isSensitive("transaction.note"))
        #expect(isSensitive("String(describing: item[\"amount\"])"))
        #expect(isSensitive("words[0]"))
        #expect(!isSensitive("trimmed.count"))
        #expect(!isSensitive("results.count"))
        #expect(!isSensitive("error"))
    }

    @Test("The scanner skips #if DEBUG blocks and previews")
    func scannerSkipsDebugAndPreviews() {
        let source = """
        print("a \\(text)")
        #if DEBUG
        print("b \\(text)")
        #else
        print("c \\(text)")
        #endif
        #Preview {
            Form { print("d \\(text)") }
        }
        print("e \\(text)")
        """
        let lines = releasePrintLines(in: source).map(\.1)
        #expect(lines == [1, 5, 10])
    }

    // MARK: - Scanner

    private func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// `print(` lines (with 1-based line numbers) that compile into Release.
    private func releasePrintLines(in source: String) -> [(String, Int)] {
        var debugStack: [Bool] = []
        var previewDepth = 0
        var result: [(String, Int)] = []

        for (index, line) in source.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let braces = line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count

            if previewDepth > 0 {
                previewDepth += braces
                continue
            }
            if trimmed.hasPrefix("#Preview") {
                previewDepth = max(braces, 0)
                continue
            }
            if trimmed.hasPrefix("#if") {
                debugStack.append(trimmed == "#if DEBUG")
            } else if trimmed.hasPrefix("#else") || trimmed.hasPrefix("#elseif") {
                if !debugStack.isEmpty { debugStack[debugStack.count - 1] = false }
            } else if trimmed.hasPrefix("#endif") {
                _ = debugStack.popLast()
            } else if !debugStack.contains(true), trimmed.contains("print(") {
                result.append((line, index + 1))
            }
        }
        return result
    }

    /// The contents of each `\( … )` in a line, with nested parentheses kept.
    private func interpolations(in line: String) -> [String] {
        var results: [String] = []
        var index = line.startIndex
        while let start = line.range(of: "\\(", range: index..<line.endIndex) {
            var depth = 1
            var cursor = start.upperBound
            while cursor < line.endIndex, depth > 0 {
                if line[cursor] == "(" { depth += 1 }
                if line[cursor] == ")" { depth -= 1 }
                if depth > 0 { cursor = line.index(after: cursor) }
            }
            results.append(String(line[start.upperBound..<cursor]))
            index = cursor < line.endIndex ? line.index(after: cursor) : line.endIndex
        }
        return results
    }

    private func isSensitive(_ expression: String) -> Bool {
        if expression.hasSuffix(".count") { return false }
        let identifiers = expression
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
            .filter { !$0.isEmpty }
        return identifiers.contains { Self.sensitiveNames.contains($0) }
    }
}
