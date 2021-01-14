//
//  VTKPointsProcessors.h
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 11/01/2021.
//

#import <Foundation/Foundation.h>

#include <vtk/vtkActor.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPolyData.h>
#include <vtk/vtkSphereSource.h>
#include <vtk/vtkAlgorithm.h>
#include <vtk/vtkPolyDataAlgorithm.h>

#include <vtk/vtkDataSetMapper.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkOpenGLGlyph3DMapper.h>

#include <vtk/vtkStatisticalOutlierRemoval.h>

#include <vtk/vtkMaskPoints.h>

@interface VTKPointsProcessors : NSObject

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)glyphingWith:(double)sphereRadius
                                       inputAlgorithm:(vtkAlgorithm*)inputAlgorithm;
+ (vtkSmartPointer<vtkPolyDataAlgorithm>)maskingWithRatio:(int)ratio
                                          inputAlgorithm:(vtkAlgorithm*)inputAlgorithm;
+ (vtkSmartPointer<vtkPolyDataAlgorithm>)statisticalOutlierRemovalWithSampleSize:(int)sampleSize
                                                                  inputAlgorithm:(vtkAlgorithm*)inputAlgorithm;

@end
