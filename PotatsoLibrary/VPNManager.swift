//
//  Manager.swift
//  Potatso
//
//  Created by LEI on 4/7/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import PotatsoBase
import PotatsoModel
import RealmSwift
import KissXML
import NetworkExtension
import ICSMainFramework
import MMWormhole

public enum ManagerError: Error {
    case InvalidProvider
    case VPNStartFail
}

public enum VPNStatus : Int {
    case Off
    case Connecting
    case On
    case Disconnecting
}


public let kDefaultGroupIdentifier = "defaultGroup"
public let kDefaultGroupName = "defaultGroupName"
private let statusIdentifier = "status"
public let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"

public class VPNManager {
    
    public static let sharedManager = VPNManager()
    
    public private(set) var vpnStatus = VPNStatus.Off {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }
    
    public let wormhole = MMWormhole(applicationGroupIdentifier: sharedGroupIdentifier, optionalDirectory: "wormhole")

    var observerAdded: Bool = false
    
    public var defaultConfigGroup: ConfigurationGroup {
        return getDefaultConfigGroup()
    }

    public init() {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                self.updateVPNStatus(manager: manager)
                if self.vpnStatus == .On {
                    self.observerAdded = true
                    NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                        self.updateVPNStatus(manager: manager)
                        })
                }
            }
        }
    }
    
    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                    self.updateVPNStatus(manager: manager)
                })
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateVPNStatus(manager: NEVPNManager) {
        print("updateVPNStatus:", manager.connection.status.rawValue)
        switch manager.connection.status {
        case .connected:
            self.vpnStatus = .On
        case .connecting, .reasserting:
            self.vpnStatus = .Connecting
        case .disconnecting:
            self.vpnStatus = .Disconnecting
        case .disconnected, .invalid:
            self.vpnStatus = .Off
        }
    }

    public func switchVPN(completion: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        loadProviderManager { [unowned self] (manager) in
            if let manager = manager {
                self.updateVPNStatus(manager: manager)
            }
            let current = self.vpnStatus
            guard current != .Connecting && current != .Disconnecting else {
                return
            }
            if current == .Off {
                self.startVPN { (manager, error) -> Void in
                    completion?(manager, error)
                }
            }else {
                self.stopVPN()
                completion?(nil, nil)
            }

        }
    }
    
    public func switchVPNFromTodayWidget(context: NSExtensionContext) {
        if NSURL(string: "mume://switch") != nil {
            //context.op as URLenURL(url, completionHandler: nil)
        }
    }
    
    public func setup() {
        setupDefaultReaml()
        do {
            try copyGEOIPData()
        }catch{
            print("copyGEOIPData fail")
        }
        do {
            try copyTemplateData()
        }catch{
            print("copyTemplateData fail")
        }
    }

    func copyGEOIPData() throws {
        let toURL = Potatso.sharedUrl().appendingPathComponent("GeoLite2-Country.mmdb")

        guard let fromURL = Bundle.main.url(forResource: "GeoLite2-Country", withExtension: "mmdb") else {
            let MaxmindLastModifiedKey = "MaxmindLastModifiedKey"
            let lastM = Potatso.sharedUserDefaults().string(forKey: MaxmindLastModifiedKey) ?? "Tue, 20 Dec 2016 12:53:05 GMT"
            
            let url = NSURL(string: "https://mumevpn.com/ios/GeoLite2-Country.mmdb")
            let request = NSMutableURLRequest(url: url! as URL)
            request.setValue(lastM, forHTTPHeaderField: "If-Modified-Since")
            let task = URLSession.shared.dataTask(with: request as URLRequest) {data, response, error in
                guard let data = data, error == nil else {
                    print("Download GeoLite2-Country.mmdb error: " + (error?.localizedDescription ?? ""))
                    return
                }
                if let r = response as? HTTPURLResponse {
                    if (r.statusCode == 200 && data.count > 1024) {
                        //let result = data.write(toURL!, atomically: true)
                        let result = try? data.write(to: toURL)
                        if (result != nil) {
                            let thisM = r.allHeaderFields["Last-Modified"];
                            if let m = thisM {
                                Potatso.sharedUserDefaults().set(m, forKey: MaxmindLastModifiedKey)
                            }
                            print("writeToFile GeoLite2-Country.mmdb: OK")
                        } else {
                            print("writeToFile GeoLite2-Country.mmdb: failed")
                        }
                    } else {
                        print("Download GeoLite2-Country.mmdb no update maybe: " + (r.description))
                    }
                } else {
                    print("Download GeoLite2-Country.mmdb bad responese: " + (response?.description ?? ""))
                }
            }
            task.resume()
            return
        }
        if FileManager.default.fileExists(atPath: fromURL.path) {
            try FileManager.default.copyItem(at: fromURL, to: toURL)
        }
    }

    func copyTemplateData() throws {
        guard let bundleURL = Bundle.main.url(forResource: "template", withExtension: "bundle") else {
            return
        }
        let fm = FileManager.default
        let toDirectoryURL = Potatso.sharedUrl().appendingPathComponent("httptemplate")
        if !fm.fileExists(atPath: toDirectoryURL.path) {
            try fm.createDirectory(at: toDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        for file in try fm.contentsOfDirectory(atPath: bundleURL.path) {
            let destURL = toDirectoryURL.appendingPathComponent(file)
            let dataURL = bundleURL.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: dataURL.path) {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try fm.copyItem(at: dataURL, to: destURL)
            }
        }
    }

    private func getDefaultConfigGroup() -> ConfigurationGroup {
        if let groupUUID = Potatso.sharedUserDefaults().string(forKey: kDefaultGroupIdentifier), let group = DBUtils.get(uuid: groupUUID, type: ConfigurationGroup.self) {
            return group
        } else {
            var group: ConfigurationGroup
            if let g = DBUtils.allNotDeleted(type: ConfigurationGroup.self, sorted: "createAt").first {
                group = g
            }else {
                group = ConfigurationGroup()
                group.name = "Default".localized()
                do {
                    try DBUtils.add(object: group)
                }catch {
                    fatalError("Fail to generate default group")
                }
            }
            let uuid = group.uuid
            let name = group.name
            /*
            dispatch_async(DispatchQueue.global(), {
                self.setDefaultConfigGroup(id: uuid, name: name)
            })
 */
            DispatchQueue.global(qos: .userInitiated).async {
                self.setDefaultConfigGroup(id: uuid, name: name)
            }
            return group
        }
    }
    
    public func setDefaultConfigGroup(id: String, name: String) {
        do {
            try regenerateConfigFiles()
        } catch {

        }
        Potatso.sharedUserDefaults().set(id, forKey: kDefaultGroupIdentifier)
        Potatso.sharedUserDefaults().set(name, forKey: kDefaultGroupName)
        Potatso.sharedUserDefaults().synchronize()
    }
    
    public func regenerateConfigFiles() throws {
        try generateGeneralConfig()
        try generateShadowsocksConfig()
        try generateHttpProxyConfig()
    }

}

extension ConfigurationGroup {

    public var isDefault: Bool {
        let defaultUUID = VPNManager.sharedManager.defaultConfigGroup.uuid
        let isDefault = defaultUUID == uuid
        return isDefault
    }
    
}

extension VPNManager {
    
    var upstreamProxy: Proxy? {
        return defaultConfigGroup.proxies.first
    }
    
    var defaultToProxy: Bool {
        return upstreamProxy != nil && defaultConfigGroup.defaultToProxy
    }
    
    func generateGeneralConfig() throws {
        let confURL = Potatso.sharedGeneralConfUrl()
        let json: NSDictionary = ["dns": defaultConfigGroup.dns ]
        do {
            try json.jsonString()?.write(to: confURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("generateGeneralConfig error")
        }
    }
    
    func generateShadowsocksConfig() throws {
        let confURL = Potatso.sharedProxyConfUrl()
        let content = ""
        if let upstreamProxy = upstreamProxy {
            if upstreamProxy.type == .Shadowsocks || upstreamProxy.type == .ShadowsocksR {
                /*
                content = ["type": upstreamProxy.type.rawValue, "host": upstreamProxy.host, "port": upstreamProxy.port, "password": upstreamProxy.password ?? "", "authscheme": upstreamProxy.authscheme ?? "", "ota": upstreamProxy.ota, "protocol": upstreamProxy.ssrProtocol ?? "", "obfs": upstreamProxy.ssrObfs ?? "", "obfs_param": upstreamProxy.ssrObfsParam ?? ""].jsonString() ?? ""
 */
            } else if upstreamProxy.type == .Socks5 {
                /*
                content = ["type": upstreamProxy.type.rawValue, "host": upstreamProxy.host, "port": upstreamProxy.port, "password": upstreamProxy.password ?? "", "authscheme": upstreamProxy.authscheme ?? ""].jsonString() ?? ""
 */
            }
        }
        try content.write(to: confURL, atomically: true, encoding: String.Encoding.utf8)
    }
    
    func generateHttpProxyConfig() throws {
        let rootUrl = Potatso.sharedUrl()
        let confDirUrl = rootUrl.appendingPathComponent("httpconf")
        let templateDirPath = rootUrl.appendingPathComponent("httptemplate").path
        let temporaryDirPath = rootUrl.appendingPathComponent("httptemporary").path
        let logDir = rootUrl.appendingPathComponent("log").path
        let maxminddbPath = Potatso.sharedUrl().appendingPathComponent("GeoLite2-Country.mmdb").path
        let userActionUrl = confDirUrl.appendingPathComponent("potatso.action")
        for p in [confDirUrl.path, templateDirPath, temporaryDirPath, logDir] {
            if !FileManager.default.fileExists(atPath: p) {
                _ = try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
            }
        }
        var mainConf: [String: AnyObject] = [:]
        if let path = Bundle.main.path(forResource: "proxy", ofType: "plist"), let defaultConf = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            mainConf = defaultConf
        }
        mainConf["confdir"] = confDirUrl.path as AnyObject
        mainConf["templdir"] = templateDirPath as AnyObject
        mainConf["logdir"] = logDir as AnyObject
        mainConf["mmdbpath"] = maxminddbPath as AnyObject
        mainConf["global-mode"] = defaultToProxy as AnyObject
//        mainConf["debug"] = 1024+65536+1
        mainConf["debug"] = 131071 as AnyObject
        if LoggingLevel.currentLoggingLevel != .OFF {
            mainConf["logfile"] = privoxyLogFile as AnyObject
        }
        mainConf["actionsfile"] = userActionUrl.path as AnyObject
        mainConf["tolerate-pipelining"] = 1 as AnyObject
        let mainContent = mainConf.map { "\($0) \($1)"}.joined(separator: "\n")
        try mainContent.write(to: Potatso.sharedHttpProxyConfUrl(), atomically: true, encoding: String.Encoding.utf8)

        var actionContent: [String] = []
        var forwardURLRules: [String] = []
        var forwardIPRules: [String] = []
        var forwardGEOIPRules: [String] = []
        let rules = defaultConfigGroup.ruleSets.flatMap({ $0.rules })
        for rule in rules {
            
            switch rule.type {
            case .GeoIP:
                forwardGEOIPRules.append(rule.description)
            case .IPCIDR:
                forwardIPRules.append(rule.description)
            default:
                forwardURLRules.append(rule.description)
            }
        }

        if forwardURLRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardURLRules)
        }

        if forwardIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardIPRules)
        }

        if forwardGEOIPRules.count > 0 {
            actionContent.append("{+forward-rule}")
            actionContent.append(contentsOf: forwardGEOIPRules)
        }

        // DNS pollution
        actionContent.append("{+forward-rule}")
        actionContent.append(contentsOf: Pollution.dnsList.map({ "DNS-IP-CIDR, \($0)/32, PROXY" }))

        let userActionString = actionContent.joined(separator: "\n")
        try userActionString.write(toFile: userActionUrl.path, atomically: true, encoding: String.Encoding.utf8)
    }

}

extension VPNManager {
    
    public func isVPNStarted(complete: @escaping (Bool, NETunnelProviderManager?) -> Void) {
        loadProviderManager { (manager) -> Void in
            if let manager = manager {
                complete(manager.connection.status == .connected, manager)
            }else{
                complete(false, nil)
            }
        }
    }
    
    public func startVPN(complete: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        startVPNWithOptions(options: nil, complete: complete)
    }
    
    private func startVPNWithOptions(options: [String : NSObject]?, complete: ((NETunnelProviderManager?, Error?) -> Void)? = nil) {
        // regenerate config files
        do {
            try VPNManager.sharedManager.regenerateConfigFiles()
        }catch {
            complete?(nil, error)
            return
        }
        // Load provider
        loadAndCreateProviderManager { (manager, error) -> Void in
            if let error = error {
                complete?(nil, error)
            }else{
                guard let manager = manager else {
                    complete?(nil, ManagerError.InvalidProvider)
                    return
                }
                if manager.connection.status == .disconnected || manager.connection.status == .invalid {
                    do {
                        try manager.connection.startVPNTunnel(options: options)
                        self.addVPNStatusObserver()
                        complete?(manager, nil)
                    }catch {
                        complete?(nil, error)
                    }
                }else{
                    self.addVPNStatusObserver()
                    complete?(manager, nil)
                }
            }
        }
    }
    
    public func stopVPN() {
        // Stop provider
        loadProviderManager { (manager) -> Void in
            guard let manager = manager else {
                return
            }
            manager.connection.stopVPNTunnel()
        }
    }
    
    public func postMessage() {
        loadProviderManager { (manager) -> Void in
            if let session = manager?.connection as? NETunnelProviderSession,
                let message = "Hello".data(using: String.Encoding.utf8), manager?.connection.status != .invalid
            {
                do {
                    try session.sendProviderMessage(message) { response in
                        
                    }
                } catch {
                    print("Failed to send a message to the provider")
                }
            }
        }
    }
    
    private func loadAndCreateProviderManager(complete: @escaping (NETunnelProviderManager?, Error?) -> Void ) {
        NETunnelProviderManager.loadAllFromPreferences { [unowned self] (managers, error) -> Void in
            if let managers = managers {
                let manager: NETunnelProviderManager
                if managers.count > 0 {
                    manager = managers[0]
                }else{
                    manager = self.createProviderManager()
                }
                manager.isEnabled = true
                manager.localizedDescription = AppEnv.appName
                manager.protocolConfiguration?.serverAddress = AppEnv.appName
                manager.isOnDemandEnabled = true
                let quickStartRule = NEOnDemandRuleEvaluateConnection()
                quickStartRule.connectionRules = [NEEvaluateConnectionRule(matchDomains: ["connect.mume.vpn"], andAction: NEEvaluateConnectionRuleAction.connectIfNeeded)]
                manager.onDemandRules = [quickStartRule]
                manager.saveToPreferences(completionHandler: { (error) -> Void in
                    if let error = error {
                        print("Failed to saveToPreferencesWithCompletionHandler" + error.localizedDescription)
                        complete(nil, error)
                    }else{
                        print("Did saveToPreferencesWithCompletionHandler")
                        manager.loadFromPreferences(completionHandler: { (error) -> Void in
                            if let error = error {
                                complete(nil, error)
                            }else{
                                complete(manager, nil)
                            }
                        })
                    }
                })
            }else{
                complete(nil, error)
            }
        }
    }
    
    public func loadProviderManager(complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) -> Void in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }
    
    private func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        let p = NETunnelProviderProtocol()
        p.providerBundleIdentifier = "info.liruqi.potatso.tunnel"
        if let upstreamProxy = upstreamProxy, upstreamProxy.type == .Shadowsocks {
            p.providerConfiguration = ["host": upstreamProxy.host, "port": upstreamProxy.port]
            p.serverAddress = upstreamProxy.host
        }
        manager.protocolConfiguration = p
        return manager
    }
}

