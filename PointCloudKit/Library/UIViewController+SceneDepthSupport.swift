//
//  UIViewController+SceneDepthSupport.swift
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 15/1/2021.
//

import ARKit

extension UIViewController {
    var supportsSceneDepthFrameSemantics: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
}
