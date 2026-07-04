//
//  Notifications.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 09/02/2025.
//

import Foundation

/// App-level notification names.
///
/// These names provide a lightweight command channel for menu items or future app
/// integrations that need to trigger the same actions as the main window controls.
extension Notification {
    /// Request to open a string catalog.
    static let openFile = Notification.Name.init("openFile")
    /// Request to start translation.
    static let translateFile = Notification.Name.init("translateFile")
    /// Request to save or export the current catalog.
    static let saveFile = Notification.Name.init("saveFile")
    /// Request to reload the current file.
    static let reloadFile = Notification.Name.init("reloadFile")
    /// Request to open the app's About surface.
    static let openAbout = Notification.Name.init("openAbout")
}
