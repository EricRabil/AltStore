//
//  ALTAppleAPI+Registration.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

private let appGroupsLock = NSLock()
private var cancellables = Set<AnyCancellable>()

extension ALTAppleAPI {
    func updateFeatures(for appID: ALTAppID, app: ALTApplication, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTAppID, Error> {
        Future { completionHandler in
            let requiredFeatures = app.entitlements.compactMap { (entitlement, value) -> (ALTFeature, Any)? in
                guard let feature = ALTFeature(entitlement: entitlement) else { return nil }
                return (feature, value)
            }
            
            var features = requiredFeatures.reduce(into: [ALTFeature: Any]()) { $0[$1.0] = $1.1 }
            
            if let applicationGroups = app.entitlements[.appGroups] as? [String], !applicationGroups.isEmpty
            {
                features[.appGroups] = true
            }
            
            var updateFeatures = false
            
            // Determine whether the required features are already enabled for the AppID.
            for (feature, value) in features
            {
                if let appIDValue = appID.features[feature] as AnyObject?, (value as AnyObject).isEqual(appIDValue)
                {
                    // AppID already has this feature enabled and the values are the same.
                    continue
                }
                else
                {
                    // AppID either doesn't have this feature enabled or the value has changed,
                    // so we need to update it to reflect new values.
                    updateFeatures = true
                    break
                }
            }
            
            if updateFeatures
            {
                let appID = appID.copy() as! ALTAppID
                appID.features = features
                
                ALTAppleAPI.shared.update(appID, team: team, session: session) { (appID, error) in
                    completionHandler(Result(appID, error))
                }
            }
            else
            {
                completionHandler(.success(appID))
            }
        }
    }
    
    func updateAppGroups(for appID: ALTAppID, app: ALTApplication, team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTAppID, Error>
    {
        
        return Future { completionHandler in
            let applicationGroups = app.entitlements[.appGroups] as? [String] ?? []
            if applicationGroups.isEmpty
            {
                guard let isAppGroupsEnabled = appID.features[.appGroups] as? Bool, isAppGroupsEnabled else {
                    // No app groups, and we also haven't enabled the feature, so don't continue.
                    // For apps with no app groups but have had the feature enabled already
                    // we'll continue and assign the app ID to an empty array
                    // in case we need to explicitly remove them.
                    print("no app groups, get that bread get that head then leave. \(appID.identifier)")
                    return completionHandler(.success(appID))
                }
            }
            
            // Dispatch onto global queue to prevent appGroupsLock deadlock.
            DispatchQueue.global().async {
                
                // Ensure we're not concurrently fetching and updating app groups,
                // which can lead to race conditions such as adding an app group twice.
                appGroupsLock.lock()
                
                LegacyFutureUnwrapping {
                    ALTAppleAPI.shared.fetchAppGroups(for: team, session: session, completionHandler: $0)
                }.pipeVoid { print("fetched app groups for \(appID.identifier)") }.flatMap { fetchedGroups in
                    Publishers.MergeMany(
                        applicationGroups.map { groupIdentifier -> AnyPublisher<ALTAppGroup, Error> in
                            let adjustedGroupIdentifier = groupIdentifier + "." + team.identifier
                            
                            if let group = fetchedGroups.first(where: { $0.groupIdentifier == adjustedGroupIdentifier }) {
                                return Just(group).setFailureType(to: Error.self).eraseToAnyPublisher()
                            }
                            
                            // Not all characters are allowed in group names, so we replace periods with spaces (like Apple does).
                            let name = "AltStore " + groupIdentifier.replacingOccurrences(of: ".", with: " ")
                            
                            return LegacyFutureUnwrapping {
                                ALTAppleAPI.shared.addAppGroup(withName: name, groupIdentifier: adjustedGroupIdentifier, team: team, session: session, completionHandler: $0)
                            }.eraseToAnyPublisher()
                        }
                    ).collect().pipeVoid { print("\(appID.identifier) finished resolving groups") }.flatMap { groups in
                        LegacyFutureUnwrapping {
                            ALTAppleAPI.shared.assign(appID, to: groups, team: team, session: session, completionHandler: $0)
                        }.pipeVoid { print("\(appID.identifier) assigned groups") }
                    }
                }.sink(receiveResult: { result in
                    print("finished updating app groups \(appID.identifier)")
                    appGroupsLock.unlock()
                    completionHandler(result.map { _ in
                        appID
                    })
                }).store(in: &cancellables)
            }
        }
    }
}
