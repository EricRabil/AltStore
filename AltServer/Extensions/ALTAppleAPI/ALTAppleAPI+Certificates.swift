//
//  ALTAppleAPI+Certificates.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import AppKit

extension ALTAppleAPI {
    func fetchCertificate(for team: ALTTeam, session: ALTAppleAPISession) -> Future<ALTCertificate, Error>
    {
        Future { completionHandler in
            var cancellables = Set<AnyCancellable>()
            
            ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { (certificates, error) in
                do
                {
                    let certificates = try Result(certificates, error).get()
                    
                    let certificateFileURL = FileManager.default.certificatesDirectory.appendingPathComponent(team.identifier + ".p12")
                    try FileManager.default.createDirectory(at: FileManager.default.certificatesDirectory, withIntermediateDirectories: true, attributes: nil)
                    
                    var isCancelled = false
                    
                    // Check if there is another AltStore certificate, which means AltStore has been installed with this Apple ID before.
                    if let previousCertificate = certificates.first(where: { $0.machineName?.starts(with: "AltStore") == true })
                    {
                        if FileManager.default.fileExists(atPath: certificateFileURL.path),
                           let data = try? Data(contentsOf: certificateFileURL),
                           let certificate = ALTCertificate(p12Data: data, password: previousCertificate.machineIdentifier)
                        {
                            // Manually set machineIdentifier so we can encrypt + embed certificate if needed.
                            certificate.machineIdentifier = previousCertificate.machineIdentifier
                            return completionHandler(.success(certificate))
                        }
                                            
                        DispatchQueue.main.sync {
                            let alert = NSAlert()
                            alert.messageText = NSLocalizedString("Multiple AltServers Not Supported", comment: "")
                            alert.informativeText = NSLocalizedString("Please use the same AltServer you previously used with this Apple ID, or else apps installed with other AltServers will stop working.\n\nAre you sure you want to continue?", comment: "")
                            
                            alert.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                            
                            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                            
                            let buttonIndex = alert.runModal()
                            if buttonIndex == NSApplication.ModalResponse.alertSecondButtonReturn
                            {
                                isCancelled = true
                            }
                        }
                        
                        guard !isCancelled else { return completionHandler(.failure(InstallError.cancelled)) }
                    }
                    
                    if team.type != .free
                    {
                        DispatchQueue.main.sync {
                            let alert = NSAlert()
                            alert.messageText = NSLocalizedString("Installing this app will revoke your iOS development certificate.", comment: "")
                            alert.informativeText = NSLocalizedString("""
    This will not affect apps you've submitted to the App Store, but may cause apps you've installed to your devices with Xcode to stop working until you reinstall them.

    To prevent this from happening, feel free to try again with another Apple ID.
    """, comment: "")
                            
                            alert.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                            
                            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                            
                            let buttonIndex = alert.runModal()
                            if buttonIndex == NSApplication.ModalResponse.alertSecondButtonReturn
                            {
                                isCancelled = true
                            }
                        }
                        
                        guard !isCancelled else { return completionHandler(.failure(InstallError.cancelled)) }
                    }
                    
                    if let certificate = certificates.first
                    {
                        ALTAppleAPI.shared.revoke(certificate, for: team, session: session) { (success, error) in
                            do
                            {
                                try Result(success, error).get()
                                self.fetchCertificate(for: team, session: session).sink(receiveResult: completionHandler).store(in: &cancellables)
                            }
                            catch
                            {
                                completionHandler(.failure(error))
                            }
                        }
                    }
                    else
                    {
                        ALTAppleAPI.shared.addCertificate(machineName: "AltStore", to: team, session: session) { (certificate, error) in
                            do
                            {
                                let certificate = try Result(certificate, error).get()
                                guard let privateKey = certificate.privateKey else { throw InstallError.missingPrivateKey }
                                
                                ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { (certificates, error) in
                                    do
                                    {
                                        let certificates = try Result(certificates, error).get()
                                        
                                        guard let certificate = certificates.first(where: { $0.serialNumber == certificate.serialNumber }) else {
                                            throw InstallError.missingCertificate
                                        }
                                        
                                        certificate.privateKey = privateKey
                                        
                                        completionHandler(.success(certificate))
                                        
                                        if let machineIdentifier = certificate.machineIdentifier,
                                           let encryptedData = certificate.encryptedP12Data(withPassword: machineIdentifier)
                                        {
                                            // Cache certificate.
                                            do { try encryptedData.write(to: certificateFileURL, options: .atomic) }
                                            catch { print("Failed to cache certificate:", error) }
                                        }
                                    }
                                    catch
                                    {
                                        completionHandler(.failure(error))
                                    }
                                }
                            }
                            catch
                            {
                                completionHandler(.failure(error))
                            }
                        }
                    }
                }
                catch
                {
                    completionHandler(.failure(error))
                }
            }
        }
    }
}
