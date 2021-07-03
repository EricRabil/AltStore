//
//  URLSession+DownloadTaskPublisher.swift
//  AltServer
//
//  Created by Eric Rabil on 7/1/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension URLSession {

    /// Returns a publisher that wraps a URL session download task for a given
    /// URL.
    ///
    /// - Parameter url: The URL for which to create a download task.
    /// - Returns: A publisher that wraps a download task for the URL.
    public func downloadTaskPublisher(for url: URL) -> DownloadTaskPublisher {
        DownloadTaskPublisher(session: self, request: URLRequest(url: url))
    }

    /// Returns a publisher that wraps a URL session download task for a given
    /// URL request.
    ///
    /// - Parameter request: The URL request for which to create a download task.
    /// - Returns: A publisher that wraps a download task for the URL request.
    public func downloadTaskPublisher(for request: URLRequest) -> DownloadTaskPublisher {
        DownloadTaskPublisher(session: self, request: request)
    }
}

public struct DownloadTaskPublisher {
    fileprivate let session: URLSession
    fileprivate let request: URLRequest
}

extension DownloadTaskPublisher: Publisher {

    public typealias Output = (url: URL, response: URLResponse)
    public typealias Failure = Error

    public func receive<Subscriber>(subscriber: Subscriber)
        where
        Subscriber: Combine.Subscriber,
        Subscriber.Failure == Failure,
        Subscriber.Input == Output
    {
        let subscription = Subscription(subscriber: subscriber, session: session, request: request)
        subscriber.receive(subscription: subscription)
    }
}

extension DownloadTaskPublisher {

    fileprivate final class Subscription {
        private let downloadTask: URLSessionDownloadTask
        init<Subscriber>(subscriber: Subscriber, session: URLSession, request: URLRequest)
            where
            Subscriber: Combine.Subscriber,
            Subscriber.Input == Output,
            Subscriber.Failure == Failure
        {
            downloadTask = session.downloadTask(with: request, completionHandler: { (url, response, error) in

                guard let url = url, let response = response else {
                    subscriber.receive(completion: .failure(error!))
                    return
                }

                _ = subscriber.receive((url, response))
                subscriber.receive(completion: .finished)
            })
        }
    }
}

extension DownloadTaskPublisher.Subscription: Subscription {

    fileprivate func request(_ demand: Subscribers.Demand) {
        downloadTask.resume()
    }

    fileprivate func cancel() {
        downloadTask.cancel()
    }
}
