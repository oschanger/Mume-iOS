//
//  DBUtils.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public class DBUtils {

    private static func currentRealm(realm: Realm?) -> Realm {
        var mRealm = realm
        if mRealm == nil {
            mRealm = try! Realm()
        }
        return mRealm!
    }

    public static func add(object: BaseModel, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm: realm)
        mRealm.beginWrite()
        if setModified {
            object.setModified()
        }
        mRealm.add(object, update: update)
        try mRealm.commitWrite()
    }

    public static func add<S: Sequence>(objects: S, update: Bool = true, setModified: Bool = true, inRealm realm: Realm? = nil) throws where S.Iterator.Element: BaseModel {
        let mRealm = currentRealm(realm: realm)
        mRealm.beginWrite()
        objects.forEach({
            if setModified {
                $0.setModified()
            }
        })
        mRealm.add(objects, update: update)
        try mRealm.commitWrite()
    }

    public static func hardDelete<T: BaseModel>(id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm: realm)
        guard let object: T = DBUtils.get(uuid: id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        mRealm.delete(object)
        try mRealm.commitWrite()
    }

    public static func hardDelete<T: BaseModel>(ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            //try hardDelete(id, type: type, inRealm: realm)
            try hardDelete(id: id, type: type, inRealm: realm)
        }
    }
}


// Query
extension DBUtils {

    public static func allNotDeleted<T: BaseModel>(type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> Results<T> {
        return all(type: type, filter: filter, sorted: sorted, inRealm: realm)
    }

    public static func all<T: BaseModel>(type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> Results<T> {
        let mRealm = currentRealm(realm: realm)
        var res = mRealm.objects(type)
        if let filter = filter {
            res = res.filter(filter)
        }
        if let sorted = sorted {
            res = res.sorted(byKeyPath: sorted)
        }
        return res
    }

    public static func get<T: BaseModel>(uuid: String, type: T.Type, filter: String? = nil, sorted: String? = nil, inRealm realm: Realm? = nil) -> T? {
        let mRealm = currentRealm(realm: realm)
        var mFilter = "uuid = '\(uuid)'"
        if let filter = filter {
            mFilter += " && " + filter
        }
        var res = mRealm.objects(type).filter(mFilter)
        if let sorted = sorted {
            res = res.sorted(byKeyPath: sorted)
        }
        return res.first
    }

    public static func modify<T: BaseModel>(type: T.Type, id: String, inRealm realm: Realm? = nil, modifyBlock: ((Realm, T) -> Error?)) throws {
        let mRealm = currentRealm(realm: realm)
        guard let object: T = DBUtils.get(uuid: id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        if let error = modifyBlock(mRealm, object) {
            throw error
        }
        do {
            try object.validate()
        }catch {
            mRealm.cancelWrite()
            throw error
        }
        object.setModified()
        try mRealm.commitWrite()
    }

}

// Sync
extension DBUtils {

    public static func allObjectsToSyncModified() -> [BaseModel] {
        let mRealm = currentRealm(realm: nil)
        let filter = ""
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        /*
        objects.appendContentsOf(proxies as [BaseModel])
        objects.appendContentsOf(rulesets as [BaseModel])
        objects.appendContentsOf(groups as [BaseModel])
         */
        return objects
    }

    public static func allObjectsToSyncDeleted() -> [BaseModel] {
        let mRealm = currentRealm(realm: nil)
        let filter = ""
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        /*
        objects.appendContentsOf(proxies as [BaseModel])
        objects.appendContentsOf(rulesets as [BaseModel])
        objects.appendContentsOf(groups as [BaseModel])
         */
        return objects
    }
}

// BaseModel API
extension BaseModel {

    func setModified() {
        updatedAt = NSDate().timeIntervalSince1970
    }

}


// Config Group API
extension ConfigurationGroup {

    public static func changeProxy(forGroupId groupId: String, proxyId: String?) throws {
        try DBUtils.modify(type: ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.proxies.removeAll()
            if let proxyId = proxyId, let proxy = DBUtils.get(uuid: proxyId, type: Proxy.self, inRealm: realm){
                group.proxies.append(proxy)
            }
            return nil
        }
    }

    public static func appendRuleSet(forGroupId groupId: String, rulesetId: String) throws {
        try DBUtils.modify(type: ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            if let ruleset = DBUtils.get(uuid: rulesetId, type: RuleSet.self, inRealm: realm) {
                group.ruleSets.append(ruleset)
            }
            return nil
        }
    }

    public static func changeDNS(forGroupId groupId: String, dns: String?) throws {
        try DBUtils.modify(type: ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.dns = dns ?? ""
            return nil
        }
    }

    public static func changeName(forGroupId groupId: String, name: String) throws {
        try DBUtils.modify(type: ConfigurationGroup.self, id: groupId) { (realm, group) -> Error? in
            group.name = name
            return nil
        }
    }

}

