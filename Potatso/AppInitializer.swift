//
//  AppInitilizer.swift
//  Potatso
//
//  Created by LEI on 12/27/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import Appirater
import Fabric

let appID = "1144787928"

class AppInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        configAppirater()
        #if !DEBUG
            Fabric.with([Answers.self, Crashlytics.self])
        #endif
        return true
    }

    func configAppirater() {
        Appirater.setAppId(appID)
    }
    
}
