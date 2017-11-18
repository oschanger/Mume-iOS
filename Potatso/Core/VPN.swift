//
//  ProxyService.swift
//  Potatso
//
//  Created by LEI on 12/28/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import Appirater
import PotatsoLibrary

class VPN {
    
    static func switchVPN(group: ConfigurationGroup, completion: ((Error?) -> Void)? = nil) {
        let defaultUUID = VPNManager.sharedManager.defaultConfigGroup.uuid
        let isDefault = defaultUUID == group.uuid
        if !isDefault {
            VPNManager.sharedManager.stopVPN()
            Async.main(after: 1) {
                _switchDefaultVPN(group: group, completion: completion)
            }
        }else {
            _switchDefaultVPN(group: group, completion: completion)
        }
    }

    private static func _switchDefaultVPN(group: ConfigurationGroup, completion: ((Error?) -> Void)? = nil) {
        VPNManager.sharedManager.setDefaultConfigGroup(id: group.uuid, name: group.name)
        VPNManager.sharedManager.switchVPN { (manager, error) in
            if let _ = manager {
                Async.background(after: 2, { () -> Void in
                    Appirater.userDidSignificantEvent(false)
                })
            }
            Async.main{
                completion?(error)
            }
        }
    }
    
}
