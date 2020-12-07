//
//  AppDelegate.swift
//  Metra
//
//  Created by Alexandre Camilleri on 7/12/2020.
//

import UIKit
import ARKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

   var window: UIWindow?

   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
         // Ensure that the device supports scene depth and present
         //  an error-message view controller, if not.
         let storyboard = UIStoryboard(name: "Main", bundle: nil)
         window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
      }
      return true
   }

}

