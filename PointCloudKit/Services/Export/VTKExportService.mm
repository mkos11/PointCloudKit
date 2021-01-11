//
//  VTKExportService.mm
//  PointCloudKit
//
//  Created by Alexandre Camilleri on 9/1/2021.
//

#import "VTKExportService.h"

#include <vtk/vtkActor.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkSmartPointer.h>

#include <vtk/vtkPLYWriter.h>
#include <vtk/vtkPolyDataWriter.h>

@interface VTKExportService ()

@end

@implementation VTKExportService

+ (const std::string)getVTKdataAsStringFrom:(vtkAlgorithmOutput*)output
{
    vtkSmartPointer<vtkPolyDataWriter> writer = vtkSmartPointer<vtkPolyDataWriter>::New();

    writer->SetInputConnection(output);
    writer->WriteToOutputStringOn();
    writer->Update();
    return writer->GetOutputString();
}

+ (const std::string&)getPLYdataAsStringFrom:(vtkAlgorithmOutput*)output
{
    vtkSmartPointer<vtkPLYWriter> writer = vtkSmartPointer<vtkPLYWriter>::New();
    writer->SetInputConnection(output);
//    writer->SetFileName(outputFileUrl.absoluteString.UTF8String);
    writer->WriteToOutputStringOn();
    writer->AddComment("author: PointCloudKit - Download at [https://apps.apple.com/us/app/pointcloudkit/id1546476130]");
    writer->Update();
    return writer->GetOutputString();
}

@end
