//
//  Publisher+Void.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension Publisher {
    var void: AnyPublisher<Void, Failure> {
        map { _ in }.eraseToAnyPublisher()
    }
}
