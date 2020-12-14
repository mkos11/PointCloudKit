//
//  HomeViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 14/12/2020.
//

import UIKit

final class HomeViewController: UIViewController {
    // Hide the status bar
    override var prefersStatusBarHidden: Bool { false }
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
