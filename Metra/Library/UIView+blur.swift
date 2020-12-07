//
//  UIView+blur.swift
//  Metra
//
//  Created by Alexandre Camilleri on 07/12/2020.
//

import UIKit
import SnapKit

extension UIView {
    
    /// Add a transparency effect to the view - Only if user hasn't disabled them
    /// - Parameter style: The style of the blur effect, by default `.systemThinMaterial`
    func addBlurEffectView(style: UIBlurEffect.Style = .systemThinMaterial) {
        guard !UIAccessibility.isReduceTransparencyEnabled else { return }
        backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        addSubview(blurEffectView)
    }
}
