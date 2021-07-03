//
//  ALTInstallationPipeline.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import AppKit
import UserNotifications

class ALTInstallError: Error {
    let innerError: Error
    let title: String
    
    init(_ innerError: Error, title: String = "") {
        self.innerError = innerError
        self.title = title
    }
}

protocol ALTInstallationPipelineProvider {
    var account: ALTAccount! { get }
    var device: ALTDevice! { get }
    var team: ALTTeam! { get }
    var cert: ALTCertificate! { get }
    var profiles: [String: ALTProvisioningProfile]! { get }
    var application: ALTApplication! { get }
}

class ALTAutomatedInstallationPipeline: ALTInstallationPipelineProvider {
    var account: ALTAccount!
    var session: ALTAppleAPISession!
    var team: ALTTeam!
    var device: ALTDevice!
    var cert: ALTCertificate!
    var profiles: [String: ALTProvisioningProfile]!
    var application: ALTApplication!
    let destinationDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    
    lazy var installationPipeline: ALTInstallationPipeline = { ALTInstallationPipeline(provider: self) }()
    
    func updateAnisetteData() -> Future<ALTAnisetteData, Error> {
        AnisetteDataManager.shared.requestAnisetteData().mapError {
            ALTInstallError($0, title: "Failed to Refresh Anisette Data")
        }.pipe { anisetteData in
            self.session?.anisetteData = anisetteData
        }.asFuture()
    }
    
    func authenticate(appleID: String, password: String) -> Future<Void, Error> {
        updateAnisetteData().flatMap { anisetteData in
            ALTDeviceManager.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData).mapError {
                ALTInstallError($0, title: "Failed to Authenticate")
            }.pipe { (account, session) in
                self.account = account
                self.session = session
            }
        }.void.asFuture()
    }
    
    func fetchTeam() -> Future<Void, Error> {
        ALTAppleAPI.shared.fetchTeam(for: account, session: session).mapError {
            ALTInstallError($0, title: "Failed to Fetch Team")
        }.pipe { team in
            self.team = team
        }.void.asFuture()
    }
    
    func register(device altDevice: ALTDevice) -> Future<Void, Error> {
        ALTAppleAPI.shared.register(altDevice, team: team, session: session).mapError {
            ALTInstallError($0, title: "Failed to Register Device")
        }.pipe {
            $0.osVersion = altDevice.osVersion
        }.pipe {
            self.device = $0
        }.void.asFuture()
    }
    
    func fetchCertificate() -> Future<Void, Error> {
        ALTAppleAPI.shared.fetchCertificate(for: team, session: session).mapError {
            ALTInstallError($0, title: "Failed to Fetch Certificate")
        }.pipe {
            self.cert = $0
        }.void.asFuture()
    }
    
    func promptIfNeeded(forURL url: URL) {
        if !url.isFileURL {
            // Show alert before downloading remote .ipa.
            showInstallationAlert(appName: NSLocalizedString("AltStore", comment: ""), deviceName: device.name)
        }
    }
    
    func downloadApp(fromURL url: URL) -> Future<Void, Error> {
        downloadApp(from: url).tryMap { fileURL -> ALTApplication in
            try FileManager.default.createDirectory(at: self.destinationDirectoryURL, withIntermediateDirectories: true, attributes: nil)

            let appBundleURL = try FileManager.default.unzipAppBundle(at: fileURL, toDirectory: self.destinationDirectoryURL)
            guard let application = ALTApplication(fileURL: appBundleURL) else { throw ALTError(.invalidApp) }

            if url.isFileURL
            {
                // Show alert after "downloading" local .ipa.
                self.showInstallationAlert(appName: application.name, deviceName: self.device.name)
            }
            
            self.application = application

            return application
        }.mapError {
            ALTInstallError($0, title: "Failed to Download AltStore")
        }.void.asFuture()
    }
    
    func prepareProfiles() -> Future<Void, Error> {
        ALTAppleAPI.shared.prepareAllProvisioningProfiles(for: application, device: device, team: team, session: session).mapError {
            ALTInstallError($0, title: "Failed to Fetch Provisioning Profiles")
        }.pipe {
            self.profiles = $0
        }.void.asFuture()
    }
    
    func install() -> Future<Void, Error> {
        installationPipeline.runPipeline().mapError {
            ALTInstallError($0, title: "Failed to Install AltStore")
        }.void.asFuture()
    }
    
    func prepare() -> Future<Void, Error> {
        ALTDeviceManager.shared.prepare(self.device).catch { error -> AnyPublisher<Void, Error> in
            print("Failed to install DeveloperDiskImage.dmg to \(self.device.name).", error)
            return Just(()).mapError { ALTInstallError($0, title: "") }.eraseToAnyPublisher()
        }.void.asFuture()
    }
    
    func runPipeline(at url: URL, to altDevice: ALTDevice, appleID: String, password: String) -> Future<ALTAutomatedInstallationPipeline, Error> {
        self.authenticate(appleID: appleID, password: password).pipeVoid {
            print("authenticated")
        }.flatMap {
            self.fetchTeam().pipeVoid { print("fetched teams") }
        }.flatMap {
            self.register(device: altDevice).pipeVoid { print("registered device.") }
        }.flatMap {
            self.fetchCertificate().pipeVoid { print("fetched certificates") }
        }.pipe { _ in
            self.promptIfNeeded(forURL: url)
        }.flatMap {
            self.prepare().pipeVoid { print("prepared.") }
        }.flatMap {
            self.downloadApp(fromURL: url).pipeVoid { print("downloaded.") }
        }.flatMap {
            self.updateAnisetteData().void.pipeVoid { print("anisette updated.") }
        }.flatMap {
            self.prepareProfiles().pipeVoid { print("profiles prepared.") }
        }.flatMap {
            self.install().pipeVoid { print("installed") }
        }.mapError { error in
            switch error {
            case let error as NSError:
                return error.withLocalizedFailure(String(format: NSLocalizedString("Could not install %@ to %@.", comment: ""), self.application?.name ?? "app", altDevice.name))
            default:
                return error
            }
        }.map { self }.receive(on: RunLoop.main).asFuture()
    }
}

// MARK: - IO
fileprivate extension ALTAutomatedInstallationPipeline {
    func downloadApp(from url: URL) -> Future<URL, Error>
    {
        Future { completionHandler in
            guard !url.isFileURL else { return completionHandler(.success(url)) }
            
            var cancellables = Set<AnyCancellable>()
            
            URLSession.shared.downloadTaskPublisher(for: url).map {
                $0.url
            }.sink(receiveResult: completionHandler).store(in: &cancellables)
        }
    }
}

// MARK: - UI
fileprivate extension ALTAutomatedInstallationPipeline {
    func showInstallationAlert(appName: String, deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(format: NSLocalizedString("Installing %@ to %@...", comment: ""), appName, deviceName)
        content.body = NSLocalizedString("This may take a few seconds.", comment: "")
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
