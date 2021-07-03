//
//  AppDelegate.swift
//  AltServer
//
//  Created by Riley Testut on 5/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Cocoa
import UserNotifications
import Combine
import AltSign

import LaunchAtLogin

extension ALTDevice: MenuDisplayable {}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate {
        NSApp.delegate as! AppDelegate
    }
    
    let pluginManager = PluginManager()
    
    var statusItem: NSStatusItem?
    
    var connectedDevices = [ALTDevice]()
    
    weak var authenticationAlert: NSAlert?
    
    @IBOutlet var appMenu: NSMenu!
    @IBOutlet var connectedDevicesMenu: NSMenu!
    @IBOutlet var sideloadIPAConnectedDevicesMenu: NSMenu!
    @IBOutlet var enableJITMenu: NSMenu!
    
    @IBOutlet var launchAtLoginMenuItem: NSMenuItem!
    @IBOutlet var installMailPluginMenuItem: NSMenuItem!
    
    weak var authenticationAppleIDTextField: NSTextField?
    weak var authenticationPasswordTextField: NSSecureTextField?
    
    var connectedDevicesMenuController: MenuController<ALTDevice>!
    var sideloadIPAConnectedDevicesMenuController: MenuController<ALTDevice>!
    var enableJITMenuController: MenuController<ALTDevice>!
    
    var _jitAppListMenuControllers = [AnyObject]()
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        UserDefaults.standard.registerDefaults()
        
        UNUserNotificationCenter.current().delegate = self
        
        ServerConnectionManager.shared.start()
        ALTDeviceManager.shared.start()
        
        let item = NSStatusBar.system.statusItem(withLength: -1)
        item.menu = self.appMenu
        item.button?.image = NSImage(named: "MenuBarIcon") 
        self.statusItem = item
        
        self.appMenu.delegate = self
        
        let placeholder = NSLocalizedString("No Connected Devices", comment: "")
        
        self.connectedDevicesMenuController = MenuController<ALTDevice>(menu: self.connectedDevicesMenu, items: [])
        self.connectedDevicesMenuController.placeholder = placeholder
        self.connectedDevicesMenuController.action = { [weak self] device in
            self?.installAltStore(to: device)
        }
        
        self.sideloadIPAConnectedDevicesMenuController = MenuController<ALTDevice>(menu: self.sideloadIPAConnectedDevicesMenu, items: [])
        self.sideloadIPAConnectedDevicesMenuController.placeholder = placeholder
        self.sideloadIPAConnectedDevicesMenuController.action = { [weak self] device in
            self?.sideloadIPA(to: device)
        }
        
        self.enableJITMenuController = MenuController<ALTDevice>(menu: self.enableJITMenu, items: [])
        self.enableJITMenuController.placeholder = placeholder
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { (success, error) in
            guard success else { return }
            
            if !UserDefaults.standard.didPresentInitialNotification
            {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("AltServer Running", comment: "")
                content.body = NSLocalizedString("AltServer runs in the background as a menu bar app listening for AltStore.", comment: "")
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
                
                UserDefaults.standard.didPresentInitialNotification = true
            }
        }
        
        if self.pluginManager.isUpdateAvailable
        {
            self.installMailPlugin()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Insert code here to tear down your application
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate
{
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .sound, .badge])
    }
}
