//
//  VTKLoader.h
//  VTKViewer
//
//  Created by Alexis Girault on 11/17/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKIt.h>

#include <vtk/vtkActor.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPolyData.h>

@interface VTKLoader : NSObject

+ (vtkSmartPointer<vtkPolyData>)loadDefaultPointCloud;
+ (vtkSmartPointer<vtkPolyData>)loadFromURL:(NSURL*)url;
+ (vtkSmartPointer<vtkPolyData>)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize;

@end
