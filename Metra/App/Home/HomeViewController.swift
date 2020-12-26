//
//  HomeViewController.swift
//  Metra
//
//  Created by Alexandre Camilleri on 14/12/2020.
//

import UIKit
import ARKit

final class HomeViewController: UIViewController {
   private let viewModel = HomeViewModel()

    // Hide the status bar
    override var prefersStatusBarHidden: Bool { false }
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

   override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
         // Ensure that the device supports scene depth and present
         //  an error-message view controller, if not.
         let storyboard = UIStoryboard(name: "Home", bundle: nil)
         let unsupportedDeviceViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
         present(unsupportedDeviceViewController, animated: true, completion: nil)
      }
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
