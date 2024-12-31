//
//  YPPermissionDeniedPopup.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 12/03/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

internal struct YPPermissionDeniedPopup {
    enum AlertType {
        case camera
        case photoLibrary
        
        func getMessage() -> String {
            switch self {
            case .camera:
                return YPConfig.wordings.permissionPopup.messageCamera
            case .photoLibrary:
                return YPConfig.wordings.permissionPopup.message
            }
        }
    }
    static func buildGoToSettingsAlert(alertType: AlertType, cancelBlock: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(title:
                                        YPConfig.wordings.permissionPopup.title,
                                      message: alertType.getMessage(),
                                      preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: YPConfig.wordings.permissionPopup.cancel,
                          style: UIAlertAction.Style.cancel,
                          handler: { _ in
                            cancelBlock()
                          }))
        alert.addAction(
            UIAlertAction(title: YPConfig.wordings.permissionPopup.grantPermission,
                          style: .default,
                          handler: { _ in
                            if #available(iOS 10.0, *) {
                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                            } else {
                                UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                          }))
        return alert
    }
}
