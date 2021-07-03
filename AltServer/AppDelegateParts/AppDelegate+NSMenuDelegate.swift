//
//  AppDelegate+NSMenu.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit
import LaunchAtLogin

extension AppDelegate: NSMenuDelegate
{
    func menuWillOpen(_ menu: NSMenu)
    {
        guard menu == self.appMenu else { return }
        
        // Clear any cached _jitAppListMenuControllers.
        self._jitAppListMenuControllers.removeAll()

        self.connectedDevices = ALTDeviceManager.shared.availableDevices
        
        self.connectedDevicesMenuController.items = self.connectedDevices
        self.sideloadIPAConnectedDevicesMenuController.items = self.connectedDevices
        self.enableJITMenuController.items = self.connectedDevices

        self.launchAtLoginMenuItem.target = self
        self.launchAtLoginMenuItem.action = #selector(AppDelegate.toggleLaunchAtLogin(_:))
        self.launchAtLoginMenuItem.state = LaunchAtLogin.isEnabled ? .on : .off

        if self.pluginManager.isUpdateAvailable
        {
            self.installMailPluginMenuItem.title = NSLocalizedString("Update Mail Plug-in", comment: "")
        }
        else if self.pluginManager.isMailPluginInstalled
        {
            self.installMailPluginMenuItem.title = NSLocalizedString("Uninstall Mail Plug-in", comment: "")
        }
        else
        {
            self.installMailPluginMenuItem.title = NSLocalizedString("Install Mail Plug-in", comment: "")
        }
        self.installMailPluginMenuItem.target = self
        self.installMailPluginMenuItem.action = #selector(AppDelegate.handleInstallMailPluginMenuItem(_:))
        
        // Need to re-set this every time menu appears so we can refresh device app list.
        self.enableJITMenuController.submenuHandler = { [weak self] device in
            let submenu = NSMenu(title: NSLocalizedString("Sideloaded Apps", comment: ""))
            
            guard let `self` = self else { return submenu }

            let submenuController = MenuController<InstalledApp>(menu: submenu, items: [])
            submenuController.placeholder = NSLocalizedString("Loading...", comment: "")
            submenuController.action = { (appInfo) in
                ALTDeviceManager.shared.enableJIT(for: appInfo, on: device)
            }
            
            // Keep strong reference
            self._jitAppListMenuControllers.append(submenuController)

            ALTDeviceManager.shared.fetchInstalledApps(on: device) { (installedApps, error) in
                DispatchQueue.main.async {
                    guard let installedApps = installedApps else {
                        print("Failed to fetch installed apps from \(device).", error!)
                        submenuController.placeholder = error?.localizedDescription
                        return
                    }
                    
                    print("Fetched \(installedApps.count) apps for \(device).")
                    
                    let sortedApps = installedApps.sorted { (app1, app2) in
                        if app1.name == app2.name
                        {
                            return app1.bundleIdentifier < app2.bundleIdentifier
                        }
                        else
                        {
                            return app1.name < app2.name
                        }
                    }
                    
                    submenuController.items = sortedApps
                    
                    if submenuController.items.isEmpty
                    {
                        submenuController.placeholder = NSLocalizedString("No Sideloaded Apps", comment: "")
                    }
                }
            }

            return submenu
        }
    }
    
    func menuDidClose(_ menu: NSMenu)
    {
        // Clearing _jitAppListMenuControllers now prevents action handler from being called.
        // self._jitAppListMenuControllers = []
    }
    
    @objc func toggleLaunchAtLogin(_ item: NSMenuItem)
    {
        LaunchAtLogin.isEnabled.toggle()
    }
}
