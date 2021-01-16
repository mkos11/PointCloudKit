//
//  AppDelegate.swift
//  Metra
//
//  Created by Alexandre Camilleri on 7/12/2020.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initializeUserDefaults()
        return true
    }

    private func initializeUserDefaults() {
        //weak
        if UserDefaults.standard.integer(forKey: "numGridPoints") == 0 {
            UserDefaults.standard.set(Constants.Renderer.defaultNumGridPoints, forKey: "numGridPoints")
            UserDefaults.standard.set(Constants.Renderer.defaultConfidence, forKey: "confidence")
            UserDefaults.standard.set(Constants.Renderer.defaultRgbRadius, forKey: "rgbRadius")
            UserDefaults.standard.set(Constants.Renderer.defaultMaxPoints, forKey: "maxPoints")
            UserDefaults.standard.set(Constants.Renderer.defaultParticleSize, forKey: "defaultParticleSize")
        }
    }
}
