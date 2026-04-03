import XCTest
@testable import JotKit

final class SnippetTests: XCTestCase {
    func test_snippet_defaultLanguage_isBash() {
        let s = Snippet(title: "Hello", code: "echo hi")
        XCTAssertEqual(s.language, "bash")
    }

    func test_snippet_encodeDecode_roundtrip() throws {
        let s = Snippet(id: UUID(), title: "Test", code: "ls -lah", language: "bash")
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(decoded.id, s.id)
        XCTAssertEqual(decoded.title, s.title)
        XCTAssertEqual(decoded.code, s.code)
        XCTAssertEqual(decoded.language, s.language)
    }

    func test_snippet_generatesUniqueIDs() {
        let a = Snippet(title: "A", code: "a")
        let b = Snippet(title: "B", code: "b")
        XCTAssertNotEqual(a.id, b.id)
    }
}
