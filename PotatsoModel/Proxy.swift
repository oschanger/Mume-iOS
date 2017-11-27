//
//  Proxy.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import CloudKit

public enum ProxyType: String {
    case Shadowsocks = "Shadowsocks"
    case ShadowsocksR = "ShadowsocksR"
    case Https = "HTTPS"
    case Socks5 = "SOCKS5"
    case None = "NONE"
}

extension ProxyType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }

    public var isShadowsocks: Bool {
        return self == .Shadowsocks || self == .ShadowsocksR
    }
    
}

public enum ProxyError: Error {
    case InvalidType
    case InvalidName
    case InvalidHost
    case InvalidPort
    case InvalidAuthScheme
    case NameAlreadyExists
    case InvalidUri
    case InvalidPassword
}

extension ProxyError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidType:
            return "Invalid type"
        case .InvalidName:
            return "Invalid name"
        case .InvalidHost:
            return "Invalid host"
        case .InvalidAuthScheme:
            return "Invalid encryption"
        case .InvalidUri:
            return "Invalid uri"
        case .NameAlreadyExists:
            return "Name already exists"
        case .InvalidPassword:
            return "Invalid password"
        case .InvalidPort:
            return "Invalid port"
        }
    }
    
}

public class Proxy: BaseModel {
    @objc public dynamic var typeRaw = ProxyType.Shadowsocks.rawValue
    @objc public dynamic var host = ""
    @objc public dynamic var port = 0
    @objc public dynamic var country = ""
    @objc public dynamic var authscheme: String?  // method in SS
    @objc public dynamic var user: String?
    @objc public dynamic var password: String?
    @objc public dynamic var ota: Bool = false
    @objc public dynamic var ssrProtocol: String?
    @objc public dynamic var ssrObfs: String?
    @objc public dynamic var ssrObfsParam: String?

    public static let ssUriPrefix = "ss://"
    public static let ssrUriPrefix = "ssr://"

    public static let ssrSupportedProtocol = [
        "origin",
        "verify_simple",
        "auth_simple",
        "auth_sha1",
        "auth_sha1_v2"
    ]

    public static let ssrSupportedObfs = [
        "plain",
        "http_simple",
        "tls1.0_session_auth",
        "tls1.2_ticket_auth"
    ]

    public static let ssSupportedEncryption = [
        "table",
        "rc4",
        "rc4-md5",
        "aes-128-cfb",
        "aes-192-cfb",
        "aes-256-cfb",
        "bf-cfb",
        "camellia-128-cfb",
        "camellia-192-cfb",
        "camellia-256-cfb",
        "cast5-cfb",
        "des-cfb",
        "idea-cfb",
        "rc2-cfb",
        "seed-cfb",
        "salsa20",
        "chacha20",
        "chacha20-ietf"
    ]

    public override static func indexedProperties() -> [String] {
        return ["host","port"]
    }

    public override func validate() throws {
        guard let _ = ProxyType(rawValue: typeRaw)else {
            throw ProxyError.InvalidType
        }
        guard host.count > 0 else {
            throw ProxyError.InvalidHost
        }
        guard port > 0 && port <= Int(UINT16_MAX) else {
            throw ProxyError.InvalidPort
        }
        switch type {
        case .Shadowsocks, .ShadowsocksR:
            guard let _ = authscheme else {
                throw ProxyError.InvalidAuthScheme
            }
        default:
            break
        }
    }

}

// Public Accessor
extension Proxy {
    
    public var type: ProxyType {
        get {
            return ProxyType(rawValue: typeRaw) ?? .Shadowsocks
        }
        set(v) {
            typeRaw = v.rawValue
        }
    }
    
    public var uri: String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme, let password = password {
                return "ss://\(authscheme):\(password)@\(host):\(port)"
            }
        case .Socks5:
            if let _ = user, let password = password {
                return "socks5://\(String(describing: authscheme)):\(password)@\(host):\(port)"
            }
            return "socks5://\(host):\(port)" // TODO: support username/password
        default:
            break
        }
        return ""
    }
    public override var description: String {
        return String.init(format: "%@:%d", host, port)
    }
    
}

// Import
extension Proxy {
    
    public convenience init(dictionary: [String: AnyObject]) throws {
        self.init()
        if let uriString = dictionary["uri"] as? String {
            if uriString.lowercased().hasPrefix(Proxy.ssUriPrefix) {
                // Shadowsocks
                let start = uriString.index(uriString.startIndex, offsetBy: Proxy.ssUriPrefix.count)
                let undecodedString = "\(uriString[start...])"
                guard let proxyString = base64DecodeIfNeeded(proxyString: undecodedString)?.replacingOccurrences(of: "\n", with: ""), let _ = proxyString.range(of: ":")?.lowerBound else {
                    throw ProxyError.InvalidUri
                }
                guard let pc1 = proxyString.range(of: ":")?.lowerBound, let pc2 = proxyString.range(of: ":", options: .backwards)?.lowerBound, let pcm = proxyString.range(of: "@", options: .backwards)?.lowerBound else {
                    throw ProxyError.InvalidUri
                }
                if !(pc1 < pcm && pcm < pc2) {
                    throw ProxyError.InvalidUri
                }
                let fullAuthscheme = "\(proxyString.lowercased()[..<pc1])"
                if let pOTA = fullAuthscheme.range(of :"-auth", options: .backwards)?.lowerBound {
                    self.authscheme = "\(fullAuthscheme[...pOTA])"
                    self.ota = true
                }else {
                    self.authscheme = fullAuthscheme
                }
                let pc1_successor = proxyString.index(pc1, offsetBy: 1)
                let pc2_successor = proxyString.index(pc2, offsetBy: 1)
                let pcm_successor = proxyString.index(pcm, offsetBy: 1)

                self.password = "\(proxyString[pc1_successor..<pcm])"
                self.host = "\(proxyString[pcm_successor..<pc2])"
                guard let p = Int("\(proxyString[pc2_successor...])") else {
                    throw ProxyError.InvalidPort
                }
                self.port = p
                self.type = .Shadowsocks
            }else if uriString.lowercased().hasPrefix(Proxy.ssrUriPrefix) {
                let start = uriString.index(uriString.startIndex, offsetBy: Proxy.ssrUriPrefix.count)
                let undecodedString = "\(uriString[start...])"
                guard let proxyString = base64DecodeIfNeeded(proxyString: undecodedString), let _ =
                    proxyString.range(of: ":")?.lowerBound else {
                    //proxyString.rangeOfString(":")?.startIndex else {
                    throw ProxyError.InvalidUri
                }
                var hostString: String = proxyString
                var queryString: String = ""

                if let queryMarkIndex = proxyString.range(of: "?", options: .backwards)?.lowerBound {
                    hostString = "\(proxyString[...queryMarkIndex])"
                    let queryMarkIndex_successor = proxyString.index(queryMarkIndex, offsetBy: 1)
                    queryString = "\(proxyString[queryMarkIndex_successor...])"
                }
                if let hostSlashIndex = hostString.range(of: "/", options: .backwards)?.lowerBound {
                    hostString = "\(hostString[..<hostSlashIndex])"
                }
                let hostComps = hostString.components(separatedBy: ":")
                guard hostComps.count == 6 else {
                    throw ProxyError.InvalidUri
                }
                self.host = hostComps[0]
                guard let p = Int(hostComps[1]) else {
                    throw ProxyError.InvalidPort
                }
                self.port = p
                self.ssrProtocol = hostComps[2]
                self.authscheme = hostComps[3]
                self.ssrObfs = hostComps[4]
                self.password = base64DecodeIfNeeded(proxyString: hostComps[5])
                for queryComp in queryString.components(separatedBy: "&") {
                    let comps = queryComp.components(separatedBy: "=")
                    guard comps.count == 2 else {
                        continue
                    }
                    switch comps[0] {
                    case "obfsparam":
                        self.ssrObfsParam = comps[1]
                    default:
                        continue
                    }
                }
                self.type = .ShadowsocksR
            }else {
                // Not supported yet
                throw ProxyError.InvalidUri
            }
        } else {
            guard let host = dictionary["host"] as? String else{
                throw ProxyError.InvalidHost
            }
            guard let typeRaw = (dictionary["type"] as? String)?.uppercased(), let type = ProxyType(rawValue: typeRaw) else{
                throw ProxyError.InvalidType
            }
            guard let portStr = (dictionary["port"] as? String), let port = Int(portStr) else{
                throw ProxyError.InvalidPort
            }
            guard let encryption = dictionary["encryption"] as? String else{
                throw ProxyError.InvalidAuthScheme
            }
            guard let password = dictionary["password"] as? String else{
                throw ProxyError.InvalidPassword
            }
            self.host = host
            self.port = port
            self.password = password
            self.authscheme = encryption
            self.type = type
        }
        getCountry()
        try validate()
    }
    
    private func getCountry() -> String {
        
    }
    
    private func getHostIP() -> String {
        if self.host.count > 0 {
            let host = CFHostCreateWithName(nil,self.host as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
                let theAddress = addresses.firstObject as? NSData {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    print(numAddress)
                    return numAddress
                }
            }
        }
        return self.host
    }

    private func base64DecodeIfNeeded(proxyString: String) -> String? {
        if let _ = proxyString.range(of: ":")?.lowerBound {
            return proxyString
        }
        let base64String = proxyString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64String.count + (base64String.count % 4 != 0 ? (4 - base64String.count % 4) : 0)
        if let decodedData = NSData(base64Encoded:base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData as Data, encoding: String.Encoding.utf8.rawValue) {
            return decodedString as String
        }
        return nil
    }

    public class func uriIsShadowsocks(uri: String) -> Bool {
        return uri.lowercased().hasPrefix(Proxy.ssUriPrefix) || uri.lowercased().hasPrefix(Proxy.ssrUriPrefix)
    }

}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}
