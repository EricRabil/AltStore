//
//  AppDelegate+Errors.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit

extension AppDelegate {
    func showErrorAlert(error: Error, localizedFailure: String)
    {
        let nsError = error as NSError
        
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = localizedFailure
        
        var messageComponents = [String]()
        
        if let errorFailure = nsError.localizedFailure
        {
            if let failureReason = nsError.localizedFailureReason
            {
                if nsError.localizedDescription.starts(with: errorFailure)
                {
                    alert.messageText = errorFailure
                    messageComponents.append(failureReason)
                }
                else
                {
                    alert.messageText = errorFailure
                    messageComponents.append(nsError.localizedDescription)
                }
            }
            else
            {
                // No failure reason given.
                
                if nsError.localizedDescription.starts(with: errorFailure)
                {
                    // No need to duplicate errorFailure in both title and message.
                    alert.messageText = localizedFailure
                    messageComponents.append(nsError.localizedDescription)
                }
                else
                {
                    alert.messageText = errorFailure
                    messageComponents.append(nsError.localizedDescription)
                }
            }
        }
        else
        {
            alert.messageText = localizedFailure
            messageComponents.append(nsError.localizedDescription)
        }
        
        if let recoverySuggestion = nsError.localizedRecoverySuggestion
        {
            messageComponents.append(recoverySuggestion)
        }
        
        let informativeText = messageComponents.joined(separator: " ")
        alert.informativeText = informativeText
        
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)

        alert.runModal()
    }
}
