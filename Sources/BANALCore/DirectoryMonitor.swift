import CoreServices
import Foundation

/// Observes a vault directory via FSEvents and `NSFilePresenter`.
///
/// External writes from Finder, Vim, or VS Code surface as coalesced URL
/// batches. The monitor does not interpret Markdown; `NoteStore` decides
/// what to reload.
public final class DirectoryMonitor: NSObject, NSFilePresenter, @unchecked Sendable {
    public var presentedItemURL: URL?
    public let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "BANAL.DirectoryMonitor.presenter"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public typealias Handler = @Sendable ([URL]) -> Void

    private let lock = NSLock()
    private var stream: FSEventStreamRef?
    private var handler: Handler?
    private var pending: Set<URL> = []
    private var debounceWork: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let callbackQueue = DispatchQueue(label: "BANAL.DirectoryMonitor")
    private var started = false

    public init(debounceInterval: TimeInterval = 0.15) {
        self.debounceInterval = debounceInterval
        super.init()
    }

    deinit {
        stop()
    }

    public func start(url: URL, handler: @escaping Handler) {
        stop()
        lock.lock()
        self.handler = handler
        presentedItemURL = url
        lock.unlock()

        NSFileCoordinator.addFilePresenter(self)

        let allocator = kCFAllocatorDefault
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = [url.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
        )
        guard let created = FSEventStreamCreate(
            allocator,
            DirectoryMonitor.streamCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            flags
        ) else {
            return
        }
        stream = created
        FSEventStreamSetDispatchQueue(created, callbackQueue)
        FSEventStreamStart(created)
        started = true
    }

    public func stop() {
        if started {
            NSFileCoordinator.removeFilePresenter(self)
            started = false
        }
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        lock.lock()
        debounceWork?.cancel()
        debounceWork = nil
        pending.removeAll()
        handler = nil
        presentedItemURL = nil
        lock.unlock()
    }

    public func presentedSubitemDidChange(at url: URL) {
        enqueue([url])
    }

    public func presentedSubitemDidAppear(at url: URL) {
        enqueue([url])
    }

    public func accommodatePresentedSubitemDeletion(at url: URL) async throws {
        enqueue([url])
    }

    public func presentedItemDidChange() {
        if let presentedItemURL {
            enqueue([presentedItemURL])
        }
    }

    fileprivate func enqueue(_ urls: [URL]) {
        lock.lock()
        for url in urls {
            pending.insert(url.standardizedFileURL)
        }
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flush()
        }
        debounceWork = work
        lock.unlock()
        callbackQueue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func flush() {
        lock.lock()
        let urls = Array(pending)
        pending.removeAll()
        let handler = self.handler
        lock.unlock()
        guard !urls.isEmpty else { return }
        handler?(urls)
    }

    private static let streamCallback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, _, _ in
        guard let clientCallBackInfo else { return }
        let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
        guard let array = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
        let limit = min(Int(numEvents), array.count)
        let urls = array.prefix(limit).map { URL(fileURLWithPath: $0) }
        monitor.enqueue(urls)
    }
}
