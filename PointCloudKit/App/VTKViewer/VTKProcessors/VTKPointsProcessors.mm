//
//  VTKPointsProcessors.m
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 11/01/2021.
//

#import "VTKPointsProcessors.h"

#include <time.h>

/// These objects take polydata that contains points only
@implementation VTKPointsProcessors

// Takes points and return polydata
+ (vtkSmartPointer<vtkPolyDataAlgorithm>)glyphingWith:(double)sphereRadius
                                       inputAlgorithm:(vtkAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "> Starting GLYPHING (VTK Points to VTK Cells)..." << std::endl;
    
    auto sphereSource = vtkSmartPointer<vtkSphereSource>::New();
    sphereSource->SetPhiResolution(6);
    sphereSource->SetThetaResolution(6);
    sphereSource->SetRadius(sphereRadius);
    
    auto glyph3D = vtkSmartPointer<vtkGlyph3D>::New();
    glyph3D->SetInputConnection(inputAlgorithm->GetOutputPort());
    glyph3D->SetSourceConnection(sphereSource->GetOutputPort());
    glyph3D->SetColorModeToColorByScalar();
    glyph3D->ScalingOff();
    glyph3D->OrientOff();
    glyph3D->Update();
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return glyph3D;
}

// Mask points (generating vertices on or off)
+ (vtkSmartPointer<vtkPolyDataAlgorithm>)maskingWithRatio:(int)ratio
                                          inputAlgorithm:(vtkAlgorithm*)inputAlgorithm
{
    clock_t tStart = clock();
    std::cout << "> Starting masking points..." << std::endl;
    auto maskPoints = vtkSmartPointer<vtkMaskPoints>::New();
    maskPoints->SetInputConnection(inputAlgorithm->GetOutputPort());
//    maskPoints->SetGenerateVertices(true);
//    maskPoints->SetRandomMode(true);
//    maskPoints->SetRandomModeType(type);
    maskPoints->SetOnRatio(ratio);
    maskPoints->RandomModeOn();
    maskPoints->Update();
    std::cout << "   -- # POLYDATA now have " << maskPoints->GetOutput()->GetNumberOfPoints() << std::endl;
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return maskPoints;
}

/// Takes points and return points
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
    std::cout << "   -- # POLYDATA now have " << statisticalRemoval->GetOutput()->GetNumberOfPoints() << " points" << std::endl;
    
    std::cout << "  -< Completed in " << (double)(clock() - tStart) / CLOCKS_PER_SEC << std::endl;
    return statisticalRemoval;
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



@end
