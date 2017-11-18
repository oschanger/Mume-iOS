//
//  HUDUtils.swift
//  Potatso
//
//  Created by LEI on 3/25/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import MBProgressHUD
import Async

private var hudKey = "hud"

extension UIViewController {
    
    func showProgreeHUD(text: String? = nil) {
        hideHUD()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .indeterminate
        hud.label.text = text!
    }
    
    func showTextHUD(text: String?, dismissAfterDelay: TimeInterval) {
        hideHUD()
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .text
        hud.detailsLabel.text = text!
        hideHUD(afterDelay: dismissAfterDelay)
    }
    
    func hideHUD() {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func hideHUD(afterDelay: TimeInterval) {
        Async.main(after: afterDelay) { 
            self.hideHUD()
        }
    }
    
}

