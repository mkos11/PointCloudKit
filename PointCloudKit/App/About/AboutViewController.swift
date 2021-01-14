//
//  AboutViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 29/12/2020.
//

import Foundation
import UIKit

final class AboutViewController: UIViewController {
    private let viewModel = AboutViewModel()
    
    let btcAdress = "35qmxVALkJFvyycJpeNk9rXZ2o2RXQTnfP"
    let ethAdress = "0xe60A29283577Be7843Beb2886fC762603492a89b"

    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { false }

    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool { false }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    @IBAction func didTapBtcDonateButton(_ sender: Any) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = btcAdress
    }
    
    @IBAction func didTapEthDonateButton(_ sender: Any) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = ethAdress
    }
    
    @IBAction func contactUsTapped() {
        guard let mailToUrl = viewModel.mailToUrl else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(mailToUrl)
        } else {
            UIApplication.shared.openURL(mailToUrl)
        }
    }
}
