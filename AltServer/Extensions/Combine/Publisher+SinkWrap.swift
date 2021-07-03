//
//  Publisher+SinkWrap.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    public func sink(receiveFailure: @escaping (Self.Failure) -> Void, receiveValue: @escaping (Self.Output) -> Void) -> AnyCancellable {
        sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
                receiveFailure(err)
            }
        }, receiveValue: receiveValue)
    }
    
    public func sink(receiveResult: @escaping (Result<Self.Output, Self.Failure>) -> Void) -> AnyCancellable {
        sink(receiveFailure: { receiveResult(.failure($0)) }, receiveValue: { receiveResult(.success($0)) })
    }
}
