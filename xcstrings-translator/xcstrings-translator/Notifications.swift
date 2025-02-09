//
//  Notifications.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 09/02/2025.
//

import Foundation

extension Notification {
    static let openFile = Notification.Name.init("openFile")
    static let translateFile = Notification.Name.init("translateFile")
    static let saveFile = Notification.Name.init("saveFile")
    static let reloadFile = Notification.Name.init("reloadFile")
    static let openAbout = Notification.Name.init("openAbout")
}
