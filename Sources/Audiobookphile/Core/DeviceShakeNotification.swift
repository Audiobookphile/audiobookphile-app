//
//  DeviceShakeNotification.swift
//  Audiobookphile
//
//  Motion shake detection support for iOS and cross-platform safe fallbacks.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation
#if !SKIP && os(iOS)
import UIKit

extension NSNotification.Name {
    public static let deviceDidShakeNotification = NSNotification.Name("Audiobookphile.deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShakeNotification, object: event)
        }
    }
}
#else
extension NSNotification.Name {
    public static let deviceDidShakeNotification = NSNotification.Name("Audiobookphile.deviceDidShakeNotification")
}
#endif

