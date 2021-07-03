//
//  ALTAppleAPI.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension ALTAppleAPI {
    func register(_ device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTDevice, Error> {
        LegacyFutureUnwrapping {
            self.fetchDevices(for: team, types: device.type, session: session, completionHandler: $0)
        }.flatMap { devices -> AnyPublisher<ALTDevice, Error> in
            if let device = devices.first(where: { $0.identifier == device.identifier }) {
                return Just(device).setFailureType(to: Error.self).eraseToAnyPublisher()
            } else {
                return LegacyFutureUnwrapping {
                    self.registerDevice(name: device.name, identifier: device.identifier, type: device.type, team: team, session: session, completionHandler: $0)
                }.eraseToAnyPublisher()
            }
        }.asFuture()
    }
    
    func registerAppID(name appName: String, bundleID: String, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTAppID, Error> {
        LegacyFutureUnwrapping {
            ALTAppleAPI.shared.fetchAppIDs(for: team, session: session, completionHandler: $0)
        }.flatMap { appIDs -> AnyPublisher<ALTAppID, Error> in
            if let appID = appIDs.first(where: { $0.bundleIdentifier == bundleID }) {
                return Just(appID).setFailureType(to: Error.self).eraseToAnyPublisher()
            } else {
                return LegacyFutureUnwrapping {
                    ALTAppleAPI.shared.addAppID(withName: appName, bundleIdentifier: bundleID, team: team, session: session, completionHandler: $0)
                }.eraseToAnyPublisher()
            }
        }.asFuture()
    }
}
