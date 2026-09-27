import AppKit

/// Checks GitHub Releases for a newer version. This is the only network access the app makes,
/// and it only happens when the user chooses "Check for Updates…".
enum UpdateChecker {
    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private static let repository = Bundle.main.object(forInfoDictionaryKey: "MDVUpdateRepository") as? String ?? ""
    private static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    @MainActor
    static func checkForUpdates() async {
        do {
            guard let release = try await latestRelease() else {
                return showAlert("No Releases Found", "There are no published releases of mdviewer yet.")
            }
            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard isVersion(latest, newerThan: currentVersion) else {
                return showAlert("You’re Up to Date", "mdviewer \(currentVersion) is the latest version.")
            }

            let alert = NSAlert()
            alert.messageText = "mdviewer \(latest) Is Available"
            alert.informativeText = "You have version \(currentVersion). Download the new version from GitHub?"
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "Later")
            // Only ever send the user to github.com.
            if alert.runModal() == .alertFirstButtonReturn, release.htmlURL.host == "github.com" {
                NSWorkspace.shared.open(release.htmlURL)
            }
        } catch {
            showAlert("Couldn’t Check for Updates", error.localizedDescription)
        }
    }

    private static func latestRelease() async throws -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)

        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try JSONDecoder().decode(Release.self, from: data)
        case 404: return nil
        default: throw URLError(.badServerResponse)
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    @MainActor
    private static func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
