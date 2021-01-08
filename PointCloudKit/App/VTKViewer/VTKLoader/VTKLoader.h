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

@interface VTKLoader : NSObject

+ (vtkSmartPointer<vtkActor>)loadFromURL:(NSURL*)url;
+ (vtkSmartPointer<vtkActor>)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize;

@end
