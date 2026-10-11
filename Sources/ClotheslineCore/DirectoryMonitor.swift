import Foundation

/// 监听一个目录的条目变化（新增、删除、改名——「预览」的安全保存也在其中），
/// 短时间内的连续变化合并成一次回调。
public final class DirectoryMonitor {
    public enum Error: Swift.Error { case cannotOpen(URL) }

    private let source: DispatchSourceFileSystemObject
    private var pending: DispatchWorkItem?

    public init(url: URL, debounce: TimeInterval = 0.3, queue: DispatchQueue = .main,
                handler: @escaping () -> Void) throws {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { throw Error.cannotOpen(url) }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete, .link], queue: queue)
        source.setEventHandler { [weak self] in
            self?.pending?.cancel()
            let work = DispatchWorkItem(block: handler)
            self?.pending = work
            queue.asyncAfter(deadline: .now() + debounce, execute: work)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    deinit {
        pending?.cancel()
        source.cancel()
    }
}
