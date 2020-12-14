//
//  PointCloudCaptureViewController+CoachingOverlay.swift
//  Metra
//
//  Created by Alexandre Camilleri on 14/12/2020.
//

import RealityKit
import ARKit

extension PointCloudCaptureViewController: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        renderer.isAccumulating = false
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        renderer.isAccumulating = true
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = session
        coachingOverlay.delegate = self
        
        coachingOverlay.setActive(true, animated: true)
        view.addSubview(coachingOverlay)
        
        coachingOverlay.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.edges.equalToSuperview()
        }
    }
}
