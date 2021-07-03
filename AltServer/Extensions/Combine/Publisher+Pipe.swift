//
//  Publisher+Pipe.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    func pipe(_ cb: @escaping (Output) -> ()) -> Publishers.Map<Self, Output> {
        map {
            cb($0)
            return $0
        }
    }
    
    func pipeError(_ cb: @escaping (Failure) -> ()) -> Publishers.MapError<Self, Failure> {
        mapError {
            cb($0)
            return $0
        }
    }
    
    func pipeVoid(_ cb: @escaping () -> ()) -> Publishers.Map<Self, Output> {
        map {
            cb()
            return $0
        }
    }
}
