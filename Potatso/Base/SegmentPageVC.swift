//
//  SegmentPageVC.swift
//  Potatso
//
//  Created by LEI on 7/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

class SegmentPageVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = segmentedControl
        showPage(index: 0)
    }

    func pageViewControllersForSegmentPageVC() -> [UIViewController] {
        fatalError()
    }

    func segmentsForSegmentPageVC() -> [String] {
        fatalError()
    }

    @objc func onSegmentedChanged(seg: UISegmentedControl) {
        showPage(index: seg.selectedSegmentIndex)
    }

    func showPage(index: Int) {
        segmentedControl.selectedSegmentIndex = index
        let pageViewControllers = pageViewControllersForSegmentPageVC()
        if index < pageViewControllers.count {
            pageVC.setViewControllers([pageViewControllers[index]], direction: .forward, animated: false, completion: nil)
        }
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        addChildVC(child: pageVC)
        setupAutoLayout()
    }

    func setupAutoLayout() {
        constrain(pageVC.view, view) { pageView, superview in
            pageView.edges == superview.edges
        }
    }

    lazy var pageVC: UIPageViewController = {
        let p = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        return p
    }()

    lazy var segmentedControl: UISegmentedControl = {
        let v = UISegmentedControl(items: self.segmentsForSegmentPageVC())
        v.addTarget(self, action: #selector(CollectionViewController.onSegmentedChanged(seg:)), for: .valueChanged)
        return v
    }()
    
}
