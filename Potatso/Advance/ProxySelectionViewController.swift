//
//  ProxySelectionViewController.swift
//  Potatso
//
//  Created by LEI on 3/10/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import Eureka
import PotatsoLibrary
import PotatsoModel

class ProxySelectionViewController: FormViewController {
    
    var proxies: [Proxy] = []
    var selectedProxies: NSMutableSet
    var callback: (([Proxy]) -> Void)?
    
    init(selectedProxies: [Proxy], callback: (([Proxy]) -> Void)?) {
        self.selectedProxies = NSMutableSet(array: selectedProxies)
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Choose Proxy".localized()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        generateForm()
    }

    func generateForm() {
        form.delegate = nil
        form.removeAll()
        proxies = defaultRealm.objects(Proxy.self).sorted(byKeyPath: "createAt").map{ $0 }
        form +++ Section("Proxy".localized())
        let sets = proxies.filter { $0.host != nil }
        for proxy in sets {
            form[0]
                <<< CheckRow(proxy.description) {
                    $0.title = proxy.description
                    $0.value = selectedProxies.contains(proxy)
            }.onChange({ [unowned self] (row) in
                self.selectProxy(selectedRow: row)
            })
        }
        form[0] <<< BaseButtonRow () {
            $0.title = "Add Proxy".localized()
        }.cellUpdate({ (cell, row) in
            cell.textLabel?.textColor = Color.Brand
        }).onCellSelection({ [unowned self] (cell, row) -> () in
            self.showProxyConfiguration(proxy: nil)
        })
        form.delegate = self
        tableView?.reloadData()
    }
    
    func selectProxy(selectedRow: CheckRow) {
        selectedProxies.removeAllObjects()
        let values = form.values()
        for proxy in proxies {
            if let checked = values[proxy.host] as? Bool, checked && proxy.description == selectedRow.title {
                selectedProxies.add(proxy)
            }
        }
        self.callback?(selectedProxies.allObjects as! [Proxy])
        close()
    }
    
    func showProxyConfiguration(proxy: Proxy?) {
        let vc = ProxyConfigurationViewController(upstreamProxy: proxy)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
