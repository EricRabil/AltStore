//
//  AppDelegate+Sideloading.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit
import UserNotifications
import Combine

#if STAGING
private let altstoreAppURL = URL(string: "https://f000.backblazeb2.com/file/altstore-staging/altstore.ipa")!
#elseif BETA
private let altstoreAppURL = URL(string: "https://cdn.altstore.io/file/altstore/altstore-beta.ipa")!
#else
private let altstoreAppURL = URL(string: "https://cdn.altstore.io/file/altstore/altstore.ipa")!
#endif

extension AppDelegate
{
    @objc func installAltStore(to device: ALTDevice)
    {
        self.installApplication(at: altstoreAppURL, to: device)
    }
    
    @objc func sideloadIPA(to device: ALTDevice)
    {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["ipa"]
        openPanel.begin { (response) in
            guard let fileURL = openPanel.url, response == .OK else { return }
            self.installApplication(at: fileURL, to: device)
        }
    }
    
    func installApplication(at url: URL, to device: ALTDevice)
    {
        let alert = ALTLoginAlert()
        
        self.authenticationAlert = alert
        
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let username = alert.appleID, password = alert.password
                
        var cancellables = Set<AnyCancellable>()
        
        func install() {
            ALTAutomatedInstallationPipeline().runPipeline(at: url, to: device, appleID: username, password: password).sink(receiveResult: { (result) in
                switch result {
                case .success(let pipeline):
                    let content = UNMutableNotificationContent()
                    content.title = NSLocalizedString("Installation Succeeded", comment: "")
                    content.body = String(format: NSLocalizedString("%@ was successfully installed on %@.", comment: ""), pipeline.application.name, device.name)
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                    
                case .failure(InstallError.cancelled), .failure(ALTAppleAPIError.requiresTwoFactorAuthentication):
                    // Ignore
                    break
                    
                case .failure(let error):
                    self.showErrorAlert(error: error, localizedFailure: String(format: NSLocalizedString("Could not install app to %@.", comment: ""), device.name))
                }
            }).store(in: &cancellables)
        }
        
        if !self.pluginManager.isMailPluginInstalled || self.pluginManager.isUpdateAvailable
        {
            AnisetteDataManager.shared.isXPCAvailable { (isAvailable) in
                if isAvailable
                {
                    // XPC service is available, so we don't need to install/update Mail plug-in.
                    // Users can still manually do so from the AltServer menu.
                    install()
                }
                else
                {
                    DispatchQueue.main.async {
                        self.installMailPlugin { (result) in
                            switch result
                            {
                            case .failure: break
                            case .success: install()
                            }
                        }
                    }
                }
            }
        }
        else
        {
            install()
        }
    }
}
