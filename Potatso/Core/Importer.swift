//
//  Importer.swift
//  Potatso
//
//  Created by LEI on 4/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import PotatsoLibrary

struct Importer {
    
    weak var viewController: UIViewController?
    
    init(vc: UIViewController) {
        self.viewController = vc
    }
    
    func importConfigFromUrl() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Import Config From URL".localized(), message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Input URL".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { (action) in
            if let input = urlTextField?.text {
                self.onImportInput(result: input)
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        viewController?.present(alert, animated: true, completion: nil)
    }
    
    func importConfigFromQRCode() {
        let vc = QRCodeScannerVC()
        vc?.resultBlock = { [weak vc] result in
            vc?.navigationController?.popViewController(animated: true)
            self.onImportInput(result: result!)
        }
        vc?.errorBlock = { [weak vc] error in
            vc?.navigationController?.popViewController(animated: true)
            self.viewController?.showTextHUD(text: "\(String(describing: error))", dismissAfterDelay: 1.5)
        }
        viewController?.navigationController?.pushViewController(vc!, animated: true)
    }
    
    func onImportInput(result: String) {
        if Proxy.uriIsShadowsocks(uri: result) {
            importSS(source: result)
        }else {
            importConfig(source: result, isURL: true)
        }
    }
    
    func importSS(source: String) {
        do {
            let proxy = try Proxy(dictionary: ["uri": source as AnyObject])
            do {
                try proxy.validate()
                try DBUtils.add(object: proxy)
                self.onConfigSaveCallback(success: true, error: nil)
            } catch {
                self.onConfigSaveCallback(success: false, error: error)
            }
        } catch {
            self.onConfigSaveCallback(success: false, error: error)
        }
    }
    
    func importConfig(source: String, isURL: Bool) {
        viewController?.showProgreeHUD(text: "Importing Config...".localized())
        Async.background(after: 1) {
            let config = Config()
            do {
                if isURL {
                    if let url = URL(string: source) {
                        try config.setup(url: url)
                    }
                }else {
                    try config.setup(string: source)
                }
                try config.save()
                self.onConfigSaveCallback(success: true, error: nil)
            }catch {
                self.onConfigSaveCallback(success: false, error: error)
            }
        }
    }
    
    func onConfigSaveCallback(success: Bool, error: Error?) {
        Async.main(after: 0.5) {
            self.viewController?.hideHUD()
            if !success {
                var errorDesc = ""
                if let error = error {
                    errorDesc = "(\(error))"
                }
                if let vc = self.viewController {
                    Alert.show(vc: vc, message: "\("Fail to save config.".localized()) \(errorDesc)")
                }
            }else {
                self.viewController?.showTextHUD(text: "Import Success".localized(), dismissAfterDelay: 1.5)
                let keyWindow = UIApplication.shared.keyWindow
                let tabBarVC:UITabBarController = (keyWindow?.rootViewController) as! UITabBarController
                tabBarVC.selectedIndex = 0
            }
        }
    }

}
