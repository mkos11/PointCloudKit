//
//  Wrapper.cpp
//  Metra
//
//  Created by Alexandre Camilleri on 18/12/2020.
//

#include <string>
#include <stdio.h>

// extern "C" will cause the C++ compiler
// (remember, this is still C++ code!) to
// compile the function in such a way that
// it can be called from C
// (and Swift).
extern "C" int getIntFromCPP()
{
    // Create an instance of A, defined in
    // the library, and call getInt() on it:
    return 1234;
}

#include <vtk/vtkPolyData.h>
#include <vtk/vtkPLYReader.h>
#include <vtk/vtkPLYWriter.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPolyDataMapper.h>

#include <vtk/vtkNew.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkQuantizePolyDataPoints.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPointSource.h>
#include <vtk/vtkPoints.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkNew.h>
#include <vtk/vtkVertexGlyphFilter.h>

extern "C" int quantizePolyDataPoints(std::string inputFilename) {
    vtkSmartPointer<vtkPLYReader> reader = vtkSmartPointer<vtkPLYReader>::New();
    reader->SetFileName(inputFilename.c_str());

//    vtkSmartPointer<vtkPolyData> pointCloud = vtkSmartPointer<vtkPolyData>::New();
//
//    pointCloud->SetPoints(points);
  
    // Convert vertex to point in case of using point data instead of file?
//    vtkNew<vtkVertexGlyphFilter> vertexGlyphFilter;
//    vertexGlyphFilter->SetInputConnection(reader->GetOutputPort());
//    //    vertexGlyphFilter->AddInputData(polydata);
//    vertexGlyphFilter->Update();

    vtkNew<vtkQuantizePolyDataPoints> quantizeFilter;
    quantizeFilter->SetInputConnection(reader->GetOutputPort());
    quantizeFilter->SetQFactor(.1);
    quantizeFilter->Update();
    
    // Data if not writting back to file
//    vtkPolyData* quantized = quantizeFilter->GetOutput();

    
    vtkSmartPointer<vtkPLYWriter> plyWriter = vtkSmartPointer<vtkPLYWriter>::New();
    plyWriter->SetFileName(inputFilename.c_str());
    plyWriter->SetInputConnection(quantizeFilter->GetOutputPort());
    plyWriter->Write();
    
    return EXIT_SUCCESS;
}
