//
//  AppNavigationController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 15/12/2020.
//

import UIKit

final class AppNavigationController: UINavigationController {
    // Hide the status bar
    override var prefersStatusBarHidden: Bool { true }
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { false }
}
