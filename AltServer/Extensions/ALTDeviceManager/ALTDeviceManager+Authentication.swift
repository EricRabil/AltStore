//
//  ALTDeviceManager+Authentication.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import AppKit

extension ALTDeviceManager {
    func promptForVerificationCode(_ completionHandler: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Two-Factor Authentication Enabled", comment: "")
            alert.informativeText = NSLocalizedString("Please enter the 6-digit verification code that was sent to your Apple devices.", comment: "")
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.placeholderString = NSLocalizedString("123456", comment: "")
            alert.accessoryView = textField
            alert.window.initialFirstResponder = textField
            
            alert.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            
            self.securityCodeAlert = alert
            self.securityCodeTextField = textField
            self.validate()
            
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn
            {
                let code = textField.stringValue
                completionHandler(code)
            }
            else
            {
                completionHandler(nil)
            }
        }
    }
    
    func authenticate(appleID: String, password: String, anisetteData: ALTAnisetteData) -> Future<(ALTAccount, ALTAppleAPISession), Error>
    {
        Future { completionHandler in
            ALTAppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData, verificationHandler: self.promptForVerificationCode) { (account, session, error) in
                guard let account = account, let session = session else {
                    return completionHandler(.failure(error ?? ALTAppleAPIError(.unknown)))
                }
                
                completionHandler(.success((account, session)))
            }
        }
    }
}
