//
//  VTKLoader.m
//  VTKViewer
//
//  Created by Alexis Girault on 11/17/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import "VTKLoader.h"
#include <time.h>

//#include <vtk/vtkPolyPointSource.h>
//#include <vtk/vtkPointSource.h>
#include <vtk/vtkDataSetMapper.h>
#include <vtk/vtkGenericDataObjectReader.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkRenderWindow.h>
#include <vtk/vtkRenderer.h>
#include <vtk/vtkOpenGLGlyph3DMapper.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkVertexGlyphFilter.h>

#include <vtk/vtkMinimalStandardRandomSequence.h>
#include <vtk/vtkPointSource.h>
#include <vtk/vtkSphereSource.h>
#include <vtk/vtkNamedColors.h>
#include <vtk/vtkCleanPolyData.h>

#include <vtk/vtkBYUReader.h>
#include <vtk/vtkOBJReader.h>
#include <vtk/vtkPLYReader.h>
#include <vtk/vtkPolyDataReader.h>
#include <vtk/vtkSTLReader.h>
#include <vtk/vtkXMLPolyDataReader.h>

#include <vtk/vtkVoxelGrid.h>
#include <vtk/vtkPointData.h>
#include <vtk/vtkSignedDistance.h>
#include <vtk/vtkExtractSurface.h>
#include <vtk/vtkPCANormalEstimation.h>

#include <vtk/vtkOpenGLPolyDataMapper.h>

#include "ShaderTypes.h"

#include <vtk/vtkArrayData.h>
#include <vtk/vtkDoubleArray.h>
#include <vtk/vtkFloatArray.h>
#include <vtk/vtkPolyVertex.h>
#include <vtk/vtkTypedArray.h>
#include <vtk/vtkUnsignedCharArray.h>

#include <vtk/vtkCellData.h>

#include <vtk/vtkStatisticalOutlierRemoval.h>
#include <vtk/vtkRadiusOutlierRemoval.h>

#include <vtk/vtkLookupTable.h>
#include <vtk/vtkColorSeries.h>

#include <vtk/vtkGaussianSplatter.h>
#include <vtk/vtkContourFilter.h>

#include <vtk/vtkSurfaceReconstructionFilter.h>
#include <vtk/vtkReverseSense.h>

#include <vtk/vtkTransform.h>
#include <vtk/vtkTransformPolyDataFilter.h>


@implementation VTKLoader

+ (vtkSmartPointer<vtkPolyData>)readPolyData:(NSURL*)url
{
    auto polyData = vtkSmartPointer<vtkPolyData>::New();
    // Setup file path
    const char* fileName = [[url path] UTF8String];
    NSString* extension = [[url lastPathComponent] pathExtension];
    
    if ([extension isEqual: @"ply"]) {
        vtkNew<vtkPLYReader> reader;
        reader->SetFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"vtp"]) {
        vtkNew<vtkXMLPolyDataReader> reader;
        reader->SetFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"vtk"]) {
        vtkNew<vtkPolyDataReader> reader;
        reader->SetFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"obj"]) {
        vtkNew<vtkOBJReader> reader;
        reader->SetFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"stl"]) {
        vtkNew<vtkSTLReader> reader;
        reader->SetFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"g"]) {
        vtkNew<vtkBYUReader> reader;
        reader->SetGeometryFileName(fileName);
        reader->Update();
        polyData = reader->GetOutput();
    } else {
        vtkNew<vtkMinimalStandardRandomSequence> randomSequence;
        randomSequence->SetSeed(8775070);
        
        vtkNew<vtkPointSource> points;
        points->SetNumberOfPoints(100000);
        points->SetRadius(10.0);
        double x, y, z;
        // random position
        x = randomSequence->GetRangeValue(-100, 100);
        randomSequence->Next();
        y = randomSequence->GetRangeValue(-100, 100);
        randomSequence->Next();
        z = randomSequence->GetRangeValue(-100, 100);
        randomSequence->Next();
        points->SetCenter(x, y, z);
        points->SetDistributionToShell();
        points->Update();
        polyData = points->GetOutput();
    }
    printf("\n Opened file - Number of points %d", polyData->GetNumberOfPoints());
    return polyData;
}

+ (vtkSmartPointer<vtkActor>)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    auto actor = vtkSmartPointer<vtkActor>::New();
    auto polyData = vtkSmartPointer<vtkPolyData>::New();
    
    auto points = vtkSmartPointer<vtkPoints>::New();
    points->SetNumberOfPoints(captureSize);
    
    auto colors = vtkSmartPointer<vtkUnsignedCharArray>::New();
    colors->SetName("colors");
    colors->SetNumberOfComponents(3);
    
    std::cout << "\n Loaded buffer - # of points in cloud " << captureSize << std::endl;
    clock_t tStart = clock();
    
    auto pointCloud = (ParticleUniforms *)particlesBuffer.contents;
    auto skipped = 0;
    for (int index = 0; index < captureSize; index++) {
        auto particleData = pointCloud[index];
        const auto confidence = particleData.confidence;
//        if (confidence < 0.0) // Float(confidenceThreshold) / 2.0 -- pass a parameter
//        {
//            skipped++;
//            continue;
//        }
        auto offsetedIndex = index - skipped;
        points->SetPoint(offsetedIndex,
                         particleData.position[0],
                         particleData.position[1],
                         particleData.position[2]);
        colors->InsertNextTuple3((uint)(particleData.color[0]*255),
                                 (uint)(particleData.color[1]*255),
                                 (uint)(particleData.color[2]*255));
    }
    
    std::cout << "    - # of points skipped (low confidence) " << skipped << " ";
    printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
    tStart = clock();
    
    points->Resize(captureSize - skipped);
    colors->Resize(captureSize - skipped);
    
    //////////////////////////////////////////////////////////////////////////////////////////
    polyData->GetPointData()->SetScalars(colors);
    
    polyData->SetPoints(points);
    
    std::cout << "STARTING WITH " << polyData->GetNumberOfPoints() << " points and " << polyData->GetPointData()->GetScalars()->GetNumberOfTuples() << " colors" << std::endl;
    
    ///////////////////////////////////////////////////////////////////////////////////////////
    
    /// Some calculus for 2 and  3
    double bounds[6];
    double range[3];
    polyData->GetBounds(bounds);
    for (int i = 0; i < 3; ++i) {
        range[i] = bounds[2 * i + 1] - bounds[2 * i];
    }
    std::cout << "    - Range: " << range[0] << ", " << range[1] << ", " << range[2] << std::endl;
    double maxRange = std::max(std::max(range[0], range[1]), range[2]);
    ////////////////////////////////////////////////////////////////////////////////////////
    
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
    
    /// Statistical Outlier removal =-------------------------------------------------------------
    std::cout << "Starting STATISTICAL OUTLIER REMOVAL..." << std::endl;
    auto statisticalRemoval = vtkSmartPointer<vtkStatisticalOutlierRemoval>::New(); //vtkStatistical also to test
                                                                                    //    statisticalRemoval->SetInputConnection(removal->GetOutputPort());
    statisticalRemoval->SetInputData(polyData);
    statisticalRemoval->SetSampleSize(80); // default 25, to speed up
    statisticalRemoval->Update();
    
    std::cout << "    - # of removed points: " << statisticalRemoval->GetNumberOfPointsRemoved() << std::endl;
    std::cout << "POLYDATA Now have " << statisticalRemoval->GetOutput()->GetNumberOfPoints() << " points and " << statisticalRemoval->GetOutput()->GetPointData()->GetScalars()->GetNumberOfTuples() << " colors " ;
    printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
    tStart = clock();
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
    
    /// GLYPHING --------------------------------------------------------------------------------------
        std::cout << "Starting GLYPHING (VTK Points to VTK Cells)..." << std::endl;
        double sphereRadius = maxRange * .001;
    
        auto sphereSource = vtkSmartPointer<vtkSphereSource>::New();
        sphereSource->SetPhiResolution(1);
        sphereSource->SetThetaResolution(1);
        sphereSource->SetRadius(sphereRadius);
    
        auto glyph3D = vtkSmartPointer<vtkGlyph3D>::New();
        glyph3D->SetInputConnection(statisticalRemoval->GetOutputPort());
        glyph3D->SetSourceConnection(sphereSource->GetOutputPort());
        glyph3D->SetColorModeToColorByScalar();
        glyph3D->ScalingOff();
        glyph3D->Update();
        std::cout << "DONE!";
        printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
        tStart = clock();
    /// -----------------------------------------------------------------------------------------------
    
    //    / CELL DOWNSAMPLING -----------------------------------------------------------------------------
        std::cout << "Starting CELL DOWNSAMPLING..." << std::endl;
        auto cleanPolyData = vtkSmartPointer<vtkCleanPolyData>::New();
        cleanPolyData->SetInputConnection(glyph3D->GetOutputPort());
        cleanPolyData->SetTolerance(0.00002);
        cleanPolyData->Update();
        std::cout << "POLYDATA Now have " << cleanPolyData->GetOutput()->GetNumberOfPoints() << " points and " << cleanPolyData->GetOutput()->GetPointData()->GetScalars()->GetNumberOfTuples() << " colors" ;
        printf("(Time: %.2fs)\n\n", (double)(clock() - tStart)/CLOCKS_PER_SEC);
        tStart = clock();
    //    / -----------------------------------------------------------------------------------------------
    
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
    
    // MAPPER
    auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
    mapper->SetInputConnection(cleanPolyData->GetOutputPort());
    
    // ACTOR
    actor->SetMapper(mapper);
    return actor;
}

+ (vtkSmartPointer<vtkActor>)loadFromURL:(NSURL*)url
{
    auto polyData = [self readPolyData:url];
    auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
    auto actor  = vtkSmartPointer<vtkActor>::New();
    auto colors = vtkSmartPointer<vtkNamedColors>::New();
    
    /// Check if point cloud or not
    if (polyData->GetNumberOfPolys() == 0 && polyData->GetNumberOfLines() == 0) {
        printf("\nIS POINT CLOUD");
        
        /// VOXEL FILTERING --------------------------------------------------------------------------
        auto voxelGrid = vtkSmartPointer<vtkVoxelGrid>::New();
        voxelGrid->SetInputData(polyData);
        voxelGrid->SetConfigurationStyleToAutomatic();
        voxelGrid->SetNumberOfPointsPerBin(0.01);
        voxelGrid->Update();
        
        auto cleanedPointCloudData = voxelGrid->GetOutput();
        printf("\nNumber of points after simplification %d", cleanedPointCloudData->GetNumberOfPoints());
        /// -----------------------------------------------------------------------------------------
        
        /// Some calculus for 2 and  3
        double bounds[6];
        cleanedPointCloudData->GetBounds(bounds);
        double range[3];
        for (int i = 0; i < 3; ++i)
        {
            range[i] = bounds[2 * i + 1] - bounds[2 * i];
        }
        std::cout << "\nRange: " << range[0] << ", " << range[1] << ", " << range[2] << std::endl;
        double maxRange = std::max(std::max(range[0], range[1]), range[2]);
        
        // use either 2 or 3
        
        //        /// (2) SURFACE RECONSTRUCTION --------------------------------------------------------------
        //        int sampleSize = cleanedPointCloudData->GetNumberOfPoints() * .00005;
        //        if (sampleSize < 10)
        //        {
        //            sampleSize = 10;
        //        }
        //        std::cout << "Sample size is: " << sampleSize << std::endl;
        //        // Do we need to estimate normals?
        //        vtkSmartPointer<vtkSignedDistance> distance =
        //        vtkSmartPointer<vtkSignedDistance>::New();
        //        if (polyData->GetPointData()->GetNormals())
        //        {
        //            std::cout << "Using normals from input file" << std::endl;
        //            distance->SetInputData (polyData);
        //        }
        //        else
        //        {
        //            std::cout << "Estimating normals using PCANormalEstimation" << std::endl;
        //            vtkSmartPointer<vtkPCANormalEstimation> normals =
        //            vtkSmartPointer<vtkPCANormalEstimation>::New();
        //            normals->SetInputData (polyData);
        //            normals->SetSampleSize(sampleSize);
        //            normals->SetNormalOrientationToGraphTraversal();
        //            normals->FlipNormalsOn();
        //            distance->SetInputConnection (normals->GetOutputPort());
        //        }
        //
        //        int dimension = 256;
        //        double radius = maxRange / static_cast<double>(dimension) * 4; // ~4 voxels
        //
        //        std::cout << "Radius: " << radius << std::endl;
        //
        //        distance->SetRadius(radius);
        //        distance->SetDimensions(dimension, dimension, dimension);
        //        distance->SetBounds(
        //                            bounds[0] - range[0] * .1,
        //                            bounds[1] + range[0] * .1,
        //                            bounds[2] - range[1] * .1,
        //                            bounds[3] + range[1] * .1,
        //                            bounds[4] - range[2] * .1,
        //                            bounds[5] + range[2] * .1);
        //
        //        vtkSmartPointer<vtkExtractSurface> surface = vtkSmartPointer<vtkExtractSurface>::New();
        //        surface->SetInputConnection (distance->GetOutputPort());
        //        surface->SetRadius(radius * .99);
        //        surface->Update();
        //
        //        vtkNew<vtkOpenGLPolyDataMapper> polyDataMapper;
        //        polyDataMapper->SetInputConnection(surface->GetOutputPort());
        //
        //        vtkSmartPointer<vtkProperty> back = vtkSmartPointer<vtkProperty>::New();
        //        back->SetColor(colors->GetColor3d("banana").GetData());
        //
        //        actor->SetMapper(polyDataMapper);
        //        actor->SetBackfaceProperty(back);
        //        return actor;
        //        /// -----------------------------------------------------------------------------------------
        
        
        
        
        /// (3) GENERATE CELLS from POINTS ------------------------------------------------------------
        // Convert points to spheres
        double sphereRadius = maxRange * .001;
        
        vtkNew<vtkSphereSource> sphereSource;
        sphereSource->SetPhiResolution(5);
        sphereSource->SetThetaResolution(5);
        sphereSource->SetRadius(sphereRadius);
        
        vtkNew<vtkOpenGLGlyph3DMapper> glyph3DMapper;
        glyph3DMapper->SetInputData(cleanedPointCloudData);
        glyph3DMapper->SetSourceConnection(sphereSource->GetOutputPort());
        glyph3DMapper->SetProgressText("Rendering point cloud...");
        // Disable this to disable colors
        glyph3DMapper->ScalarVisibilityOn();
        glyph3DMapper->ScalingOff();
        glyph3DMapper->Update();
        
        actor->SetMapper(glyph3DMapper);
        return actor;
        /// -------------------------------------------------------------------------------------------
        
    }
    printf("\nIS 3d model");
    // Setup mapper
    mapper->SetInputData(polyData);
    actor->SetMapper(mapper);
    actor->GetProperty()->SetColor(colors->GetColor3d("Banana").GetData());
    return actor;
}

+ (vtkSmartPointer<vtkPolyData>)transform_back:(vtkSmartPointer<vtkPoints>)pt data:(vtkSmartPointer<vtkPolyData>)pd
{
    // The reconstructed surface is transformed back to where the
    // original points are. (Hopefully) it is only a similarity
    // transformation.
    
    // 1. Get bounding box of pt, get its minimum corner (left, bottom, least-z), at c0, pt_bounds
    
    // 2. Get bounding box of surface pd, get its minimum corner (left, bottom, least-z), at c1, pd_bounds
    
    // 3. compute scale as:
    //       scale = (pt_bounds[1] - pt_bounds[0])/(pd_bounds[1] - pd_bounds[0]);
    
    // 4. transform the surface by T := T(pt_bounds[0], [2], [4]).S(scale).T(-pd_bounds[0], -[2], -[4])
    
    
    
    // 1.
    double pt_bounds[6];  // (xmin,xmax, ymin,ymax, zmin,zmax)
    pt->GetBounds(pt_bounds);
    
    
    // 2.
    double pd_bounds[6];  // (xmin,xmax, ymin,ymax, zmin,zmax)
    pd->GetBounds(pd_bounds);
    
    //   // test, make sure it is isotropic
    //   std::cout<<(pt_bounds[1] - pt_bounds[0])/(pd_bounds[1] - pd_bounds[0])<<std::endl;
    //   std::cout<<(pt_bounds[3] - pt_bounds[2])/(pd_bounds[3] - pd_bounds[2])<<std::endl;
    //   std::cout<<(pt_bounds[5] - pt_bounds[4])/(pd_bounds[5] - pd_bounds[4])<<std::endl;
    //   // TEST
    
    
    // 3
    double scale = (pt_bounds[1] - pt_bounds[0])/(pd_bounds[1] - pd_bounds[0]);
    
    
    // 4.
    auto transp = vtkSmartPointer<vtkTransform>::New();
    transp->Translate(pt_bounds[0], pt_bounds[2], pt_bounds[4]);
    transp->Scale(scale, scale, scale);
    transp->Translate(- pd_bounds[0], - pd_bounds[2], - pd_bounds[4]);
    
    auto tpd = vtkSmartPointer<vtkTransformPolyDataFilter>::New();
    
    tpd->SetInputData(pd);
    tpd->SetTransform(transp);
    tpd->Update();
    return tpd->GetOutput();
}

+ (BOOL)fileAtURL:(NSURL*)url matchesExtension:(NSArray<NSString*>*)validExtensions
{
    // Actual extension
    NSString* fileExt = [url pathExtension];
    
    // Check if one of the valid extensions
    for (NSString* validExt in validExtensions)
    {
        // Case insensitive comparison
        if ([fileExt caseInsensitiveCompare:validExt] == NSOrderedSame)
        {
            return YES;
        }
    }
    return NO;
}

@end
