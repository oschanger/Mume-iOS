//
//  IndexViewController.swift
//  Potatso
//
//  Created by LEI on 5/27/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoLibrary
import PotatsoModel
import Eureka
import Cartography

private let kFormName = "name"
private let kFormDNS = "dns"
private let kFormProxies = "proxies"
private let kFormDefaultToProxy = "defaultToProxy"

class HomeVC: FormViewController, UINavigationControllerDelegate, HomePresenterProtocol, UITextFieldDelegate {

    let presenter = HomePresenter()
    var proxies: [Proxy] = []

    var ruleSetSection: Section!

    var status: VPNStatus {
        didSet(o) {
            updateConnectButton()
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.status = VPNManager.sharedManager.vpnStatus
        print ("HomeVC.init: ", self.status.rawValue)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        presenter.bindToVC(vc: self)
        presenter.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Fix a UI stuck bug
        navigationController?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.titleView = titleButton
        // Post an empty message so we could attach to packet tunnel process
        VPNManager.sharedManager.postMessage()
        //     @objc    handleRefres@objc hUI(nil)
        updateForm()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: "List".templateImage, style: .plain, target: presenter, action: #selector(HomePresenter.chooseConfigGroups))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addProxy(sender:)))
        startTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    @objc func addProxy(sender: AnyObject) {
        let alert = UIAlertController(title: "Add Proxy".localized(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Import From QRCode".localized(), style: .default, handler: { (action) in
            let importer = Importer(vc: self)
            importer.importConfigFromQRCode()
        }))
        alert.addAction(UIAlertAction(title: "Manual Settings".localized(), style: .default, handler: { (action) in
            let vc = ProxyConfigurationViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        if let presenter = alert.popoverPresentationController {
            if let rightBtn : View = navigationItem.rightBarButtonItem?.value(forKey: "view") as? View {
                presenter.sourceView = rightBtn
                presenter.sourceRect = rightBtn.bounds
            } else {
                presenter.sourceView = titleButton
                presenter.sourceRect = titleButton.bounds
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - HomePresenter Protocol

    func handleRefreshUI(error: Error?) {
        if presenter.group.isDefault {
            let vpnStatus = VPNManager.sharedManager.vpnStatus
            if status == .Connecting {
                if nil == error {
                    if vpnStatus == .Off {
                        return
                    }
                }
            }
            if status == .Disconnecting {
                if vpnStatus == .On {
                    return
                }
            }
            status = vpnStatus
        } else {
            status = .Off
        }
        updateTitle()
    }

    func updateTitle() {
        titleButton.setTitle(presenter.group.name, for: .normal)
        titleButton.sizeToFit()
    }

    func updateForm() {
        form.delegate = nil
        form.removeAll()

        
        form.delegate = nil
        form.removeAll()
        
        form +++ generateProxySection()

        let section = Section("Proxy".localized())
        proxies = DBUtils.allNotDeleted(type: Proxy.self, sorted: "createAt").map({ $0 })
        if proxies.count == 0 {
            section
                /*
                <<< ProxyRow() {
                    $0.value = nil
                    $0.cellStyle = UITableViewCellStyle.Subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .None
                        cell.accessoryType = .Checkmark
                    })
 */
        } else {
            if nil == self.presenter.proxy {
                try? ConfigurationGroup.changeProxy(forGroupId: self.presenter.group.uuid, proxyId: proxies[0].uuid)
            }
        
        for proxy in proxies {
            section
                /*
                <<< ProxyRow() {
                    $0.value = proxy
                    $0.cellStyle = UITableViewCellStyle.Subtitle
                    }.cellSetup({ (cell, row) -> () in
                        cell.selectionStyle = .None
                        if (self.presenter.proxy?.uuid == proxy.uuid) {
                            cell.accessoryType = .Checkmark
                        } else {
                            cell.accessoryType = .None
                        }
                    }).onCellSelection({ [unowned self] (cell, row) in
                        let proxy = row.value
                        do {
                            try ConfigurationGroup.changeProxy(forGroupId: self.presenter.group.uuid, proxyId: proxy?.uuid)
                            self.updateTitle()
                            self.updateForm()
                            //TODO: reconnect here
                        }catch {
                            self.showTextHUD("\("Fail to change proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
                        }
                        })
            */
        }
            }
        form +++ section
        
        form +++ generateRuleSetSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func updateConnectButton() {
        tableView?.reloadRows(at: [IndexPath.init(item: 0, section: 0)], with: .none)
        //tableView?.reloadRowsAtIndexPaths([IndexPath(forRow: 0, inSection: 0)], withRowAnimation: .None)
    }

    // MARK: - Form

    func generateProxySection() -> Section {
        let proxySection = Section("Connect".localized())
        var reloading = true

        proxySection <<< SwitchRow("connection") {
            reloading = true
            $0.title = status.hintDescription
            $0.value = status.onOrConnectiong
            reloading = false
            }.onChange({ [unowned self] (row) in
                if reloading {
                    return
                }
                self.handleConnectButtonPressed()
                })
            .cellUpdate ({ cell, row in
                reloading = true
                row.title = self.status.hintDescription
                row.value = self.status.onOrConnectiong
                reloading = false
            })
        <<< TextRow(kFormDNS) {
            $0.title = "DNS".localized()
            $0.value = presenter.group.dns
        }.cellSetup { cell, row in
            cell.textField.placeholder = "System DNS".localized()
            cell.textField.autocorrectionType = .no
            cell.textField.autocapitalizationType = .none
        }
        return proxySection
    }

    func generateRuleSetSection() -> Section {
        ruleSetSection = Section("Rule Set".localized())
        for ruleSet in presenter.group.ruleSets {
            ruleSetSection
                <<< LabelRow () {
                    $0.title = "\(ruleSet.name)"
                    var count = 0
                    if ruleSet.ruleCount > 0 {
                        count = ruleSet.ruleCount
                    } else {
                        count = ruleSet.rules.count
                    }
                    if count > 1 {
                        $0.value = String(format: "%d rules".localized(),  count)
                    }else {
                        $0.value = String(format: "%d rule".localized(), count)
                    }
                }.cellSetup({ (cell, row) -> () in
                    cell.selectionStyle = .none
                })
        }
        ruleSetSection <<< SwitchRow(kFormDefaultToProxy) {
            $0.title = "Default To Proxy".localized()
            $0.value = presenter.group.defaultToProxy
            $0.hidden = Condition.function([kFormProxies]) { [unowned self] form in
                return self.presenter.proxy == nil
            }
            }.onChange({ [unowned self] (row) in
                do {
                    try defaultRealm.write {
                        self.presenter.group.defaultToProxy = row.value ?? true
                    }
                }catch {
                    self.showTextHUD(text: "\("Fail to modify default to proxy".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
                }
                })
        ruleSetSection <<< BaseButtonRow () {
            $0.title = "Add Rule Set".localized()
        }.onCellSelection({ [unowned self] (cell, row) -> () in
            self.presenter.addRuleSet()
        })
        return ruleSetSection
    }


    // MARK: - Private Actions

    func handleConnectButtonPressed() {
        if status == .On {
            status = .Disconnecting
        }else {
            status = .Connecting
        }
        presenter.switchVPN()
    }

    @objc func handleTitleButtonPressed() {
        presenter.changeGroupName()
    }

    // MARK: - TableView

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.section == ruleSetSection.index && indexPath.row < presenter.group.ruleSets.count {
            return true
        }
        return false
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                try defaultRealm.write {
                    presenter.group.ruleSets.remove(at: indexPath.row)
                }
                form[indexPath].hidden = true
                form[indexPath].evaluateHidden()
            }catch {
                self.showTextHUD(text: "\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }

    // MARK: - TextRow

    override func textInputDidEndEditing<T>(_ textInput: UITextInput, cell: Cell<T>) {
        guard let textField = textInput as? UITextField else {
            return
        }
        guard let dnsString = textField.text, cell.row.tag == kFormDNS else {
            return
        }
        presenter.updateDNS(dnsString: dnsString)
        textField.text = presenter.group.dns
    }

    // MARK: - View Setup

    private let connectButtonHeight: CGFloat = 48

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
    }

    lazy var titleButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitleColor(UIColor.black, for: .normal)
        b.addTarget(self, action: #selector(HomeVC.handleTitleButtonPressed), for: .touchUpInside)
        if let titleLabel = b.titleLabel {
            titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabel.font.pointSize)
        }
        return b
    }()

    var timer: Timer?
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(onTime), userInfo: nil, repeats: true)
        timer?.fire()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func onTime() {
        updateConnectButton()
    }
}

extension VPNStatus {
    
    var color: UIColor {
        switch self {
        case .On, .Disconnecting:
            return Color.StatusOn
        case .Off, .Connecting:
            return Color.StatusOff
        }
    }

    var onOrConnectiong: Bool {
        switch self {
        case .On, .Connecting:
            return true
        case .Off, .Disconnecting:
            return false
        }
    }
    
    var hintDescription: String {
        switch self {
        case .On:
            if (Settings.shared().startTime) != nil {
                let flags = NSCalendar.Unit.init(rawValue: UInt.max)
                //let difference = NSCalendar.current.component(flags, from: time)
               // let difference = NSCalendar.current.dateComponents(flags, from: time, to: Date())
                //let difference = NSCalendar.currentCalendar.components(flags, fromDate: time, toDate: Date(), options: NSCalendar.Options.MatchFirst)
                let f = DateComponentsFormatter()
                f.unitsStyle = .abbreviated
                return "Connected".localized()
                //return  "Connected".localized() + " - " + f.stringFromDateComponents(difference)!
            }
            return "Connected".localized()
        case .Disconnecting:
            return "Disconnecting...".localized()
        case .Off:
            return "Off".localized()
        case .Connecting:
            return "Connecting...".localized()
        }
    }
}
