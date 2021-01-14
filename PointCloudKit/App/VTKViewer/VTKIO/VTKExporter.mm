//
//  VTKExporter.mm
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 9/1/2021.
//

#import "VTKExporter.h"

#include <vtk/vtkActor.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkPolyDataAlgorithm.h>
#include <vtk/vtkXMLPolyDataWriter.h>
#include <vtk/vtkWriter.h>
#include <vtk/vtkDataWriter.h>
#include <vtk/vtkPLYWriter.h>
#include <vtk/vtkPolyDataWriter.h>
#include <vtk/vtkSimplePointsWriter.h>
#include <vtk/vtkOBJWriter.h>
#include <vtk/vtkSTLWriter.h>
#include <vtk/vtkBYUWriter.h>

@interface VTKExporter ()

@end

@implementation VTKExporter

+ (int)writeTo:(NSString*)pathName polyData:(vtkSmartPointer<vtkPolyData>)polyData type:(const SupportedExportType)type binary:(const bool)binary
{
    vtkSmartPointer<vtkWriter> writer;
    
    std::cout << "Number of points being EXPORTED " << polyData->GetNumberOfPoints() << std::endl;
    std::cout << "Number of poly being EXPORTED " << polyData->GetNumberOfPolys() << std::endl;
    std::cout << "Number of line being EXPORTED " << polyData->GetNumberOfLines() << std::endl;
    std::cout << "Number of vet being EXPORTED " << polyData->GetNumberOfVerts() << std::endl;
    std::cout << "Number of cells being EXPORTED " << polyData->GetNumberOfCells() << std::endl;
    
    switch (type) {
        case SupportedExportType::polygon: {
            auto plyWriter = vtkSmartPointer<vtkPLYWriter>::New();
            plyWriter->SetFileName(pathName.UTF8String);
            plyWriter->SetInputData(polyData);
            plyWriter->SetArrayName("RGB");
            plyWriter->AddComment("author: PointCloudKit - Download at [https://apps.apple.com/us/app/pointcloudkit/id1546476130]");
            if (binary == true) {
                plyWriter->SetFileTypeToBinary();
            } else {
                plyWriter->SetFileTypeToASCII();
            }
            writer = plyWriter;
            break;
        }
        case SupportedExportType::visualisationToolKit: {
            auto vtkWriter = vtkSmartPointer<vtkPolyDataWriter>::New();
            vtkWriter->SetFileName(pathName.UTF8String);
            vtkWriter->SetInputData(polyData);
            if (binary) {
                vtkWriter->SetFileTypeToBinary();
            } else {
                vtkWriter->SetFileTypeToASCII();
            }
            writer = vtkWriter;
            break;
        }
        case SupportedExportType::xyz: {
            auto vtkXyzWriter = vtkSmartPointer<vtkSimplePointsWriter>::New();
            vtkXyzWriter->SetFileName(pathName.UTF8String);
            vtkXyzWriter->SetInputData(polyData);
            writer = vtkXyzWriter;
            break;
        }
        case SupportedExportType::WavefrontObject: {
            auto writer = vtkSmartPointer<vtkOBJWriter>::New();
            vtkSmartPointer<vtkOBJWriter> vtkObjWriter = vtkSmartPointer<vtkOBJWriter>::New();
            vtkObjWriter->SetFileName(pathName.UTF8String);
            vtkObjWriter->SetInputData(polyData);
            writer = vtkObjWriter;
            break;
        }
        case SupportedExportType::stereoLithography: { // No color
            vtkSmartPointer<vtkSTLWriter> vtkStlWriter = vtkSmartPointer<vtkSTLWriter>::New();
            vtkStlWriter->SetFileName(pathName.UTF8String);
            vtkStlWriter->SetInputData(polyData);
            if (binary) {
                vtkStlWriter->SetFileTypeToBinary();
            }
            writer = vtkStlWriter;
            break;
        }
        default: {
            break;
        }
    }
    writer->Update();
    return writer->Write();
}

@end
