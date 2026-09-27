import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves files next to the open document (e.g. relative image paths) to the web view.
/// Only files inside `rootDirectory` are readable.
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mdviewer-file"

    var rootDirectory: URL?

    static func baseURL(for directory: URL?) -> URL? {
        guard let directory else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "local"
        components.path = directory.standardizedFileURL.path.hasSuffix("/")
            ? directory.standardizedFileURL.path
            : directory.standardizedFileURL.path + "/"
        return components.url
    }

    static func fileURL(for url: URL) -> URL? {
        guard url.scheme == scheme else { return nil }
        return URL(fileURLWithPath: url.path).standardizedFileURL
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard
            let url = task.request.url,
            let fileURL = Self.fileURL(for: url),
            let root = rootDirectory?.standardizedFileURL.resolvingSymlinksInPath(),
            fileURL.resolvingSymlinksInPath().path.hasPrefix(root.path + "/"),
            let data = try? Data(contentsOf: fileURL)
        else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
