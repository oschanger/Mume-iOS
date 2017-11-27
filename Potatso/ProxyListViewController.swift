//
//  ProxyListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import Eureka
import MMDB_Swift

private let rowHeight: CGFloat = 107
private let kProxyCellIdentifier = "proxy"

class ProxyListViewController: FormViewController {

    var proxies: [Proxy?] = []
    var cloudProxies: [Proxy] = []

    let allowNone: Bool
    let chooseCallback: ((Proxy?) -> Void)?

    let db = MMDB()
    
    init(allowNone: Bool = false, chooseCallback: ((Proxy?) -> Void)? = nil) {
        self.chooseCallback = chooseCallback
        self.allowNone = allowNone
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        API.getProxySets() { (response) in
            for dic in response {
                if let proxy = try? Proxy(dictionary: dic as [String : AnyObject]) {
                    self.cloudProxies.append(proxy)
                }
            }
            self.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Proxy".localized()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        reloadData()
    }

    @objc func add() {
        let vc = ProxyConfigurationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func reloadData() {
        proxies = DBUtils.allNotDeleted(type: Proxy.self, sorted: "createAt").map({ $0 })
        if allowNone {
            proxies.insert(nil, at: 0)
        }
        form.delegate = nil
        form.removeAll()
        let section = self.cloudProxies.count > 0 ? Section("Local".localized()) : Section()
        for proxy in proxies {
            section
                <<< ProxyRow () {
                    $0.value = proxy
                    $0.cellStyle = UITableViewCellStyle.subtitle
                    if let country = db?.lookup((proxy?.host)!) {
                        print(country.isoCode)
                    }
                }.cellSetup({ (cell, row) -> () in
                    cell.accessoryType = .disclosureIndicator
                    cell.selectionStyle = .default
                }).onCellSelection({ [unowned self] (cell, row) in
                    cell.setSelected(false, animated: true)
                    let proxy = row.value
                    if let cb = self.chooseCallback {
                        cb(proxy)
                        self.close()
                    }else {
                        if proxy?.type != .none {
                            self.showProxyConfiguration(proxy: proxy)
                        }
                    }
                })
        }
        form +++ section
        
        if self.cloudProxies.count > 0 {
            let cloudSection = Section("Cloud".localized())
            for proxy in cloudProxies {
                cloudSection
                    <<< ProxyRow () {
                            $0.value = proxy
                        }.cellSetup({ (cell, row) -> () in
                            cell.accessoryType = .disclosureIndicator
                            cell.selectionStyle = .none
                        }).onCellSelection({ [weak self] (cell, row) in
                            cell.setSelected(false, animated: true)
                            let proxy = row.value
                            if let cb = self?.chooseCallback {
                                cb(proxy)
                                self?.close()
                            }else {
                                if proxy?.type != .none {
                                    let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
                                    vc.readOnly = true
                                    self?.navigationController?.pushViewController(vc, animated: true)
                                }
                            }
                        })
            }
            form +++ cloudSection
        }
        form.delegate = self
        tableView.setEditing(false, animated: false)
        tableView.reloadData()
    }

    func showProxyConfiguration(proxy: Proxy?) {
        let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if allowNone && indexPath.row == 0 {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if indexPath.section == 0 {
            return .delete
        }
        return .none
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard indexPath.row < proxies.count, let item = (form[indexPath] as? ProxyRow)?.value else {
                return
            }
            
            do {
                try DBUtils.hardDelete(id: item.uuid, type: Proxy.self)
                proxies.remove(at: indexPath.row)
                form[indexPath].hidden = true
                form[indexPath].evaluateHidden()
            }catch {
                self.showTextHUD(text: "\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView?.tableFooterView = UIView()
        tableView?.tableHeaderView = UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.01
    }
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }

}
