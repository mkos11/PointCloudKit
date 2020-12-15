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
        pauseCapture()
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        resumeCapture()
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        restartSession()
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = session
        coachingOverlay.delegate = self
        
        view.addSubview(coachingOverlay)
        
        coachingOverlay.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.edges.equalToSuperview()
        }
    }
}
