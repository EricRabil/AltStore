//
//  ALTDeviceManager+SecurityCode.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit

private var securityCodeAlertKey = 0
private var securityCodeTextFieldKey = 0

extension ALTDeviceManager: NSTextFieldDelegate
{
    var securityCodeAlert: NSAlert? {
        get { return objc_getAssociatedObject(self, &securityCodeAlertKey) as? NSAlert }
        set { objc_setAssociatedObject(self, &securityCodeAlertKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var securityCodeTextField: NSTextField? {
        get { return objc_getAssociatedObject(self, &securityCodeTextFieldKey) as? NSTextField }
        set { objc_setAssociatedObject(self, &securityCodeTextFieldKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func controlTextDidChange(_ obj: Notification)
    {
        self.validate()
    }
    
    public func controlTextDidEndEditing(_ obj: Notification)
    {
        self.validate()
    }
    
    func validate()
    {
        guard let code = self.securityCodeTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        if code.count == 6
        {
            self.securityCodeAlert?.buttons.first?.isEnabled = true
        }
        else
        {
            self.securityCodeAlert?.buttons.first?.isEnabled = false
        }
        
        self.securityCodeAlert?.layout()
    }
}
