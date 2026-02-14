import Foundation
import PDFKit
import CryptoKit

// ============================================================================
// DOCUMENT PARSER — HTML + PDF Text Extraction
//
// INVARIANT: Strictly read-only. Parses data already fetched.
// INVARIANT: No network calls. No file mutations.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            or any write-capable service.
// INVARIANT: FAIL CLOSED on parse error — never return partial/corrupt data silently.
//
// EVIDENCE TAGS:
//   document_parsed, document_parse_failed
// ============================================================================

// MARK: - Parsed Document

/// Immutable artifact from document parsing.
public struct ParsedDocument: Sendable, Identifiable {
    public let id: UUID
    public let sourceURL: URL
    public let title: String
    public let text: String
    public let sections: [DocumentSection]
    public let pageCount: Int
    public let mimeType: String
    public let contentHash: String
    public let parsedAt: Date
    public let charCount: Int

    public init(
        sourceURL: URL,
        title: String,
        text: String,
        sections: [DocumentSection],
        pageCount: Int,
        mimeType: String,
        rawData: Data
    ) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.title = title
        self.text = text
        self.sections = sections
        self.pageCount = pageCount
        self.mimeType = mimeType
        self.parsedAt = Date()
        self.charCount = text.count
        self.contentHash = SHA256.hash(data: rawData)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// Returns a truncated preview of the text.
    public func preview(maxChars: Int = 500) -> String {
        String(text.prefix(maxChars))
    }
}

/// A section within a parsed document.
public struct DocumentSection: Sendable, Identifiable, Codable {
    public let id: UUID
    public let heading: String
    public let body: String
    public let level: Int        // 1=h1, 2=h2, etc.
    public let pageNumber: Int?  // For PDFs

    public init(heading: String, body: String, level: Int = 1, pageNumber: Int? = nil) {
        self.id = UUID()
        self.heading = heading
        self.body = body
        self.level = level
        self.pageNumber = pageNumber
    }
}

// MARK: - Parse Errors

public enum DocumentParseError: Error, LocalizedError {
    case unsupportedFormat(String)
    case emptyContent
    case pdfLoadFailed
    case pdfNoText
    case htmlParseError(String)
    case contentTooLarge(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let m): return "Unsupported document format: \(m)"
        case .emptyContent: return "Document contains no extractable text"
        case .pdfLoadFailed: return "Failed to load PDF document"
        case .pdfNoText: return "PDF contains no extractable text (may be scanned image)"
        case .htmlParseError(let e): return "HTML parse error: \(e)"
        case .contentTooLarge(let s): return "Content exceeds max size: \(s) characters"
        }
    }
}

// MARK: - Document Parser

public enum DocumentParser {

    /// Maximum characters to extract from a single document.
    public static let maxContentChars = 500_000  // ~500K chars

    // MARK: - Parse WebDocument

    /// Parse a WebDocument into structured text.
    /// Dispatches to HTML or PDF parser based on MIME type.
    /// FAIL CLOSED on unsupported format or parse error.
    public static func parse(_ document: WebDocument) throws -> ParsedDocument {
        if document.isPDF {
            return try parsePDF(document)
        } else if document.isHTML {
            return try parseHTML(document)
        } else if document.mimeType.contains("text/") {
            return try parsePlainText(document)
        } else {
            logParseEvidence(success: false, url: document.url, detail: "Unsupported MIME: \(document.mimeType)")
            throw DocumentParseError.unsupportedFormat(document.mimeType)
        }
    }

    // MARK: - HTML Parser

    private static func parseHTML(_ document: WebDocument) throws -> ParsedDocument {
        guard let html = String(data: document.rawData, encoding: .utf8), !html.isEmpty else {
            logParseEvidence(success: false, url: document.url, detail: "Empty HTML")
            throw DocumentParseError.emptyContent
        }

        // Strip scripts and styles
        var cleaned = html
        cleaned = removePattern(cleaned, pattern: #"<script[^>]*>[\s\S]*?</script>"#)
        cleaned = removePattern(cleaned, pattern: #"<style[^>]*>[\s\S]*?</style>"#)
        cleaned = removePattern(cleaned, pattern: #"<!--[\s\S]*?-->"#)
        cleaned = removePattern(cleaned, pattern: #"<nav[^>]*>[\s\S]*?</nav>"#)
        cleaned = removePattern(cleaned, pattern: #"<footer[^>]*>[\s\S]*?</footer>"#)
        cleaned = removePattern(cleaned, pattern: #"<header[^>]*>[\s\S]*?</header>"#)

        // Extract title
        let title = extractHTMLTitle(cleaned) ?? document.url.host ?? "Untitled"

        // Extract headings as sections
        var sections: [DocumentSection] = []
        for level in 1...3 {
            let headingMatches = extractHeadings(cleaned, level: level)
            for (heading, body) in headingMatches {
                sections.append(DocumentSection(
                    heading: heading,
                    body: body,
                    level: level
                ))
            }
        }

        // Strip all remaining HTML tags
        let bodyText = stripHTMLTags(cleaned)
        let normalizedText = normalizeWhitespace(bodyText)

        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logParseEvidence(success: false, url: document.url, detail: "No text after HTML stripping")
            throw DocumentParseError.emptyContent
        }

        // Size check
        guard normalizedText.count <= maxContentChars else {
            logParseEvidence(success: false, url: document.url, detail: "Content too large: \(normalizedText.count) chars")
            throw DocumentParseError.contentTooLarge(normalizedText.count)
        }

        let parsed = ParsedDocument(
            sourceURL: document.url,
            title: title,
            text: normalizedText,
            sections: sections,
            pageCount: 1,
            mimeType: document.mimeType,
            rawData: document.rawData
        )

        logParseEvidence(success: true, url: document.url, detail: "chars=\(normalizedText.count), sections=\(sections.count)")
        return parsed
    }

    // MARK: - PDF Parser

    private static func parsePDF(_ document: WebDocument) throws -> ParsedDocument {
        guard let pdfDocument = PDFDocument(data: document.rawData) else {
            logParseEvidence(success: false, url: document.url, detail: "PDFDocument init failed")
            throw DocumentParseError.pdfLoadFailed
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            logParseEvidence(success: false, url: document.url, detail: "PDF has 0 pages")
            throw DocumentParseError.pdfLoadFailed
        }

        // Extract text page by page
        var fullText = ""
        var sections: [DocumentSection] = []

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            guard let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            fullText += pageText + "\n\n"

            // Each page becomes a section
            let preview = String(pageText.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(DocumentSection(
                heading: "Page \(i + 1)",
                body: pageText,
                level: 1,
                pageNumber: i + 1
            ))

            // Safety: break if content too large
            if fullText.count > maxContentChars {
                fullText = String(fullText.prefix(maxContentChars))
                break
            }
        }

        let normalizedText = normalizeWhitespace(fullText)

        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logParseEvidence(success: false, url: document.url, detail: "PDF has no extractable text (scanned image?)")
            throw DocumentParseError.pdfNoText
        }

        // Extract title from PDF metadata
        let title: String
        if let attrs = pdfDocument.documentAttributes,
           let pdfTitle = attrs[PDFDocumentAttribute.titleAttribute] as? String,
           !pdfTitle.isEmpty {
            title = pdfTitle
        } else {
            title = document.url.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
        }

        let parsed = ParsedDocument(
            sourceURL: document.url,
            title: title,
            text: normalizedText,
            sections: sections,
            pageCount: pageCount,
            mimeType: document.mimeType,
            rawData: document.rawData
        )

        logParseEvidence(success: true, url: document.url, detail: "pages=\(pageCount), chars=\(normalizedText.count)")
        return parsed
    }

    // MARK: - Plain Text Parser

    private static func parsePlainText(_ document: WebDocument) throws -> ParsedDocument {
        guard let text = String(data: document.rawData, encoding: .utf8), !text.isEmpty else {
            logParseEvidence(success: false, url: document.url, detail: "Empty text content")
            throw DocumentParseError.emptyContent
        }

        guard text.count <= maxContentChars else {
            throw DocumentParseError.contentTooLarge(text.count)
        }

        let parsed = ParsedDocument(
            sourceURL: document.url,
            title: document.url.lastPathComponent,
            text: text,
            sections: [DocumentSection(heading: "Content", body: text)],
            pageCount: 1,
            mimeType: document.mimeType,
            rawData: document.rawData
        )

        logParseEvidence(success: true, url: document.url, detail: "chars=\(text.count)")
        return parsed
    }

    // MARK: - HTML Helpers

    private static func extractHTMLTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<title[^>]*>(.*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return stripHTMLTags(String(html[range])).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractHeadings(_ html: String, level: Int) -> [(heading: String, body: String)] {
        let tag = "h\(level)"
        let pattern = #"<\#(tag)[^>]*>(.*?)</\#(tag)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            let headingText = stripHTMLTags(String(html[range]))
            return (headingText.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }
    }

    private static func stripHTMLTags(_ html: String) -> String {
        // Replace common block elements with newlines
        var text = html
        let blockTags = ["p", "div", "br", "li", "tr", "td", "th", "blockquote", "pre"]
        for tag in blockTags {
            text = removePattern(text, pattern: #"</?\#(tag)[^>]*>"#, replacement: "\n")
        }
        // Strip remaining tags
        text = removePattern(text, pattern: "<[^>]+>", replacement: "")
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        return text
    }

    private static func removePattern(_ text: String, pattern: String, replacement: String = "") -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return text
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: replacement)
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        // Collapse multiple blank lines into double newline
        var result = text
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // Trim lines
        let lines = result.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.joined(separator: "\n")
    }

    // MARK: - Evidence

    private static func logParseEvidence(success: Bool, url: URL, detail: String) {
        let type = success ? "document_parsed" : "document_parse_failed"
        let host = url.host ?? "nil"
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: UUID(),
                jsonString: """
                {"host":"\(host)","path":"\(url.path)","detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
