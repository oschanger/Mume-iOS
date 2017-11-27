//
//  API.swift
//  Potatso
//
//  Created by LEI on 6/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Alamofire
import ObjectMapper

struct API {

    static let URL = "https://api.liruqi.info/"

    enum Path {
        case RuleSets
        case RuleSet(String)

        var url: String {
            let path: String
            switch self {
            case .RuleSets:
                path = "mume-rulesets.php"
            case .RuleSet(let uuid):
                path = "ruleset/\(uuid).json"
            }
            return API.URL + path
        }
    }

    static func getRuleSets(callback: @escaping (DataResponse<String>) -> Void) {
        let lang = NSLocale.preferredLanguages[0]
        let versionCode: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
        NSLog("API.getRuleSets ===> lang: \(lang), version: \(String(describing: versionCode))")
        //Alamofire.request("https://raw.githubusercontent.com/h2y/Shadowrocket-ADBlock-Rules/master/sr_top500_banlist_ad.conf").responseData(completionHandler: callback)
        Alamofire.request("https://raw.githubusercontent.com/h2y/Shadowrocket-ADBlock-Rules/master/sr_top500_banlist_ad.conf").responseString(completionHandler: callback)
        //Alamofire.request(.GET, Path.RuleSets.url, parameters: ["lang": lang, "version": versionCode!]).responseArray(completionHandler: callback)
    }
    
    static func getProxySets(callback: ([Dictionary<String, String>]) -> Void) {
        let kCloudProxySets = "kCloudProxySets"
        let lang = NSLocale.preferredLanguages[0]
        let versionCode: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
        NSLog("API.getRuleSets ===> lang: \(lang), version: \(String(describing: versionCode))")
        
        if let data = Potatso.sharedUserDefaults().data(forKey: kCloudProxySets) {
            do {
                if let JSON = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String, String>] {
                    return callback(JSON)
                }
            } catch {
                print("Local deserialization failed")
            }
        }
        /*
        Alamofire.request(API.URL, method: , parameters: ["lang": lang, "version": versionCode!], encoding: .URLEncoding, headers: .defaultHTTPHeaders)
        //Alamofire.request(.GET, API.URL + "shadowsocks.php", parameters: ["lang": lang, "version": versionCode!])
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                Potatso.sharedUserDefaults().setObject(response.data, forKey: kCloudProxySets)
                if let JSON = response.result.value as? [Dictionary<String, String>] {
                    callback(JSON)
                }
        }
         */ 
    }
}

extension RuleSet: Mappable {

    public convenience init?(map: Map) {
        self.init()
        guard let rulesJSON = map.JSON["rules"] as? [AnyObject] else {
            return
        }
        var rules: [Rule] = []
        if let parsedObject = Mapper<Rule>().map(JSONObject: rulesJSON){
            rules.append(parsedObject)
        }
        self.rules = rules
    }

    // Mappable
    public func mapping(map: Map) {
        uuid      <- map["id"]
        name      <- map["name"]
        createAt <- map["created_at"]
        remoteUpdatedAt  <- map["updated_at"]
        desc      <- map["description"]
        ruleCount <- map["rule_count"]
        isOfficial <- map["is_official"]
    }
}

extension RuleSet {

    static func addRemoteObject(ruleset: RuleSet, update: Bool = true) throws {
        ruleset.isSubscribe = true
        ruleset.editable = false
        let id = ruleset.uuid
        guard let local = DBUtils.get(uuid: id, type: RuleSet.self) else {
            try DBUtils.add(object: ruleset)
            return
        }
        if local.remoteUpdatedAt == ruleset.remoteUpdatedAt {
            return
        }
        try DBUtils.add(object: ruleset)
    }

    static func addRemoteArray(rulesets: [RuleSet], update: Bool = true) throws {
        for ruleset in rulesets {
            try addRemoteObject(ruleset: ruleset, update: update)
        }
    }

}

extension Rule: Mappable {

    public convenience init?(map: Map) {
        guard let pattern = map.JSON["pattern"] as? String else {
            return nil
        }
        guard let actionStr = map.JSON["action"] as? String, let action = RuleAction(rawValue: actionStr) else {
            return nil
        }
        guard let typeStr = map.JSON["type"] as? String, let type = MMRuleType(rawValue: typeStr) else {
            return nil
        }
        self.init(type: type, action: action, value: pattern)
    }

    // Mappable
    public func mapping(map: Map) {
    }
}



struct DateTransform: TransformType {
    typealias Object = Double
    
    typealias JSON = String
    
    func transformFromJSON(_ value: Any?) -> Double? {
        guard let dateStr = value as? String else {
            return NSDate().timeIntervalSince1970
        }
        if #available(iOS 10.0, *) {
            return ISO8601DateFormatter().date(from: dateStr)?.timeIntervalSince1970
        } else {
            // Fallback on earlier versions
            return nil
        }
    }

    func transformToJSON(_ value: Double?) -> String? {
        guard let v = value else {
            return nil
        }
        let date = Date(timeIntervalSince1970: v)
        if #available(iOS 10.0, *) {
            return ISO8601DateFormatter().string(from: date)
        } else {
            return nil
            // Fallback on earlier versions
        }
    }

}

extension Alamofire.Request {

    public static func ObjectMapperSerializer<T: Mappable>(keyPath: String?, mapToObject object: T? = nil) -> DataResponseSerializer<T> {
        return DataResponseSerializer { request, response, data, error in
            NSLog("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error: error!, request: request as NSURLRequest?, response: response)
                return .failure(error!)
            }
            
            guard let _ = data else {
                let error = AFError.responseSerializationFailed(reason: .inputDataNil)
                logError(error: error, request: request as NSURLRequest?, response: response)
                return .failure(error)
            }

            let result = Alamofire.Request.serializeResponseJSON(options: .allowFragments, response: response, data: data, error: error)
            var JSONToMap: AnyObject?
            if let keyPath = keyPath, keyPath.isEmpty == false {
                JSONToMap = nil
                print(keyPath)
            } else {
                JSONToMap = result.value as AnyObject
            }

            if let object = object {
                Mapper<T>().map(JSONObject: JSONToMap, toObject: object)
                return .success(object)
            } else if let parsedObject = Mapper<T>().map(JSONObject: JSONToMap){
                return .success(parsedObject)
            }

            let error = AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error!))
            logError(error: error, request: request as NSURLRequest?, response: response)
            return .failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue:             The queue on which the completion handler is dispatched.
     - parameter keyPath:           The key path where object mapping should be performed
     - parameter object:            An object to perform the mapping on to
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */

    /*
    public func responseObject<T: Mappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, mapToObject object: T? = nil, completionHandler: (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.Request.ObjectMapperSerializer(keyPath, mapToObject: object), completionHandler: completionHandler)
    }
 */

    /*
    public static func ObjectMapperArraySerializer<T: Mappable>(keyPath: String?) -> DataResponseSerializer<Any> {
        return ResponseSerializer { request, response, data, error in
            NSLog("Alamofire response ===> request: \(request.debugDescription), response: \(response.debugDescription)")
            guard error == nil else {
                logError(error!, request: request, response: response)
                return .Failure(error!)
            }

            guard let _ = data else {
                let error = AFError.responseSerializationFailed(reason: .inputDataNil)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            let JSONResponseSerializer = Alamofire.Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONResponseSerializer.serializeResponse(request, response, data, error)

            if let errorMessage = result.value?.valueForKeyPath("error_message") as? String {
                let error = Error.errorWithCode(.StatusCodeValidationFailed, failureReason: errorMessage)
                logError(error, request: request, response: response)
                return .Failure(error)
            }

            let JSONToMap: AnyObject?
            if let keyPath = keyPath, keyPath.isEmpty == false {
                JSONToMap = result.value?.valueForKeyPath(keyPath)
            } else {
                JSONToMap = result.value
            }

            if let parsedObject = Mapper<T>().mapArray(JSONToMap){
                return .Success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
            logError(error, request: request, response: response)
            return .Failure(error)
        }
    }*/

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue: The queue on which the completion handler is dispatched.
     - parameter keyPath: The key path where object mapping should be performed
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    /*
    public func responseArray<T: Mappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, completionHandler: Response<[T], NSError> -> Void) -> Self {
        return response(queue: queue, responseSerializer: Alamofire.Request.ObjectMapperArraySerializer(keyPath), completionHandler: completionHandler)
    }
     */

    private static func logError(error: Error, request: NSURLRequest?, response: URLResponse?) {
        NSLog("ObjectMapperSerializer failure: \(error), request: \(String(describing: request?.debugDescription)), response: \(response.debugDescription)")
    }
}
