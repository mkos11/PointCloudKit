//
//  AboutViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 26/12/2020.
//

import Foundation

final class AboutViewModel {
   private let email = "pointcloudkit@gmail.com"

   lazy var mailToUrl = URL(string: "mailto:\(email)")
}
