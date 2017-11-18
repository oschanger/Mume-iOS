//
//  UrlHandler.swift
//  Potatso
//
//  Created by LEI on 4/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import PotatsoLibrary
import Async
import CallbackURLKit


class UrlHandler: NSObject, AppLifeCycleProtocol {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        let manager = Manager.shared
        manager.callbackURLScheme = Manager.urlSchemes?.first
        for action in [URLAction.ON, URLAction.OFF, URLAction.SWITCH] {
            manager[action.rawValue] = { parameters, success, failure, cancel in
                action.perform(url: nil, parameters: parameters) { error in
                    Async.main(after: 1, {
                        if let error = error {
                            failure(error as NSError)
                        }else {
                            success(nil)
                        }
                    })
                    return
                }
            }
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var parameters: Parameters = [:]
        components?.queryItems?.forEach {
            guard let _ = $0.value else {
                return
            }
            parameters[$0.name] = $0.value
        }
        if let host = url.host {
            return dispatchAction(url: url, actionString: host, parameters: parameters)
        }
        return false
    }
    
    func dispatchAction(url: URL?, actionString: String, parameters: Parameters) -> Bool {
        guard let action = URLAction(rawValue: actionString) else {
            return false
        }
        return action.perform(url: url, parameters: parameters)
    }

}

enum URLAction: String {

    case ON = "on"
    case OFF = "off"
    case SWITCH = "switch"
    case XCALLBACK = "x-callback-url"

    func perform(url: URL?, parameters: Parameters, completion: ((Error?) -> Void)? = nil) -> Bool {
        switch self {
        case .ON:
            VPNManager.sharedManager.startVPN(complete: { (manager, error) in
                if error == nil {
                    self.autoClose(parameters: parameters)
                }
                completion?(error)
            })
        case .OFF:
            VPNManager.sharedManager.stopVPN()
            autoClose(parameters: parameters)
            completion?(nil)
        case .SWITCH:
            VPNManager.sharedManager.switchVPN(completion: { (manager, error) in
                if error == nil {
                    self.autoClose(parameters: parameters)
                }
                completion?(error)
            })
        case .XCALLBACK:
            if let url = url {
                return Manager.shared.handleOpen(url: url)
            }
        }
        return true
    }

    func autoClose(parameters: Parameters) {
        var autoclose = false
        if let value = parameters["autoclose"], value.lowercased() == "true" || value.lowercased() == "1" {
            autoclose = true
        }
        if autoclose {
            Async.main(after: 1, {
                UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
            })
        }
    }

}
