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
    @discardableResult
    func addBlurEffectView(style: UIBlurEffect.Style = .systemThinMaterial) -> UIVisualEffectView? {
        guard !UIAccessibility.isReduceTransparencyEnabled else {
            backgroundColor = .black
            return nil
        }
        let blurEffect = UIBlurEffect(style: style)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let blurView = UIVisualEffectView(effect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        
        backgroundColor = .clear
        addSubview(blurView)
        blurView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        blurView.contentView.addSubview(vibrancyView)
        vibrancyView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        return blurView
    }
}
