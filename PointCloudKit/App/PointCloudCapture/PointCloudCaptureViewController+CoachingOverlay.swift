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
        viewModel.pauseCapture()
        viewModel.shouldShowUI.send(false)
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        viewModel.resumeCapture()
        viewModel.shouldShowUI.send(true)
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        viewModel.startRenderer(overridingCurrentSession: true)
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlayView.session = viewModel.session
        coachingOverlayView.delegate = self
        
        view.addSubview(coachingOverlayView)
        
        coachingOverlayView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.edges.equalToSuperview()
        }
    }
}
