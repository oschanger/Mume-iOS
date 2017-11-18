//
//  BaseModel.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoBase
import CloudKit

private let version: UInt64 = 20
public var defaultRealm: Realm!

public func setupDefaultReaml() {
    var config = Realm.Configuration()
    let sharedURL = Potatso.sharedDatabaseUrl()
    
    config.fileURL = sharedURL
    config.schemaVersion = version
    config.migrationBlock = { migration, oldSchemaVersion in
        if oldSchemaVersion < 20 {
            // No migration yet
        }
    }
    Realm.Configuration.defaultConfiguration = config
    defaultRealm = try! Realm()
}


public class BaseModel: Object {
    @objc public dynamic var uuid = NSUUID().uuidString
    @objc public dynamic var createAt = NSDate().timeIntervalSince1970
    @objc public dynamic var updatedAt = NSDate().timeIntervalSince1970

    override public static func primaryKey() -> String? {
        return "uuid"
    }
    
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }

    public func validate() throws {
        //
    }

}

