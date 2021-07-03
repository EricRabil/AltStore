//
//  ALTLoginAlert.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit

private let ALTTextFieldWidth = 300
private let ALTTextFieldHeight = 22
private let ALTTextFieldSize = NSSize(width: ALTTextFieldWidth, height: ALTTextFieldHeight)
private let ALTTextFieldFrame = NSRect(origin: .zero, size: ALTTextFieldSize)

private let ALTStackSize = NSSize(width: ALTTextFieldWidth, height: ALTTextFieldHeight * 2)

class ALTLoginAlert: NSAlert, NSTextFieldDelegate {
    let appleIDTextField = NSTextField(frame: ALTTextFieldFrame)
    let passwordTextField = NSSecureTextField(frame: ALTTextFieldFrame)
    
    let stackView = NSStackView(frame: NSRect(origin: .zero, size: ALTStackSize))
    
    override init() {
        super.init()
        
        // MARK: - AppleID Field
        appleIDTextField.translatesAutoresizingMaskIntoConstraints = false
        appleIDTextField.placeholderString = NSLocalizedString("Apple ID", comment: "")
        appleIDTextField.nextKeyView = passwordTextField
        appleIDTextField.delegate = self
        
        // MARK: - Password Field
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.placeholderString = NSLocalizedString("Password", comment: "")
        passwordTextField.delegate = self
        
        stackView.orientation = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 0
        stackView.addArrangedSubview(appleIDTextField)
        stackView.addArrangedSubview(passwordTextField)
        
        // MARK: - NSAlert Setup
        messageText = NSLocalizedString("Please enter your Apple ID and password.", comment: "")
        informativeText = NSLocalizedString("Your Apple ID and password are not saved and are only sent to Apple for authentication.", comment: "")
        window.initialFirstResponder = appleIDTextField
        accessoryView = stackView
        addButton(withTitle: NSLocalizedString("Install", comment: ""))
        addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
    }
    
    var appleID: String {
        appleIDTextField.stringValue
    }
    
    var password: String {
        passwordTextField.stringValue
    }
    
    func controlTextDidChange(_ obj: Notification) {
        self.validate()
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        self.validate()
    }
    
    func validate() {
        buttons.first?.isEnabled = !(appleID.isEmpty || password.isEmpty)
        layout()
    }
}
