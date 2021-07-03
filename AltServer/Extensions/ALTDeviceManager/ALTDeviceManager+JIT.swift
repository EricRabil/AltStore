//
//  ALTDeviceManager+JIT.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AppKit
import Combine

extension ALTDeviceManager {
    func enableJIT(for app: InstalledApp, on device: ALTDevice) {
        let _ = ALTDeviceManager.shared.prepare(device).flatMap {
            LegacyFuture {
                ALTDeviceManager.shared.startDebugConnection(to: device, completionHandler: $0)
            }
        }.flatMap { connection in
            LegacyFuture {
                connection!.enableUnsignedCodeExecutionForProcess(withName: app.executableName, completionHandler: $0)
            }
        }.receive(on: RunLoop.main).sink(receiveFailure: { err in
            AppDelegate.shared.showErrorAlert(error: err, localizedFailure: String(format: NSLocalizedString("JIT compilation could not be enabled for %@.", comment: ""), app.name))
        }, receiveValue: { _ in
            let alert = NSAlert()
            alert.messageText = String(format: NSLocalizedString("Successfully enabled JIT for %@.", comment: ""), app.name)
            alert.informativeText = String(format: NSLocalizedString("JIT will remain enabled until you quit the app. You can now disconnect %@ from your computer.", comment: ""), device.name)
            alert.runModal()
        })
    }
}
