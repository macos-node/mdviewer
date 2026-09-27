import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let bodyHTML: String
    let title: String
    let baseDirectory: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(context.coordinator.fileHandler, forURLScheme: LocalFileSchemeHandler.scheme)
        // Markdown can embed raw HTML; never run scripts from documents.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        // The app's own scripts run in an isolated world, unaffected by the setting above.
        let contentController = configuration.userContentController
        for script in [Self.bundledScript("highlight.min"), Self.bundledScript("viewer")] {
            contentController.addUserScript(WKUserScript(
                source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        }
        contentController.add(context.coordinator, contentWorld: .defaultClient, name: "copyCode")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true

        // Nothing is shown until the offline rules are installed (fails closed).
        OfflineRules.load { rules in
            if let rules {
                contentController.add(rules)
                context.coordinator.rulesInstalled = true
                context.coordinator.pendingLoad?()
            } else {
                webView.loadHTMLString("<p style='font: 13px -apple-system; padding: 20px'>Couldn’t enable offline protection, so the document wasn’t displayed.</p>", baseURL: nil)
            }
            context.coordinator.pendingLoad = nil
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.loadedBody != bodyHTML || coordinator.fileHandler.rootDirectory != baseDirectory else { return }
        let canUpdateInPlace = coordinator.isLoaded && coordinator.fileHandler.rootDirectory == baseDirectory
        coordinator.loadedBody = bodyHTML
        coordinator.fileHandler.rootDirectory = baseDirectory

        let page = MarkdownRenderer.page(body: bodyHTML, title: title)
        let baseURL = LocalFileSchemeHandler.baseURL(for: baseDirectory)
        let loadPage = {
            coordinator.isLoaded = false
            webView.loadHTMLString(page, baseURL: baseURL)
        }

        guard coordinator.rulesInstalled else {
            coordinator.pendingLoad = { _ = loadPage() }
            return
        }
        guard canUpdateInPlace else { return loadPage() }
        // Swap the content without reloading, so the scroll position is kept and nothing flashes.
        webView.callAsyncJavaScript("mdviewer.update(html)", arguments: ["html": bodyHTML], in: nil, in: .defaultClient) { result in
            if case .failure = result { loadPage() }
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    private static func bundledScript(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let fileHandler = LocalFileSchemeHandler()
        var loadedBody: String?
        var isLoaded = false
        var rulesInstalled = false
        var pendingLoad: (() -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "copyCode", let code = message.body as? String else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = action.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Navigation the document starts on its own (meta refresh, frames, etc.) may only
            // load local content; the reader never touches the network.
            guard action.navigationType == .linkActivated else {
                let isLocal = url.scheme == LocalFileSchemeHandler.scheme || url.scheme == "about"
                decisionHandler(isLocal ? .allow : .cancel)
                return
            }

            // In-page anchors (#section) scroll within the document.
            if url.fragment != nil, url.withoutFragment == webView.url?.withoutFragment {
                decisionHandler(.allow)
                return
            }

            // Links the user clicks open in their default app (e.g. the browser), not in the reader.
            decisionHandler(.cancel)
            if let fileURL = LocalFileSchemeHandler.fileURL(for: url) {
                NSWorkspace.shared.open(fileURL)
            } else if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

/// WebKit content-blocking rules that block every load except local content, so documents
/// can never reach the network (even though the app itself may check GitHub for updates).
enum OfflineRules {
    private static let rules = """
    [
      { "trigger": { "url-filter": ".*" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "^\(LocalFileSchemeHandler.scheme):" }, "action": { "type": "ignore-previous-rules" } },
      { "trigger": { "url-filter": "^data:" }, "action": { "type": "ignore-previous-rules" } },
      { "trigger": { "url-filter": "^about:" }, "action": { "type": "ignore-previous-rules" } }
    ]
    """
    private static var cached: WKContentRuleList?

    static func load(_ completion: @escaping (WKContentRuleList?) -> Void) {
        if let cached { return completion(cached) }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "mdviewer-offline", encodedContentRuleList: rules) { list, _ in
            cached = list
            completion(list)
        }
    }
}

private extension URL {
    var withoutFragment: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url
    }
}
