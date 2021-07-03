//
//  Publisher+Future.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    func asFuture() -> Future<Output, Failure> {
        return Future { promise in
            var ticket: AnyCancellable? = nil
            ticket = self.sink(
                receiveCompletion: {
                    ticket?.cancel()
                    ticket = nil
                    switch $0 {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        break
                    }
            },
                receiveValue: {
                    ticket?.cancel()
                    ticket = nil
                    promise(.success($0))
            })
        }
    }
}
