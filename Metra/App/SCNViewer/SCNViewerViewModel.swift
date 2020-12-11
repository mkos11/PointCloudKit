//
//  SCNViewerViewModel.swift
//  Metra
//
//  Created by Alexandre Camilleri on 11/12/2020.
//

import Foundation

final class SCNViewerViewModel {
    let scnFileLocation: URL
    
    init(scnFileLocation: URL) {
        self.scnFileLocation = scnFileLocation
    }
}
