//
//  LegacyFuture.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

func LegacyFutureUnwrapping<Output, Failure>(_ cb: @escaping (@escaping (Output?, Failure?) -> ()) -> ()) -> Future<Output, Failure> {
    Future { completion in
        cb { output, error in
            if let error = error {
                return completion(.failure(error))
            }
            
            return completion(.success(output!))
        }
    }
}

func LegacyFuture<Output, Failure>(_ cb: @escaping (@escaping (Output, Failure?) -> ()) -> ()) -> Future<Output, Failure> {
    Future { completion in
        cb { output, error in
            if let error = error {
                return completion(.failure(error))
            }
            
            return completion(.success(output))
        }
    }
}
