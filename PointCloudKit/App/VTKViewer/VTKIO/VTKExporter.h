//
//  VTKExporter.h
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 9/1/2021.
//

#import <Foundation/Foundation.h>

#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPolyData.h>

//////////////////////////////////////////////////////////////////////////////////
/// This block is a quick hack to emulate a switch on string in objc/c++
// Value-Defintions of the different String values
static enum SupportedExportType {
    polygon,
    visualisationToolKit,
    xyz,
    WavefrontObject,
    stereoLithography
};

@interface VTKExporter: NSObject

+ (int)writeTo:(NSString*)pathName
      polyData:(vtkSmartPointer<vtkPolyData>)polyData
          type:(const SupportedExportType)type
        binary:(const bool)binary;

@end

