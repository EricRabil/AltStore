//
//  AppDelegate+MailPlugin.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit

extension AppDelegate {
    @objc func handleInstallMailPluginMenuItem(_ item: NSMenuItem)
    {
        if !self.pluginManager.isMailPluginInstalled || self.pluginManager.isUpdateAvailable
        {
            self.installMailPlugin()
        }
        else
        {
            self.uninstallMailPlugin()
        }
    }
    
    func installMailPlugin(completion: ((Result<Void, Error>) -> Void)? = nil)
    {
        self.pluginManager.installMailPlugin { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(PluginError.cancelled): break
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Failed to Install Mail Plug-in", comment: "")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                    
                case .success:
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Mail Plug-in Installed", comment: "")
                    alert.informativeText = NSLocalizedString("Please restart Mail and enable AltPlugin in Mail's Preferences. Mail must be running when installing or refreshing apps with AltServer.", comment: "")
                    alert.runModal()
                }
                
                completion?(result)
            }
        }
    }
    
    func uninstallMailPlugin()
    {
        self.pluginManager.uninstallMailPlugin { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(PluginError.cancelled): break
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Failed to Uninstall Mail Plug-in", comment: "")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                    
                case .success:
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("Mail Plug-in Uninstalled", comment: "")
                    alert.informativeText = NSLocalizedString("Please restart Mail for changes to take effect. You will not be able to use AltServer until the plug-in is reinstalled.", comment: "")
                    alert.runModal()
                }
            }
        }
    }
}
