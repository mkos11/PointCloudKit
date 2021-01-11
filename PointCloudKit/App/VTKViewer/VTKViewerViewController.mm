//
//  VTKViewerViewController.m
//  VTKViewer
//
//  Created by Max Smolens on 6/19/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import "VTKViewerViewController.h"

#import "VTKGestureHandler.h"
#import "VTKLoader.h"
#import "VTKView.h"
#import "VTKExportService.h"

#include <vtk/vtkActor.h>
#include <vtk/vtkCubeSource.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkRenderWindow.h>
#include <vtk/vtkRenderer.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkCamera.h>

#include <vtk/vtkAppendPolyData.h>

//////////////////////////////////////////////////////////////////////////////////
/// This block is a quick hack to emulate a switch on string in objc/c++
// Value-Defintions of the different String values
static enum SupportedExportType {
    polygonFileFormat,
    visualisationToolKitFileFormat,
    unsupported
};

// Map to associate the strings with the enum values
//static std::map<std::string, SupportedExportType> supportedExportTypeMap;
//
//const void cppInitializeSupportedExportTypeMap()
//{
//    supportedExportTypeMap["kUTTypePolygon"] = polygonFileFormat;
//    supportedExportTypeMap["unsupported"] = unsupported;
//}

const char* pathExtensionFor(const SupportedExportType exportType) {
    switch (exportType) {
        case SupportedExportType::polygonFileFormat:
            return "ply";
        case SupportedExportType::visualisationToolKitFileFormat:
            return "vtk";
        default:
            return "";
    }
}

const char* utiFor(const SupportedExportType exportType) {
    switch (exportType) {
        case SupportedExportType::polygonFileFormat:
            return "public.polygon-file-format";
        case SupportedExportType::visualisationToolKitFileFormat:
            return "com.kitware.vtk";
        default:
            return "";
    }
}


//////////////////////////////////////////////////////////////////////////////////

@interface VTKViewerViewController ()

@property (strong, nonatomic) NSArray<NSURL*>* initialUrls;

// Views
@property (strong, nonatomic) IBOutlet VTKView* vtkView;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *exportBarButtonItem;

@property (strong, nonatomic) UIDocumentInteractionController *documentInteractionController;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

// VTK
@property (nonatomic) vtkSmartPointer<vtkRenderer> renderer;

// VTK Logic
@property (nonatomic) VTKGestureHandler* vtkGestureHandler;

@end

@implementation VTKViewerViewController

/*
 Using ivars instead of properties to avoid any performance penalities with
 the Objective-C runtime.
 */
id<MTLBuffer> _particlesBuffer = nil;
int _captureSize;

//id<MTLTexture> _diffuseTexture;

// MARK: UIViewController

- (BOOL)prefersStatusBarHidden { return TRUE; }

- (BOOL)prefersHomeIndicatorAutoHidden { return TRUE; }

- (instancetype)initWithCoder:(NSCoder *)coder particlesBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    // We pass the capture size because the MTL buffer is often not fully filled by the capture
    _particlesBuffer = particlesBuffer;
    _captureSize = captureSize;
    return [super initWithCoder:coder];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:FALSE animated:TRUE];

    // UI Gestures
    [self setupGestures];
    
    // Rendering
    [self setupRenderer];
    
    // VTK Logic
    self.vtkGestureHandler = [[VTKGestureHandler alloc] initWithVtkView:self.vtkView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK: Renderer

- (void)setupRenderer
{
    self.renderer = vtkSmartPointer<vtkRenderer>::New();
    self.renderer->SetBackground(0.3, 0.12, 0.3);
    self.renderer->SetBackground2(0.12, 0.12, 0.25);
    self.renderer->GradientBackgroundOn();
    self.vtkView.renderWindow->AddRenderer(self.renderer);
    
    // Load initial data
    if (_particlesBuffer != nil)
    {
        [self loadPointCloudFromBuffer: _particlesBuffer captureSize: _captureSize];
    }
    else if (self.initialUrls)
    {
        // If URL given when launching app,
        // load that file
        [self loadFiles:self.initialUrls];
        self.initialUrls = nil;
    }
    else
    {
        // If no data is explicitly requested,
        // add dummy cube
        auto cubeSource = vtkSmartPointer<vtkCubeSource>::New();
        auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
        mapper->SetInputConnection(cubeSource->GetOutputPort());
        auto actor = vtkSmartPointer<vtkActor>::New();
        actor->SetMapper(mapper);
        self.renderer->AddActor(actor);
        // Position the camera better, should move the cube tho
        self.renderer->GetActiveCamera()->Azimuth(30);
        self.renderer->GetActiveCamera()->Elevation(30);
        self.renderer->GetActiveCamera()->Dolly(0.142);
    }
}

// MARK: Gestures

- (void)setupGestures
{
    // Add the double tap gesture recognizer
    UITapGestureRecognizer* doubleTapRecognizer =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    [doubleTapRecognizer setNumberOfTapsRequired:2];
    [self.view addGestureRecognizer:doubleTapRecognizer];
    doubleTapRecognizer.delegate = self;
}

- (void)onDoubleTap:(UITapGestureRecognizer*)sender
{
}

// MARK: Files

- (NSArray<NSString*>*)supportedFileTypes
{
    NSArray* documentTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
    NSDictionary* vtkDocumentType = [documentTypes objectAtIndex:0];
    return [vtkDocumentType objectForKey:@"LSItemContentTypes"];
}

- (IBAction)onAddDataButtonPressed:(id)sender
{
    UIDocumentPickerViewController* documentPicker = [[UIDocumentPickerViewController alloc]
                                                      initWithDocumentTypes:[self supportedFileTypes]
                                                      inMode:UIDocumentPickerModeImport];
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = true;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (IBAction)onExportButtonPressed:(id)sender
{
    auto exportTypeSelection = [UIAlertController alertControllerWithTitle:@"Supported Export Formats"
                                                                   message:nil
                                                            preferredStyle: UIAlertControllerStyleActionSheet];
    auto plyExport = [UIAlertAction actionWithTitle:@"Polygon File (PLY)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::polygonFileFormat];
    }];

    auto vtkExport = [UIAlertAction actionWithTitle:@"Visualisation Toolkit (VTK)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::visualisationToolKitFileFormat];
    }];


    auto cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [exportTypeSelection addAction:plyExport];
    [exportTypeSelection addAction:vtkExport];
    [exportTypeSelection addAction:cancel];
    [self presentViewController:exportTypeSelection animated:true completion:nil];
}

- (IBAction)resetCameraButtonPressed:(id)sender {
    [self resetCamera];
}

// MARK: - Document Picker Delegate
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(nonnull NSArray<NSURL*>*)urls
{
    [self loadFiles:urls];
}

// MARK: - Document Intercation Controller Delegate
- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {

    [self showAlertWithTitle:@"Success" andMesage:@"The file has been saved" additionalAtions:nil];
}

// MARK: - Opening files URL

- (void)loadFiles:(nonnull NSArray<NSURL*>*)urls
{
    // If the view is not yet loaded, keep track of the url
    // and load it after everything is initialized
    if (!self.isViewLoaded)
    {
        self.initialUrls = urls;
        return;
    }
    
    // First Check if scene is empty.
    if (self.renderer->GetViewProps()->GetNumberOfItems() == 0)
    {
        // Directly load the file. Not necessary to reset the scene as there's nothing to reset.
        [self loadFilesInternal:urls];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController* alertController =
            [UIAlertController alertControllerWithTitle:@"Import"
                                                message:@"There are other objects in the scene."
                                         preferredStyle:UIAlertControllerStyleAlert];

            // Completion handler for selected action in alertController.
            void (^onSelectedAction)(UIAlertAction*) = ^(UIAlertAction* action) {
                // Reset the scene if "Replace" was selected.
                if (action.style == UIAlertActionStyleCancel)
                {
                    self.renderer->RemoveAllViewProps();
                }
                [self loadFilesInternal:urls];
            };

            // Two actions : Insert file in scene and Reset the scene.
            [alertController addAction:[UIAlertAction actionWithTitle:@"Add"
                                                                style:UIAlertActionStyleDefault
                                                              handler:onSelectedAction]];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Replace"
                                                                style:UIAlertActionStyleCancel
                                                              handler:onSelectedAction]];

            [self presentViewController:alertController animated:YES completion:nil];
        });
    }
}

- (void)loadFilesInternal:(nonnull NSArray<NSURL*>*)urls
{
    for (NSURL* url in urls)
    {
        [self loadFileInternal:url];
    }
}

- (void)loadFileInternal:(NSURL*)url
{
    vtkSmartPointer<vtkActor> actor = [VTKLoader loadFromURL:url];
    
    NSString* alertTitle;
    NSString* alertMessage;
    if (actor)
    {
        self.renderer->AddActor(actor);
        [self resetCamera];
        alertTitle = @"Import";
        alertMessage = [NSString stringWithFormat:@"Imported %@", [url lastPathComponent]];
    }
    else
    {
        alertTitle = @"Import Failed";
        alertMessage = [NSString stringWithFormat:@"Could not load %@", [url lastPathComponent]];
    }
    [self showAlertWithTitle:alertTitle andMesage:alertMessage additionalAtions:nil];
}

// MARK: - Opening MTL Buffer

- (void)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    vtkSmartPointer<vtkActor> actor = [VTKLoader loadPointCloudFromBuffer:particlesBuffer captureSize:captureSize];
    if (actor)
    {
        self.renderer->AddActor(actor);
        [self resetCamera];
    }
    else
    {
        NSString* alertTitle = @"Import Failed";
        NSString* alertMessage = @"Could not load capture";
        [self showAlertWithTitle:alertTitle andMesage:alertMessage additionalAtions:nil];
    }

}

// MARK: - Button actions
- (void)resetCamera
{
    self.renderer->ResetCameraClippingRange();
    self.renderer->ResetCamera();
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)exportWithType:(SupportedExportType)type
{
    auto actors = self.renderer->GetActors();
    auto actorsPolydata = vtkSmartPointer<vtkAppendPolyData>::New();

    // Concat rendered actors using a vtkAppendPolyData
    actors->InitTraversal();
    for(int i = 0; i < actors->GetNumberOfItems(); i++) {
        auto actorPolyData = vtkPolyData::SafeDownCast(actors->GetNextActor()->GetMapper()->GetInput());
        actorsPolydata->AddInputData(actorPolyData);
    }
    actorsPolydata->Update();

    std::cout << "Number of points being EXPORTED " << actorsPolydata->GetOutput()->GetNumberOfPoints() << std::endl;
    std::cout << "Number of poly being EXPORTED " << actorsPolydata->GetOutput()->GetNumberOfPolys() << std::endl;
    std::cout << "Number of line being EXPORTED " << actorsPolydata->GetOutput()->GetNumberOfLines() << std::endl;
    std::cout << "Number of vet being EXPORTED " << actorsPolydata->GetOutput()->GetNumberOfVerts() << std::endl;
    std::cout << "Number of cells being EXPORTED " << actorsPolydata->GetOutput()->GetNumberOfCells() << std::endl;

    auto fileManager = [NSFileManager defaultManager];
    auto timestamp = [[[NSUUID UUID] UUIDString] substringToIndex:6];
    auto fileName = [NSString stringWithFormat:@"pointCloudKit_export_%@", timestamp];
    auto fileExtension = [NSString stringWithCString:pathExtensionFor(type) encoding:NSUTF8StringEncoding];
    auto fileUti = [NSString stringWithCString:utiFor(type) encoding:NSUTF8StringEncoding];
    auto temporaryUrl = [[[fileManager temporaryDirectory]
                          URLByAppendingPathComponent:fileName]
                         URLByAppendingPathExtension:fileExtension];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator startAnimating];
    });
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul);
    dispatch_async(queue, ^{
        switch (type) {
            case SupportedExportType::polygonFileFormat: {
                auto plyString = [VTKExportService getPLYdataAsStringFrom:actorsPolydata->GetOutputPort()];
                [[NSData dataWithBytes:&plyString length:plyString.length()]
                 writeToURL:temporaryUrl atomically:false];
                break;
            }
            case SupportedExportType::visualisationToolKitFileFormat: {
                auto vtkString = [VTKExportService getVTKdataAsStringFrom:actorsPolydata->GetOutputPort()];
                [[NSData dataWithBytes:&vtkString length:vtkString.length()]
                 writeToURL:temporaryUrl atomically:false];
                break;
            }
            default: {
                break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            // Show export location picker
            if (self.documentInteractionController == nil) {
                self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:temporaryUrl];
            } else {
                [self.documentInteractionController setURL:temporaryUrl];
            }
            [self.documentInteractionController setName:fileName];
            [self.documentInteractionController setUTI:fileUti];
            [self.documentInteractionController presentOptionsMenuFromBarButtonItem:self.exportBarButtonItem animated:true];
        });
    });
}


// MARK: - Helpers

- (void)showAlertWithTitle:(NSString*)title andMesage:(NSString*)message additionalAtions:(NSArray<UIAlertAction*>*)actions
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        for (id action in actions) {
            [alertController addAction: action];
        }
        // Default OK action
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok"
                                                            style:UIAlertActionStyleDefault
                                                          handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

@end
