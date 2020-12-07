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
    func addBlurEffectView(style: UIBlurEffect.Style = .systemUltraThinMaterialLight) -> UIVisualEffectView? {
        guard !UIAccessibility.isReduceTransparencyEnabled else {
            return nil
        }
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        backgroundColor = .clear
        addSubview(blurEffectView)
        blurEffectView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        return blurEffectView
    }
}
