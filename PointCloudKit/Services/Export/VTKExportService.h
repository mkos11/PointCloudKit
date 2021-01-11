//
//  VTKExportService.h
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 9/1/2021.
//

#ifndef VTKExportService_h
#define VTKExportService_h

#import <Foundation/Foundation.h>

#include <vtk/vtkAlgorithmOutput.h>

@interface VTKExportService: NSObject

+ (const std::string)getVTKdataAsStringFrom:(vtkAlgorithmOutput*)output;
+ (const std::string&)getPLYdataAsStringFrom:(vtkAlgorithmOutput*)output;

@end

#endif /* VTKExportService_h */
