import SwiftUI

@main
struct MDViewerApp: App {
    var body: some Scene {
        // Read-only for now. To add editing later, switch to
        // `DocumentGroup(newDocument: MarkdownDocument())` and pass `file.$document`.
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await UpdateChecker.checkForUpdates() }
                }
            }
            ReloadCommands()
        }
    }
}

struct ReloadCommands: Commands {
    @FocusedValue(\.reloadDocument) private var reloadDocument

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Reload") { reloadDocument?() }
                .keyboardShortcut("r")
                .disabled(reloadDocument == nil)
            Divider()
        }
    }
}

struct ReloadAction {
    let perform: () -> Void
    func callAsFunction() { perform() }
}

extension FocusedValues {
    @Entry var reloadDocument: ReloadAction?
}
