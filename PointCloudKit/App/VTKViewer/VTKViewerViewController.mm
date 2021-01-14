//
//  VTKViewerViewController.m
//  VTKViewer
//
//  Created by Max Smolens on 6/19/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import "PointCloudKit-Swift.h"
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <UniformTypeIdentifiers/UTCoreTypes.h>
#include <UniformTypeIdentifiers/UTAdditions.h>

#import "VTKViewerViewController.h"
#import "VTKPointsProcessors.h"
#import "VTKPolyDataProcessors.h"

#import "VTKGestureHandler.h"
#import "VTKLoader.h"
#import "VTKView.h"
#import "VTKExporter.h"

#include <vtk/vtkActor.h>
#include <vtk/vtkPointSource.h>
#include <vtk/vtkPolyDataMapper.h>
#include <vtk/vtkRenderWindow.h>
#include <vtk/vtkRenderer.h>
#include <vtk/vtkSmartPointer.h>
#include <vtk/vtkCamera.h>

#include <vtk/vtkAppendPolyData.h>

#include <vtk/vtkNamedColors.h>
#include <vtk/vtkPointData.h>
#include <vtk/vtkProperty.h>
#include <vtk/vtkNamedColors.h>

// SupportedExportType defined in VTKExporter.h
const char* pathExtensionFor(const SupportedExportType exportType) {
    switch (exportType) {
        case SupportedExportType::polygon:
            return "ply";
        case SupportedExportType::visualisationToolKit:
            return "vtk";
        case SupportedExportType::xyz:
            return "xyz";
        case SupportedExportType::WavefrontObject:
            return "obj";
        case SupportedExportType::stereoLithography:
            return "stl";
    }
}
//
const std::string utiFor(const SupportedExportType exportType) {
    switch (exportType) {
        case SupportedExportType::polygon:
            return "public.polygon-file-format";
        case SupportedExportType::visualisationToolKit:
            return "com.kitware.vtk";
        case SupportedExportType::xyz:
            return "com.pointcloudkit.xyz";
        case SupportedExportType::WavefrontObject:
            return "public.geometry-definition-format";
        case SupportedExportType::stereoLithography:
            return "public.standard-tesselated-geometry-format";
    }
}

//////////////////////////////////////////////////////////////////////////////////

@interface VTKViewerViewController ()

@property (strong, nonatomic) NSURL* initialUrl;

// Views
@property (strong, nonatomic) IBOutlet VTKView* vtkView;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *exportBarButtonItem;

@property (strong, nonatomic) UIDocumentInteractionController *documentInteractionController;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (weak, nonatomic) IBOutlet UIButton *revertButton;

// VTK
@property (nonatomic) vtkSmartPointer<vtkRenderer> renderer;

@property (nonatomic) vtkSmartPointer<vtkPolyData> revertablePolyData;

@property (nonatomic) vtkSmartPointer<vtkPolyData> polyData;

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

/// DidSet for revertablePolyData
- (void)setRevertablePolyData:(vtkSmartPointer<vtkPolyData>)revertablePolyData {
    _revertablePolyData = revertablePolyData;
    [self.revertButton setEnabled:true];
}

// MARK: Renderer

- (void)setupRenderer
{
    self.renderer = vtkSmartPointer<vtkRenderer>::New();
    self.renderer->SetBackground(0.3, 0.12, 0.3);
    self.renderer->SetBackground2(0.12, 0.12, 0.40);
    self.renderer->GradientBackgroundOn();
    [self resetCamera];
    self.vtkView.renderWindow->AddRenderer(self.renderer);
    
    // Load initial data
    if (_particlesBuffer != nil)
    {
        [self loadPointCloudFromBuffer: _particlesBuffer captureSize: _captureSize];
    }
    else if (self.initialUrl)
    {
        // If URL given when launching app,
        // load that file
        [self loadFile:self.initialUrl];
        self.initialUrl = nil;
    }
    else
    {
        self.polyData = [VTKLoader loadDefaultPointCloud];
        auto actor = [self actorFromPolydata:self.polyData];
        self.renderer->AddActor(actor);
        [self resetCamera];
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

//// MARK: Files
////
//- (NSArray<UTType*>*)supportedFileTypes
//{
//    auto vtkUtiString = [NSString stringWithUTF8String:utiFor(::visualisationToolKit).c_str()];
//    auto xyzUtiString = [NSString stringWithUTF8String:utiFor(::xyz).c_str()];
//    auto publicDataTypeString = [NSString stringWithUTF8String:"public.data"];
////    auto publicDataType = [UTType typeWithFilenameExtension:<#(nonnull NSString *)#>]
//    return [[NSArray<UTType*> alloc ] initWithObjects:
//            [UTType typeWithIdentifier:kUTTypePolygon],
//            [UTType typeWithIdentifier:kUTTypeStereolithography],
//            [UTType typeWithIdentifier:kUTType3dObject],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "xyz"]],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "XYZ"]],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "xyzrgb"]],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "XYZRGB"]],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "vtk"]],
//            [UTType typeWithFilenameExtension: [NSString stringWithUTF8String: "VTK"]],
////            [UTType exportedTypeWithIdentifier:vtkUtiString],
////            [UTType exportedTypeWithIdentifier:xyzUtiString],
//            nil
//            ];
//}

- (IBAction)onAddDataButtonPressed:(id)sender
{
    //    NSArray<UTType*> *supportedFileTypes = [self supportedFileTypes];
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[
        @"public.polygon-file-format",
        @"com.pointcloudkit.xyz",
        @"public.standard-tesselated-geometry-format",
        @"public.geometry-definition-format",
        @"com.pointcloudkit.vtk",
        @"com.kitware.vtk"
//        @"public.data"
    ] inMode:UIDocumentPickerModeImport];
    //[[UIDocumentPickerViewController alloc]  initForOpeningContentTypes:supportedFileTypes asCopy:true];
    documentPicker.shouldShowFileExtensions = true;
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = false;
    [self presentViewController:documentPicker animated:true completion:nil];
}

- (IBAction)onExportButtonPressed:(id)sender
{
    auto exportTypeSelectionAlertController = [UIAlertController alertControllerWithTitle:@"Supported Export Formats"
                                                                   message:nil
                                                            preferredStyle: UIAlertControllerStyleActionSheet];
    auto plyExport = [UIAlertAction actionWithTitle:@"Polygon File (PLY) PlainText"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::polygon binary:false];
    }];
    
    auto plyBinaryExport = [UIAlertAction actionWithTitle:@"Polygon File (PLY) Binary"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::polygon];
    }];

    auto xyzExport = [UIAlertAction actionWithTitle:@"Simple Point File (XYZ)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::xyz];
    }];
    
    auto vtkExport = [UIAlertAction actionWithTitle:@"Visualisation Toolkit (VTK)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::visualisationToolKit];
    }];
    
    auto objExport = [UIAlertAction actionWithTitle:@"Wavefront Object (OBJ)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::WavefrontObject];
    }];
    
    auto stlExport = [UIAlertAction actionWithTitle:@"Stereo Litography (STL)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self exportWithType:SupportedExportType::stereoLithography];
    }];
    
    auto cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [exportTypeSelectionAlertController addAction:plyExport];
    [exportTypeSelectionAlertController addAction:plyBinaryExport];
    [exportTypeSelectionAlertController addAction:xyzExport];
    [exportTypeSelectionAlertController addAction:vtkExport];
    [exportTypeSelectionAlertController addAction:objExport];
    [exportTypeSelectionAlertController addAction:stlExport];
    [exportTypeSelectionAlertController addAction:cancel];
    
    exportTypeSelectionAlertController.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    // There is a constraint error presenting this and it's an Apple bug...
    [self presentViewController:exportTypeSelectionAlertController animated:false completion:nil];
}

- (IBAction)resetCameraButtonPressed:(id)sender {
    [self resetCamera];
}

- (IBAction)statisticalOutlierRemovalFilteringButtonPressed:(id)sender {
    [self statisticalOutlierRemovalFiltering];
}

- (IBAction)cellDownSamplingButtonPressed:(id)sender {
    [self cellDownSampling];
}

- (IBAction)surfaceReconstructionButtonPressed:(id)sender {
    [self surfaceReconstruction];
}

- (IBAction)revertButtonPressed:(id)sender {
    [self revert];
}

// MARK: - Document Picker Delegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    [self loadFile:url];
}

// MARK: - Document Intercation Controller Delegate
- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    // DOESNT work... Need to remove the tmpfile also
    [self showAlertWithTitle:@"Success" andMesage:@"The file has been saved" additionalAtions:nil];
}

// MARK: - Opening file URL

- (void)loadFile:(nonnull NSURL*)url
{
    // If the view is not yet loaded, keep track of the url
    // and load it after everything is initialized
    if (!self.isViewLoaded)
    {
        self.initialUrl = url;
        return;
    }
    
    // First Check if scene is empty.
    if (self.renderer->GetViewProps()->GetNumberOfItems() == 0)
    {
        // Directly load the file. Not necessary to reset the scene as there's nothing to reset.
        [self loadFileInternal:url];
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
                [self loadFileInternal:url];
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

- (void)loadFileInternal:(NSURL*)url
{
    self.polyData = [VTKLoader loadFromURL: url];
    auto actor = [self actorFromPolydata: self.polyData];
    
    if (actor)
    {
        self.renderer->AddActor(actor);
        [self resetCamera];
    }
    else
    {
        NSString *alertTitle = @"Import Failed";
        NSString *alertMessage = [NSString stringWithFormat:@"Could not load %@", [url lastPathComponent]];
        [self showAlertWithTitle:alertTitle andMesage:alertMessage additionalAtions:nil];
    }
}

// MARK: - Opening MTL Buffer

- (void)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    self.polyData = [VTKLoader loadPointCloudFromBuffer:particlesBuffer captureSize:captureSize];
    auto actor = [self actorFromPolydata:self.polyData];
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

- (void)statisticalOutlierRemovalFiltering
{
    auto polydataAlgorithm = vtkSmartPointer<vtkAppendPolyData>::New();

    // Transform polyData to algorythm to streamline processors
    polydataAlgorithm->AddInputData(self.polyData);
    polydataAlgorithm->Update();
    
    std::cout << "Number of points being Filtered " << polydataAlgorithm->GetOutput()->GetNumberOfPoints() << std::endl;
    std::cout << "Number of poly being Filtered " << polydataAlgorithm->GetOutput()->GetNumberOfPolys() << std::endl;
    std::cout << "Number of line being Filtered " << polydataAlgorithm->GetOutput()->GetNumberOfLines() << std::endl;
    std::cout << "Number of vet being Filtered " << polydataAlgorithm->GetOutput()->GetNumberOfVerts() << std::endl;
    std::cout << "Number of cells being Filtered " << polydataAlgorithm->GetOutput()->GetNumberOfCells() << std::endl;
    
    auto statisticalRemovalPolyDataAlgorithm = [VTKPointsProcessors statisticalOutlierRemovalWithSampleSize:80
                                                                                     inputAlgorithm:polydataAlgorithm];

    self.renderer->RemoveAllViewProps();
    self.revertablePolyData = self.polyData;
    self.polyData = statisticalRemovalPolyDataAlgorithm->GetOutput();
    auto actor = [self actorFromPolydata:self.polyData];
    self.renderer->AddActor(actor);
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)cellDownSampling
{
    auto polydataAlgorithm = vtkSmartPointer<vtkAppendPolyData>::New();

    // Transform polyData to algorythm to streamline processors
    polydataAlgorithm->AddInputData(self.polyData);
    polydataAlgorithm->Update();
    
    auto cleanedPolyDataAlgorithm = [VTKPolyDataProcessors cleanPolyDataWithTolerance:0.00001 inputAlgorithm:polydataAlgorithm];
    
    self.renderer->RemoveAllViewProps();
    self.revertablePolyData = self.polyData;
    self.polyData = cleanedPolyDataAlgorithm->GetOutput();
    auto actor = [self actorFromPolydata:self.polyData];
    self.renderer->AddActor(actor);
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)surfaceReconstruction
{
    auto polydataAlgorithm = vtkSmartPointer<vtkAppendPolyData>::New();

    // Transform polyData to algorythm to streamline processors
    polydataAlgorithm->AddInputData(self.polyData);
    polydataAlgorithm->Update();
    
    auto surfaceReconstructionAlgorithm = [VTKPolyDataProcessors surfaceReconstruction:polydataAlgorithm];
    auto namedColor = vtkSmartPointer<vtkNamedColors>::New();
    vtkSmartPointer<vtkProperty> back = vtkSmartPointer<vtkProperty>::New();
    back->SetColor(namedColor->GetColor3d("banana").GetData());
    
    self.renderer->RemoveAllViewProps();
    self.revertablePolyData = self.polyData;
    self.polyData = surfaceReconstructionAlgorithm->GetOutput();
    auto actor = [self actorFromPolydata:self.polyData];
    
    actor->SetBackfaceProperty(back);
    
    self.renderer->AddActor(actor);
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)revert
{
    // remove curently presented actors
    self.renderer->RemoveAllViewProps();
    // Swap
    auto swapHolder = self.revertablePolyData;
    self.revertablePolyData = self.polyData;
    self.polyData = swapHolder;
    
    
    auto actor = [self actorFromPolydata:self.polyData];
    self.renderer->AddActor(actor);
    
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)exportWithType:(SupportedExportType)type
{ [self exportWithType:type binary:true]; }
- (void)exportWithType:(SupportedExportType)type binary:(bool)binary
{
    auto fileManager = [NSFileManager defaultManager];
    auto timestamp = [[[NSUUID UUID] UUIDString] substringToIndex:6];
    auto fileName = [NSString stringWithFormat:@"pointCloudKit_export_%@", timestamp];
    auto fileExtension = [NSString stringWithUTF8String:pathExtensionFor(type)];
    auto fileUti = [NSString stringWithUTF8String:utiFor(type).c_str()];
    auto temporaryUrl = [[[fileManager temporaryDirectory]
                          URLByAppendingPathComponent:fileName]
                         URLByAppendingPathExtension:fileExtension];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator startAnimating];
    });
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul);
    dispatch_async(queue, ^{
        
        [VTKExporter writeTo:temporaryUrl.path polyData:self.polyData type:type binary:binary];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            // Show export location picker
            if (self.documentInteractionController == nil) {
                self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:temporaryUrl];
                [self.documentInteractionController setDelegate:self];
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

- (vtkSmartPointer<vtkActor>)actorFromPolydata:(vtkPolyData*)polyData
{
    auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
    auto actor  = vtkSmartPointer<vtkActor>::New();
    auto colors = vtkSmartPointer<vtkNamedColors>::New();
    
    // hack to start with algo instead data to streamline the processors
    auto polydataAlgorithm = vtkSmartPointer<vtkAppendPolyData>::New();
    polydataAlgorithm->AddInputData(polyData);
    polydataAlgorithm->Update();
    
    if (polyData->GetNumberOfPolys() == 0 && polyData->GetNumberOfLines() == 0) {
        // MARK: - POINT CLOUD
        // Calculate Bounds and Range of PolyData
        double bounds[6];
        double range[3];
        polyData->GetBounds(bounds);
        for (int i = 0; i < 3; ++i) {
            range[i] = bounds[2 * i + 1] - bounds[2 * i];
        }
        auto maxRange = std::max(std::max(range[0], range[1]), range[2]);
        
        /// GLYPHING ---------------------------------------------------------------------------
        double sphereRadius = maxRange * .002;
        auto glyphedAlgorithm = [VTKPointsProcessors glyphingWith:sphereRadius
                                                   inputAlgorithm:polydataAlgorithm];
        
        // MAPPER
        auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
        mapper->SetInputConnection(glyphedAlgorithm->GetOutputPort());
        // ACTOR
        actor->SetMapper(mapper);
    } else {
        // MARK: - REGULAR 3D MODEL
        mapper->SetInputConnection(polydataAlgorithm->GetOutputPort());
        actor->SetMapper(mapper);
        actor->GetProperty()->SetColor(colors->GetColor3d("Chartreuse").GetData());
    }
    return actor;
}

@end
