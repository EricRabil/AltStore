//
//  ALTInstallationPipeline.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

class ALTInstallationPipeline {
    let provider: ALTInstallationPipelineProvider
    
    var application: ALTApplication { provider.application }
    var device: ALTDevice { provider.device }
    var team: ALTTeam { provider.team }
    var certificate: ALTCertificate { provider.cert }
    var profiles: [String: ALTProvisioningProfile] { provider.profiles }
    var allProfiles: [ALTProvisioningProfile] { Array(profiles.values) }
    lazy var resigner = { ALTSigner(team: team, certificate: certificate) }()
    
    var activeProfiles: Set<String>? {
        guard team.type == .free, application.isAltStoreApp else {
            return nil
        }
        
        return Set(allProfiles.map(\.bundleIdentifier))
    }
    
    init(provider: ALTInstallationPipelineProvider) {
        self.provider = provider
    }
    
    func prepare(_ bundle: Bundle, additionalInfoDictionaryValues: [String: Any] = [:]) throws {
        guard let identifier = bundle.bundleIdentifier else { throw ALTError(.missingAppBundle) }
        guard let profile = profiles[identifier] else { throw ALTError(.missingProvisioningProfile) }
        guard var infoDictionary = bundle.completeInfoDictionary else { throw ALTError(.missingInfoPlist) }
        
        infoDictionary[kCFBundleIdentifierKey as String] = profile.bundleIdentifier
        infoDictionary[Bundle.Info.altBundleID] = identifier

        for (key, value) in additionalInfoDictionaryValues
        {
            infoDictionary[key] = value
        }
        
        if let appGroups = profile.entitlements[.appGroups] as? [String]
        {
            infoDictionary[Bundle.Info.appGroups] = appGroups
        }
        
        try (infoDictionary as NSDictionary).write(to: bundle.infoPlistURL)
    }
    
    func computeInfoExtras(forAppBundle appBundle: Bundle) throws -> [String: Any] {
        guard let infoDictionary = appBundle.completeInfoDictionary else {
            throw ALTError(.missingInfoPlist)
        }
        
        let openAppURL = URL(string: "altstore-" + application.bundleIdentifier + "://")!
        
        var allURLSchemes = infoDictionary[Bundle.Info.urlTypes] as? [[String: Any]] ?? []
        
        // Embed open URL so AltBackup can return to AltStore.
        let altstoreURLScheme = ["CFBundleTypeRole": "Editor",
                                 "CFBundleURLName": application.bundleIdentifier,
                                 "CFBundleURLSchemes": [openAppURL.scheme!]] as [String : Any]
        allURLSchemes.append(altstoreURLScheme)
        
        var additionalValues: [String: Any] = [Bundle.Info.urlTypes: allURLSchemes]
        
        if application.isAltStoreApp {
            additionalValues[Bundle.Info.deviceID] = device.identifier
            additionalValues[Bundle.Info.serverID] = UserDefaults.standard.serverID
            
            if
                let machineIdentifier = certificate.machineIdentifier,
                let encryptedData = certificate.encryptedP12Data(withPassword: machineIdentifier)
            {
                additionalValues[Bundle.Info.certificateID] = certificate.serialNumber
                
                let certificateURL = application.fileURL.appendingPathComponent("ALTCertificate.p12")
                try encryptedData.write(to: certificateURL, options: .atomic)
            }
        }
        
        return additionalValues
    }
    
    func prepareAll() throws {
        guard let appBundle = Bundle(url: application.fileURL) else {
            throw ALTError(.missingAppBundle)
        }
        
        try prepare(appBundle, additionalInfoDictionaryValues: computeInfoExtras(forAppBundle: appBundle))
        
        for appExtension in application.appExtensions {
            guard let bundle = Bundle(url: appExtension.fileURL) else {
                throw ALTError(.missingAppBundle)
            }
            
            try prepare(bundle)
        }
    }
    
    func install() -> Future<Void, Error> {
        Future { completionHandler in
            ALTDeviceManager.shared.installApp(at: self.application.fileURL, toDeviceWithUDID: self.device.identifier, activeProvisioningProfiles: self.activeProfiles) { success, error in
                completionHandler(Result(success, error))
            }
        }.pipeError {
            print("Failed to install app", $0)
        }.asFuture()
    }
    
    func sign() -> Future<Void, Error> {
        Future { completionHandler in
            self.resigner.signApp(at: self.application.fileURL, provisioningProfiles: self.allProfiles) { success, error in
                completionHandler(Result(success, error))
            }
        }.pipeError {
            print("Failed to sign app", $0)
        }.asFuture()
    }
    
    func runPipeline() -> Future<Void, Error> {
        Future { completionHandler in
            do {
                try self.prepareAll()
                completionHandler(.success(()))
            } catch {
                completionHandler(.failure(error))
            }
        }.flatMap { () -> Future<Void, Error> in
            print("prepared. signing")
            return self.sign()
        }.flatMap { () -> Future<Void, Error> in
            print("signed. installing")
            return self.install()
        }.void.asFuture()
    }
}
