//
//  Model.swift
//  Downloader
//
//  Created by Chris Eidhof on 15.11.21.
//

import Foundation

@MainActor
final class DownloadModel: ObservableObject, Sendable {
    let url: URL
    init(_ url: URL) {
        self.url = url
    }
    
    enum State {
        case notStarted
        case started
        case paused(resumeData: Data?)
        case done(URL)
    }
    
    @Published var progress: (bytesWritten: Int64, bytesExpected: Int64)?
    
    @Published var state = State.notStarted
    
    private var downloadTask: URLSessionDownloadTask?
    private var delegate = DownloadModelDelegate()
    
    func start() async {
        let task: URLSessionDownloadTask
        if case let .paused(data?) = state {
            task = URLSession.shared.downloadTask(withResumeData: data)
        } else {
            task = URLSession.shared.downloadTask(with: url)
        }
        state = .started
        task.delegate = delegate
        let stream = AsyncStream<DownloadModelDelegate.Event> { cont in
            delegate.onEvent = { event in
                cont.yield(event)
                if case .didFinish = event {
                    cont.finish()
                }
                if case .didCancel = event {
                    cont.finish()
                }
            }
        }
        task.resume()
        downloadTask = task
        for await event in stream {
            switch event {
            case .didCancel:
                ()
            case .didFinish(let url):
                state = .done(url)
            case let .didWrite(bytesWritten: written, bytesExpected: expected):
                progress = (written, expected)
            }
        }
        print("All done")
    }
    
    func pause() async {
        let data = await downloadTask?.cancelByProducingResumeData()
        state = .paused(resumeData: data)
    }
}

final class DownloadModelDelegate: NSObject, URLSessionDownloadDelegate {
    enum Event {
        case didCancel
        case didFinish(URL)
        case didWrite(bytesWritten: Int64, bytesExpected: Int64)
    }
    
    var onEvent: (Event) -> () = { _ in }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        onEvent(.didFinish(location))
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let n = error as? NSError, n.code == CFNetworkErrors.cfurlErrorCancelled.rawValue {
            onEvent(.didCancel)
        } else {
            print("Error", error) // todo
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onEvent(.didWrite(bytesWritten: totalBytesWritten, bytesExpected: totalBytesExpectedToWrite))
    }
}
