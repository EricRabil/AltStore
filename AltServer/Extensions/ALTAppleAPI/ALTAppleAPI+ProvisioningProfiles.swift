//
//  ALTAppleAPI+ProvisioningProfiles.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension ALTAppleAPI {
    func fetchProvisioningProfile(for appID: ALTAppID, device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTProvisioningProfile, Error> {
        LegacyFutureUnwrapping {
            ALTAppleAPI.shared.fetchProvisioningProfile(for: appID, deviceType: device.type, team: team, session: session, completionHandler: $0)
        }
    }
    
    func prepareProvisioningProfile(for application: ALTApplication, parentApp: ALTApplication?, device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTProvisioningProfile, Error>
    {
        print("prepare provisioning profile for \(application.bundleIdentifier)")
        let parentBundleID = parentApp?.bundleIdentifier ?? application.bundleIdentifier
        let updatedParentBundleID: String
        
        if application.isAltStoreApp
        {
            // Use legacy bundle ID format for AltStore (and its extensions).
            updatedParentBundleID = "com.\(team.identifier).\(parentBundleID)"
        }
        else
        {
            updatedParentBundleID = parentBundleID + "." + team.identifier // Append just team identifier to make it harder to track.
        }
        
        let bundleID = application.bundleIdentifier.replacingOccurrences(of: parentBundleID, with: updatedParentBundleID)
        
        let preferredName: String
        
        if let parentApp = parentApp
        {
            preferredName = parentApp.name + " " + application.name
        }
        else
        {
            preferredName = application.name
        }
        
        return ALTAppleAPI.shared.registerAppID(name: preferredName, bundleID: bundleID, team: team, session: session).pipeVoid {
            print("registered app id for \(application.bundleIdentifier)")
        }.flatMap { appID in
            ALTAppleAPI.shared.updateFeatures(for: appID, app: application, team: team, session: session).pipeVoid { print("updated features for \(application.bundleIdentifier)") }
        }.flatMap { appID in
            ALTAppleAPI.shared.updateAppGroups(for: appID, app: application, team: team, session: session).pipeVoid { print("updated app groups for \(application.bundleIdentifier)") }
        }.flatMap { appID in
            ALTAppleAPI.shared.fetchProvisioningProfile(for: appID, device: device, team: team, session: session).pipeVoid { print("fetched provisioning profile for \(application.bundleIdentifier)") }
        }.pipeVoid { print("created provisioning profile for \(application.bundleIdentifier)") }.asFuture()
    }
    
    func prepareAllProvisioningProfiles(for application: ALTApplication, device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession) -> Future<[String: ALTProvisioningProfile], Error>
    {
        ALTAppleAPI.shared.prepareProvisioningProfile(for: application, parentApp: nil, device: device, team: team, session: session).pipeVoid {
            print("prepared provisioning profile")
        }.flatMap { profile in
            
            
            Publishers.MergeMany(
                application.appExtensions.map { appExtension in
                    return ALTAppleAPI.shared.prepareProvisioningProfile(for: appExtension, parentApp: application, device: device, team: team, session: session).map {
                        (appExtension, $0)
                    }.pipeVoid { print("prepared extension provisioning profile") }
                }
            ).reduce([application.bundleIdentifier: profile]) { profiles, result in
                var profiles = profiles
                profiles[result.0.bundleIdentifier] = result.1
                return profiles
            }
        }.asFuture()
    }
}
