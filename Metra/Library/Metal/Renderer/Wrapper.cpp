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
//
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkPointSource.h>
//#include <vtk/vtkPolyData.h>
//#include <vtk/vtkCleanPolyData.h>
//#include <vtk/vtkPolyDataMapper.h>


#include <vtk/vtkNew.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkQuantizePolyDataPoints.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkCamera.h>
#include <vtk/vtkGlyph3DMapper.h>
#include <vtk/vtkPointSource.h>
#include <vtk/vtkPoints.h>
#include <vtk/vtkPolyData.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkRenderWindow.h>
#include <vtk/vtkRenderWindowInteractor.h>
#include <vtk/vtkRenderer.h>
#include <vtk/vtkSphereSource.h>
#include <vtk/vtkXMLPolyDataReader.h>
#include <vtk/vtkNamedColors.h>
#include <vtk/vtkNew.h>
#include <vtk/vtkProperty.h>


extern "C" int simplify(std::string inputFilename) {
    vtkNew<vtkNamedColors> colors;
    vtkNew<vtkPointSource> pointSource;
    
    vtkSmartPointer<vtkPLYReader> reader = vtkSmartPointer<vtkPLYReader>::New();
    reader->SetFileName ( inputFilename.c_str() );
    
    pointSource->SetNumberOfPoints(100);
    pointSource->Update();
    
    std::cout << "There are " << pointSource->GetNumberOfPoints() << " points."
    << std::endl;
    
    vtkNew<vtkQuantizePolyDataPoints> quantizeFilter;
    quantizeFilter->SetInputConnection(pointSource->GetOutputPort());
    quantizeFilter->SetQFactor(.1);
    quantizeFilter->Update();
    
    vtkPolyData* quantized = quantizeFilter->GetOutput();
    std::cout << "There are " << quantized->GetNumberOfPoints()
    << " quantized points." << std::endl;
    
    for (vtkIdType i = 0; i < pointSource->GetOutput()->GetNumberOfPoints(); i++)
    {
        double pOrig[3];
        double pQuantized[3];
        pointSource->GetOutput()->GetPoint(i, pOrig);
        quantized->GetPoints()->GetPoint(i, pQuantized);
        
        std::cout << "Point " << i << " : (" << pOrig[0] << ", " << pOrig[1] << ", "
        << pOrig[2] << ")"
        << " (" << pQuantized[0] << ", " << pQuantized[1] << ", "
        << pQuantized[2] << ")" << std::endl;
    }
    
    double radius = 0.02;
    vtkNew<vtkSphereSource> sphereSource;
    sphereSource->SetRadius(radius);
    
    vtkNew<vtkGlyph3DMapper> inputMapper;
    inputMapper->SetInputConnection(pointSource->GetOutputPort());
    inputMapper->SetSourceConnection(sphereSource->GetOutputPort());
    inputMapper->ScalarVisibilityOff();
    inputMapper->ScalingOff();
    
    vtkNew<vtkActor> inputActor;
    inputActor->SetMapper(inputMapper);
    inputActor->GetProperty()->SetColor(
                                        colors->GetColor3d("Orchid").GetData());
    
    
    vtkNew<vtkGlyph3DMapper> quantizedMapper;
    quantizedMapper->SetInputConnection(quantizeFilter->GetOutputPort());
    quantizedMapper->SetSourceConnection(sphereSource->GetOutputPort());
    quantizedMapper->ScalarVisibilityOff();
    quantizedMapper->ScalingOff();
    
    vtkNew<vtkActor> quantizedActor;
    quantizedActor->SetMapper(quantizedMapper);
    quantizedActor->GetProperty()->SetColor(
                                            colors->GetColor3d("Orchid").GetData());
    
    // There will be one render window
    vtkNew<vtkRenderWindow> renderWindow;
    renderWindow->SetSize(640, 360);
    
    // And one interactor
    vtkNew<vtkRenderWindowInteractor> interactor;
    interactor->SetRenderWindow(renderWindow);
    renderWindow->SetWindowName("QuantizePolyDataPoints");
    
    // Define viewport ranges
    // (xmin, ymin, xmax, ymax)
    double leftViewport[4] = {0.0, 0.0, 0.5, 1.0};
    double rightViewport[4] = {0.5, 0.0, 1.0, 1.0};
    
    // Setup both renderers
    vtkNew<vtkRenderer> leftRenderer;
    renderWindow->AddRenderer(leftRenderer);
    leftRenderer->SetViewport(leftViewport);
    leftRenderer->SetBackground(colors->GetColor3d("Bisque").GetData());
    
    vtkNew<vtkRenderer> rightRenderer;
    renderWindow->AddRenderer(rightRenderer);
    rightRenderer->SetViewport(rightViewport);
    rightRenderer->SetBackground(colors->GetColor3d("PaleTurquoise").GetData());
    
    leftRenderer->AddActor(inputActor);
    rightRenderer->AddActor(quantizedActor);
    
    leftRenderer->ResetCamera();
    
    rightRenderer->SetActiveCamera(leftRenderer->GetActiveCamera());
    
    renderWindow->Render();
    interactor->Start();
    
    return EXIT_SUCCESS;
}

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
