//
//  VTKPolyDataProcessors.h
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 12/01/2021.
//

#import <Foundation/Foundation.h>

#include <vtk/vtkActor.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPolyData.h>
#include <vtk/vtkAlgorithm.h>
#include <vtk/vtkPolyDataAlgorithm.h>

#include <vtk/vtkCleanPolyData.h>
#include <vtk/vtkSignedDistance.h>
#include <vtk/vtkPCANormalEstimation.h>
#include <vtk/vtkDoubleArray.h>
#include <vtk/vtkExtractSurface.h>
#include <vtk/vtkProperty.h>

@interface VTKPolyDataProcessors : NSObject

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)cleanPolyDataWithTolerance:(double)tolerance
                                                    inputAlgorithm:(vtkAlgorithm*)inputAlgorithm;
+ (vtkSmartPointer<vtkPolyDataAlgorithm>)surfaceReconstruction:(vtkPolyDataAlgorithm*)inputAlgorithm;

@end
