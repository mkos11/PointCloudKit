//
//  VTKPolyDataProcessors.m
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 12/01/2021.
//

#import "VTKPolyDataProcessors.h"

#include <time.h>

#include <vtk/vtkNamedColors.h>

@implementation VTKPolyDataProcessors

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)cleanPolyDataWithTolerance:(double)tolerance
                                                     inputAlgorithm:(vtkAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "> Starting CELL DOWNSAMPLING..." << std::endl;
    auto cleanPolyData = vtkSmartPointer<vtkCleanPolyData>::New();
    cleanPolyData->SetInputConnection(inputAlgorithm->GetOutputPort());
    cleanPolyData->SetTolerance(tolerance);
    cleanPolyData->Update();
    std::cout << "   -- # POLYDATA Now have " << cleanPolyData->GetOutput()->GetNumberOfPoints() << " points" << std::endl;
    
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return cleanPolyData;
}

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)surfaceReconstruction:(vtkPolyDataAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "Starting SURFACE RECONSTRUCT..." << std::endl;
    
    auto namedColor = vtkSmartPointer<vtkNamedColors>::New();
    int sampleSize = inputAlgorithm->GetOutput()->GetNumberOfPoints() * .00005;
    if (sampleSize < 10) {
        sampleSize = 10;
    }
    std::cout << "    - Sample size is: " << sampleSize << std::endl;
    // Do we need to estimate normals?
    auto distance = vtkSmartPointer<vtkSignedDistance>::New();
    //    if (inputAlgorithm->GetOutput()-> ->GetNormals()) {
    //        std::cout << "Using normals from input file" << std::endl;
    //        distance->SetInputData(cleanPolyData);
    //    }
    //    else {
    std::cout << "    - Estimating normals using PCANormalEstimation" << std::endl;
    auto normals = vtkSmartPointer<vtkPCANormalEstimation>::New();
    normals->SetInputConnection(inputAlgorithm->GetOutputPort());
    normals->SetSampleSize(sampleSize);
    normals->SetNormalOrientationToPoint();// GraphTraversal(); // EXPwENSSIVe but best results
    
    normals->FlipNormalsOn();
    distance->SetInputConnection(normals->GetOutputPort());
    //    }
    
    // Calculate Bounds and Range of PolyData
    double bounds[6];
    double range[3];
    inputAlgorithm->GetOutput()->GetBounds(bounds);
    for (int i = 0; i < 3; ++i) {
        range[i] = bounds[2 * i + 1] - bounds[2 * i];
    }
    auto maxRange = std::max(std::max(range[0], range[1]), range[2]);
    
    int dimension = 512;
    double radius = maxRange / static_cast<double>(dimension) * 3; // ~3 voxels
    
    std::cout << "    -  Radius: " << radius << std::endl;
    
    distance->SetRadius(radius);
    distance->SetDimensions(dimension, dimension, dimension);
    distance->SetBounds(
                        bounds[0] - range[0] * .1,
                        bounds[1] + range[0] * .1,
                        bounds[2] - range[1] * .1,
                        bounds[3] + range[1] * .1,
                        bounds[4] - range[2] * .1,
                        bounds[5] + range[2] * .1);
    
    auto surface = vtkSmartPointer<vtkExtractSurface>::New();
    surface->SetInputConnection (distance->GetOutputPort());
    surface->SetRadius(radius * .99);
    surface->HoleFillingOn();
    surface->Update();
    
    std::cout << "DONE!" << std::endl;
    std::cout << "(Time: %.2fs)\n\n" << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return surface;
}

// SEEMS to work well... but need a fucking clean input
//    auto surfaceGenerator = vtkSmartPointer<vtkSurfaceReconstructionFilter>::New();
//    surfaceGenerator->SetInputConnection(statisticalRemoval->GetOutputPort());
//    surfaceGenerator->Update();
//
//    auto contourFilter = vtkSmartPointer<vtkContourFilter>::New();
//    contourFilter->SetInputConnection(surfaceGenerator->GetOutputPort());
//    contourFilter->SetValue(0, 0.0);
//    contourFilter->Update();
//
//    auto reverse = vtkSmartPointer<vtkReverseSense>::New();
//
//    reverse->SetInputConnection(contourFilter->GetOutputPort());
//    reverse->ReverseCellsOn();
//    reverse->ReverseNormalsOn();
//    reverse->Update();
//
//    std::cout << reverse->GetOutput()->GetNumberOfCells() << std::endl;
//    std::cout << reverse->GetOutput()->GetNumberOfPoints() << std::endl;
//    auto newSurf = [self transform_back:statisticalRemoval->GetOutput()->GetPoints() data:reverse->GetOutput()];

@end
