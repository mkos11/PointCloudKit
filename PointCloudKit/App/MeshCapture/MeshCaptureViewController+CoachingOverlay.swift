//
//  MeshCaptureViewController+CoachingOverlay.swift
//  Metra
//
//  Created by Alexandre Camilleri on 15/12/2020.
//

import UIKit
import ARKit

extension MeshCaptureViewController: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        hideMeshButton.isHidden = true
        resetButton.isHidden = true
        planeDetectionButton.isHidden = true
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        hideMeshButton.isHidden = false
        resetButton.isHidden = false
        planeDetectionButton.isHidden = false
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetButtonPressed(self)
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        #if !targetEnvironment(simulator)
        coachingOverlay.session = arView.session
        #endif
        coachingOverlay.delegate = self
        
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
            ])
    }
}
