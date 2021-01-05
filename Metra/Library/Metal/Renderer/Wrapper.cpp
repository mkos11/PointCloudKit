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

#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPointSource.h>
#include <vtk/vtkPolyData.h>
#include <vtk/vtkCleanPolyData.h>
#include <vtk/vtkPolyDataMapper.h>


//extern "C" int simplify(vtkPointSource *pointSource, char *[])
//{
//        vtkSmartPointer<vtkPointSource> pointSource = vtkSmartPointer<vtkPointSource>::New();
//        pointSource->SetNumberOfPoints(1000);
//        pointSource->SetRadius(1.0);
//        pointSource->Update();
        
//        vtkSmartPointer<vtkCleanPolyData> cleanPolyData = vtkSmartPointer<vtkCleanPolyData>::New();
//        cleanPolyData->SetInputConnection(pointSource->GetOutputPort());
//        cleanPolyData->SetTolerance(0.1);
//        cleanPolyData->Update();
//
//        vtkSmartPointer<vtkPolyDataMapper> inputMapper = vtkSmartPointer<vtkPolyDataMapper>::New();
//        inputMapper->SetInputConnection(pointSource->GetOutputPort());
//        vtkSmartPointer<vtkActor> inputActor =
//        vtkSmartPointer<vtkActor>::New();
//        inputActor->SetMapper(inputMapper);
//
//        vtkSmartPointer<vtkPolyDataMapper> cleanedMapper = vtkSmartPointer<vtkPolyDataMapper>::New();
//        cleanedMapper->SetInputConnection(cleanPolyData->GetOutputPort());
//
//        vtkSmartPointer<vtkActor> cleanedActor = vtkSmartPointer<vtkActor>::New();
//        cleanedActor->SetMapper(cleanedMapper);
        
//        // There will be one render window
//        vtkSmartPointer<vtkRenderWindow> renderWindow =
//        vtkSmartPointer<vtkRenderWindow>::New();
//        renderWindow->SetSize(600, 300);
        
//        // And one interactor
//        vtkSmartPointer<vtkRenderWindowInteractor> interactor =
//        vtkSmartPointer<vtkRenderWindowInteractor>::New();
//        interactor->SetRenderWindow(renderWindow);
        
//        // Define viewport ranges
//        // (xmin, ymin, xmax, ymax)
//        double leftViewport[4] = {0.0, 0.0, 0.5, 1.0};
//        double rightViewport[4] = {0.5, 0.0, 1.0, 1.0};
//
//        // Setup both renderers
//        vtkSmartPointer<vtkRenderer> leftRenderer =
//        vtkSmartPointer<vtkRenderer>::New();
//        renderWindow->AddRenderer(leftRenderer);
//        leftRenderer->SetViewport(leftViewport);
//        leftRenderer->SetBackground(.6, .5, .4);
//
//        vtkSmartPointer<vtkRenderer> rightRenderer =
//        vtkSmartPointer<vtkRenderer>::New();
//        renderWindow->AddRenderer(rightRenderer);
//        rightRenderer->SetViewport(rightViewport);
//        rightRenderer->SetBackground(.4, .5, .6);
//
//        leftRenderer->AddActor(inputActor);
//        rightRenderer->AddActor(cleanedActor);
//
//        leftRenderer->ResetCamera();
//        rightRenderer->ResetCamera();
//
//        renderWindow->Render();
//        interactor->Start();
//}
