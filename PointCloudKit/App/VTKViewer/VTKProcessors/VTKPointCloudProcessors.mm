//
//  VTKPointsProcessors.m
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 11/01/2021.
//

#import "VTKPointsProcessors.h"

#include <time.h>

@implementation VTKPointsProcessors

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)glyphingWith:(double)sphereRadius
                                       inputAlgorithm:(vtkAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "> Starting GLYPHING (VTK Points to VTK Cells)..." << std::endl;
    
    auto sphereSource = vtkSmartPointer<vtkSphereSource>::New();
    sphereSource->SetPhiResolution(1);
    sphereSource->SetThetaResolution(1);
    sphereSource->SetRadius(sphereRadius);
    
    auto glyph3D = vtkSmartPointer<vtkGlyph3D>::New();
    glyph3D->SetInputConnection(inputAlgorithm->GetOutputPort());
    glyph3D->SetSourceConnection(sphereSource->GetOutputPort());
    glyph3D->SetColorModeToColorByScalar();
    glyph3D->ScalingOff();
    glyph3D->Update();
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return glyph3D;
}

+ (vtkSmartPointer<vtkPolyDataAlgorithm>)statisticalOutlierRemovalWithSampleSize:(int)sampleSize
                                                                  inputAlgorithm:(vtkAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "> Starting STATISTICAL OUTLIER REMOVAL..." << std::endl;
//    std::cout << "   -- initial # of points: " << inputAlgorithm << std::endl;
    auto statisticalRemoval = vtkSmartPointer<vtkStatisticalOutlierRemoval>::New();
    statisticalRemoval->SetInputConnection(inputAlgorithm->GetOutputPort());
    statisticalRemoval->SetSampleSize(sampleSize); // default 25, lower faster
    statisticalRemoval->Update();
    
    std::cout << "   -- # of removed points: " << statisticalRemoval->GetNumberOfPointsRemoved() << std::endl;
    std::cout << "   -- # POLYDATA Now have " << statisticalRemoval->GetOutput()->GetNumberOfPoints() << " points" << std::endl;
    
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return statisticalRemoval;
}

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



/// Outlier removal =------------------------------------------------------------------------
//    std::cout << "Starting OUTLIER REMOVAL..." << std::endl;
//    auto removal = vtkSmartPointer<vtkRadiusOutlierRemoval>::New(); //vtkStatistical also to test
//    removal->SetInputData(polyData);
////    removal->SetRadius(range[0] / 10.0);
////    removal->SetNumberOfNeighbors(6);
//    //    removal->GenerateOutliersOn();
//    removal->Update();
//
//    std::cout << "    - # of removed points: " << removal->GetNumberOfPointsRemoved() << std::endl;
//    std::cout << "POLYDATA Now have " << removal->GetOutput()->GetNumberOfPoints() << " points and " << removal->GetOutput()->GetPointData()->GetScalars()->GetNumberOfTuples() << " colors " ;
//    printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
//    tStart = clock();
/// ------------------------------------------------------------------------------------------



/// VOXEL FILTERING -------------------------------------------------------------------------- Might need to be before the calculus part above
//        std::cout << "Starting VOXEL FILTERING..." << std::endl;
//        auto voxelGrid = vtkSmartPointer<vtkVoxelGrid>::New();
//        voxelGrid->SetInputConnection(statisticalRemoval->GetOutputPort());
//
//        voxelGrid->SetConfigurationStyleToLeafSize();
//        voxelGrid->SetLeafSize(0.05, 0.1, 0.1); // voxel of 1cm^3
//
//        voxelGrid->SetNumberOfPointsPerBin(1);
//        voxelGrid->Update();
//
//        std::cout << "# of points left: " << voxelGrid->GetOutput()->GetNumberOfPoints() << std::endl;
//        std::cout << "POLYDATA Now have " << voxelGrid->GetOutput()->GetNumberOfPoints() << " points and " << voxelGrid->GetOutput()->GetPointData()->GetScalars()->GetNumberOfTuples() << " colors" << std::endl;
/// -----------------------------------------------------------------------------------------


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


/// SURFACE RECONSTRUCTION ------------------------------------------------------------------------
//    std::cout << "Starting SURFACE RECONSTRUCT..." << std::endl;
//    auto namedColor = vtkSmartPointer<vtkNamedColors>::New();
////    int sampleSize = statisticalRemoval->GetOutput()->GetNumberOfPoints() * .00005;
////    if (sampleSize < 10) {
////        sampleSize = 10;
////    }
////    std::cout << "    - Sample size is: " << sampleSize << std::endl;
//    // Do we need to estimate normals?
//    auto distance = vtkSmartPointer<vtkSignedDistance>::New();
//    //    if (cleanPolyData->GetOutput()-> ->GetNormals()) {
//    //        std::cout << "Using normals from input file" << std::endl;
//    //        distance->SetInputData(cleanPolyData);
//    //    }
//    //    else {
//    std::cout << "    - Estimating normals using PCANormalEstimation" << std::endl;
//    auto normals = vtkSmartPointer<vtkPCANormalEstimation>::New();
//    normals->SetInputConnection(statisticalRemoval->GetOutputPort());
//    //        normals->SetInputData(cleanPolyData->GetOutput());
//    normals->SetSampleSize(20);
//    normals->SetNormalOrientationToPoint();// GraphTraversal(); // EXPENSSIVe but best results
//                                           //        normals->FlipNormalsOn();
//    distance->SetInputConnection(normals->GetOutputPort());
//    //    }
//
//    int dimension = 512;
//    double radius = maxRange / static_cast<double>(dimension) * 3; // ~3 voxels
//
//    std::cout << "    -  Radius: " << radius << std::endl;
//
//    distance->SetRadius(radius);
//    distance->SetDimensions(dimension, dimension, dimension);
//    distance->SetBounds(
//                        bounds[0] - range[0] * .1,
//                        bounds[1] + range[0] * .1,
//                        bounds[2] - range[1] * .1,
//                        bounds[3] + range[1] * .1,
//                        bounds[4] - range[2] * .1,
//                        bounds[5] + range[2] * .1);
//
//    auto surface = vtkSmartPointer<vtkExtractSurface>::New();
//    surface->SetInputConnection (distance->GetOutputPort());
//    surface->SetRadius(radius * .99);
//    surface->HoleFillingOn();
//    surface->Update();
//
//    vtkSmartPointer<vtkProperty> back = vtkSmartPointer<vtkProperty>::New();
//    back->SetColor(namedColor->GetColor3d("banana").GetData());
//
//    actor->SetBackfaceProperty(back);
//    std::cout << "DONE!" << std::endl;
//    printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
/// -----------------------------------------------------------------------------------------

@end
