//
//  UIViewController+.swift
//  Metra
//
//  Created by Alexandre Camilleri on 30/12/2020.
//

import UIKit
import ARKit

extension UIViewController {
    func assertSceneDepthSupport() {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            // Ensure that the device supports scene depth and present
            //  an error-message view controller, if not.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let unsupportedDeviceViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
            navigationController?.present(unsupportedDeviceViewController, animated: true, completion: nil)
        }
    }
}
