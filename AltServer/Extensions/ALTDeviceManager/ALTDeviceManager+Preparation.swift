//
//  ALTDeviceManager+Preparation.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

private let developerDiskManager = DeveloperDiskManager()

extension ALTDeviceManager
{
    func prepare(_ device: ALTDevice) -> Future<Void, Error>
    {
        Future { completionHandler in
            ALTDeviceManager.shared.isDeveloperDiskImageMounted(for: device) { (isMounted, error) in
                switch (isMounted, error)
                {
                case (_, let error?): return completionHandler(.failure(error))
                case (true, _): return completionHandler(.success(()))
                case (false, _):
                    developerDiskManager.downloadDeveloperDisk(for: device) { (result) in
                        switch result
                        {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success((let diskFileURL, let signatureFileURL)):
                            ALTDeviceManager.shared.installDeveloperDiskImage(at: diskFileURL, signatureURL: signatureFileURL, to: device) { (success, error) in
                                switch Result(success, error)
                                {
                                case .failure(let error): completionHandler(.failure(error))
                                case .success: completionHandler(.success(()))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
