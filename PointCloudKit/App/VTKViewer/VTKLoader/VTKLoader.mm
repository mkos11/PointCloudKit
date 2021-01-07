//
//  VTKLoader.m
//  VTKViewer
//
//  Created by Alexis Girault on 11/17/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import "VTKLoader.h"

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
    printf("\nNumber of points %d", polyData->GetNumberOfPoints());
    return polyData;
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
        voxelGrid->SetProgressText("Voxel filtering...");
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
        // Disable this to enable colors?
        //        glyph3DMapper->ScalarVisibilityOff();
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
