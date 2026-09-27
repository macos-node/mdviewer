import Foundation
import cmark_gfm
import cmark_gfm_extensions

enum MarkdownRenderer {
    /// Renders GitHub-flavored Markdown to an HTML fragment.
    static func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        // Raw HTML is passed through; the web view disables document JavaScript, and the CSP
        // plus the web view's content-blocking rules prevent any network access.
        let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_SMART
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in ["table", "strikethrough", "autolink", "tasklist", "tagfilter"] {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        guard let cString = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(cString) }
        return addHeadingIDs(to: String(cString: cString))
    }

    /// Wraps a rendered HTML fragment in a complete, styled page.
    static func page(body: String, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="x-dns-prefetch-control" content="off">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src \(LocalFileSchemeHandler.scheme): data:; media-src \(LocalFileSchemeHandler.scheme):; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <title>\(escape(title))</title>
        <style>\(stylesheet)</style>
        </head>
        <body><article class="markdown-body">
        \(body)
        </article></body>
        </html>
        """
    }

    private static let stylesheet: String = {
        func load(_ name: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: "css") else { return "" }
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        // Syntax themes: GitHub light, and GitHub dark in dark mode. The base stylesheet comes last to win.
        return load("hl-light")
            + "\n@media (prefers-color-scheme: dark) {\n" + load("hl-dark") + "\n}\n"
            + load("style")
    }()

    // MARK: Heading anchors

    private static let headingPattern = try! NSRegularExpression(pattern: "<h([1-6])>(.*?)</h\\1>")
    private static let tagPattern = try! NSRegularExpression(pattern: "<[^>]+>")

    /// Adds GitHub-style `id`s to headings so `[link](#section-name)` anchors work.
    private static func addHeadingIDs(to html: String) -> String {
        let source = html as NSString
        var result = ""
        var cursor = 0
        var used: [String: Int] = [:]

        for match in headingPattern.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let level = source.substring(with: match.range(at: 1))
            let inner = source.substring(with: match.range(at: 2))

            var slug = slugify(inner)
            if let count = used[slug] {
                used[slug] = count + 1
                slug += "-\(count)"
            } else {
                used[slug] = 1
            }

            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += "<h\(level) id=\"\(slug)\">\(inner)</h\(level)>"
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    private static func slugify(_ headingHTML: String) -> String {
        let text = tagPattern.stringByReplacingMatches(
            in: headingHTML, range: NSRange(location: 0, length: (headingHTML as NSString).length), withTemplate: "")
        let decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return decoded.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "_" }
            .replacingOccurrences(of: " ", with: "-")
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
