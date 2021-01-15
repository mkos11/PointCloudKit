//
//  HomeViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 14/12/2020.
//

import UIKit

final class HomeViewController: UIViewController {
    // Hide the status bar
    override var prefersStatusBarHidden: Bool { true }
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        switch identifier {
        case "capturePoint", "captureMesh":
            if !supportsSceneDepthFrameSemantics {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let unsupportedDeviceViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
                navigationController?.setNavigationBarHidden(false, animated: true)
                navigationController?.show(unsupportedDeviceViewController, sender: nil)
                return false
            }
            fallthrough
        default:
            return true
        }
    }
}
