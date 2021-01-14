//
//  VTKLoader.m
//  VTKViewer
//
//  Created by Alexis Girault on 11/17/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import "VTKLoader.h"
#import "VTKPointsProcessors.h"
#include "ShaderTypes.h"

#include <time.h>

#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkPointData.h>
#include <vtk/vtkSphereSource.h>
#include <vtk/vtkNamedColors.h>

#include <vtk/vtkSimplePointsReader.h>
#include <vtk/vtkBYUReader.h>
#include <vtk/vtkOBJReader.h>
#include <vtk/vtkPLYReader.h>
#include <vtk/vtkPolyDataReader.h>
#include <vtk/vtkSTLReader.h>
#include <vtk/vtkXMLPolyDataReader.h>

#include <vtk/vtkUnsignedCharArray.h>

@implementation VTKLoader


+ (vtkSmartPointer<vtkPolyData>)readPolyData:(NSURL*)url
{
    // If no URL provided load default file
    if (url == nil) {
        url = [[NSBundle mainBundle] URLForResource:@"keyboard_capture" withExtension:@"ply"];
    }
    auto polyData = vtkSmartPointer<vtkPolyData>::New();
    auto fileNameCString = [url filePathURL].path.UTF8String;
    std::cout << " [+] Opening file at url " << fileNameCString << " ..." << std::endl;
    // Setup file path
    NSString* extension = [[url lastPathComponent] pathExtension];

    
    if ([extension isEqual: @"ply"]) {
        vtkNew<vtkPLYReader> reader;
        reader->SetFileName(fileNameCString);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"xyz"]) {
        vtkNew<vtkSimplePointsReader> reader;
        reader->SetFileName(fileNameCString);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"vtk"]) {
        vtkNew<vtkPolyDataReader> reader;
        reader->SetFileName(fileNameCString);
//        reader->SetReadAllScalars(1);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"obj"]) {
        vtkNew<vtkOBJReader> reader;
        reader->SetFileName(fileNameCString);
        reader->Update();
        polyData = reader->GetOutput();
    } else if ([extension isEqual: @"stl"]) {
        vtkNew<vtkSTLReader> reader;
        reader->SetFileName(fileNameCString);
        reader->Update();
        polyData = reader->GetOutput();
    }
#if DEBUG
    std::cout << " [+] Opened file - Number of points " << polyData->GetNumberOfPoints() << std::endl;
    std::cout << " [+]             - Number of verts " << polyData->GetNumberOfVerts() << std::endl;
    std::cout << " [+]             - Number of lines " << polyData->GetNumberOfLines() << std::endl;
    std::cout << " [+]             - Number of strips " << polyData->GetNumberOfStrips() << std::endl;
    std::cout << " [+]             - Number of pieces " << polyData->GetNumberOfPieces() << std::endl;
    std::cout << " [+]             - Number of polys " << polyData->GetNumberOfPolys() << std::endl;
    std::cout << " [+]             - Number of cells " << polyData->GetNumberOfCells() << std::endl;
#endif
    return polyData;
}

+ (vtkSmartPointer<vtkPolyData>)loadDefaultPointCloud
{
    return [self loadFromURL:nil];
}

+ (vtkSmartPointer<vtkPolyData>)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    auto polyData = vtkSmartPointer<vtkPolyData>::New();
    
    auto points = vtkSmartPointer<vtkPoints>::New();
    points->SetNumberOfPoints(captureSize);
    
    auto colors = vtkSmartPointer<vtkUnsignedCharArray>::New();
    colors->SetName("RGB");
    colors->SetNumberOfComponents(3);
    
    std::cout << " [*] Loaded buffer - # of points in cloud " << captureSize << std::endl;
    
    auto pointCloud = (ParticleUniforms *)particlesBuffer.contents;
    for (int index = 0; index < captureSize; index++) {
        auto particleData = pointCloud[index];
        auto offsetedIndex = index;
        points->SetPoint(offsetedIndex,
                         particleData.position[0],
                         particleData.position[1],
                         particleData.position[2]);
        colors->InsertNextTuple3((uint)abs(particleData.color[0]*255),
                                 (uint)abs(particleData.color[1]*255),
                                 (uint)abs(particleData.color[2]*255));
    }
    points->Resize(captureSize);
    colors->Resize(captureSize);
    polyData->GetPointData()->SetScalars(colors);
    polyData->SetPoints(points);
    return polyData;
}

+ (vtkSmartPointer<vtkPolyData>)loadFromURL:(NSURL*)url
{
    // Get the polyData from the file at URL
    return [self readPolyData:url];
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
