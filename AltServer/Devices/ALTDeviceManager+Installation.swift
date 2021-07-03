//
//  ALTDeviceManager+Installation.swift
//  AltServer
//
//  Created by Riley Testut on 7/1/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Cocoa
import UserNotifications
import ObjectiveC
import Combine

enum InstallError: LocalizedError
{
    case cancelled
    case noTeam
    case missingPrivateKey
    case missingCertificate
    
    var errorDescription: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The operation was cancelled.", comment: "")
        case .noTeam: return "You are not a member of any developer teams."
        case .missingPrivateKey: return "The developer certificate's private key could not be found."
        case .missingCertificate: return "The developer certificate could not be found."
        }
    }
}
