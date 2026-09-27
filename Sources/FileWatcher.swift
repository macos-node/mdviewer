import Foundation

/// Calls `onChange` (on the main queue) when the file at `url` is modified.
/// Handles editors that save atomically by replacing the file.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pendingChange: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        startWatching()
    }

    deinit {
        pendingChange?.cancel()
        source?.cancel()
    }

    private func startWatching() {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // File is temporarily missing (mid-save) or was removed; check again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startWatching() }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self, unowned source] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                // The file was replaced; watch the new one at the same path.
                self.source?.cancel()
                self.source = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.startWatching() }
            }
            self.scheduleChange()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    /// Coalesces bursts of events from a single save.
    private func scheduleChange() {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pendingChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
