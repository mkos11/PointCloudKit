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

#include <vtk/vtkCornerAnnotation.h>

#include <vtk/vtkProgressBarWidget.h>
#include <vtk/vtkProgressBarRepresentation.h>

#include <vtk/vtkVertexGlyphFilter.h>
#include <vtk/vtkMaskPoints.h>
#include <vtk/vtkCallbackCommand.h>
#include <vtk/vtkTextProperty.h>

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
@property (weak, nonatomic) IBOutlet UIBarButtonItem *importButton;

@property (strong, nonatomic) UIDocumentInteractionController *documentInteractionController;


@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *resetCameraPositionButton;
@property (weak, nonatomic) IBOutlet UIButton *outlierFilterButton;
@property (weak, nonatomic) IBOutlet UIButton *simplifyCloudButton;
@property (weak, nonatomic) IBOutlet UIButton *surfaceReconstructionButton;

@property (weak, nonatomic) IBOutlet UILabel *inProgressLabel;
@property (weak, nonatomic) IBOutlet UILabel *informationLabel;
@property (weak, nonatomic) IBOutlet UIButton *revertButton;

// VTK
@property (nonatomic) vtkSmartPointer<vtkRenderer> renderer;

@property (nonatomic) vtkSmartPointer<vtkPolyData> revertablePolyData;
@property (nonatomic) vtkSmartPointer<vtkPolyData> polyData;

@property (nonatomic) vtkSmartPointer<vtkPolyData> polyDataGlyphed;

@property (nonatomic) vtkSmartPointer<vtkProgressBarRepresentation> progressBarVtk;

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
vtkSmartPointer<vtkCornerAnnotation> cornerAnnotation;
dispatch_queue_t highPriorityDispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);

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
    
    // Rendering
    [self setupRenderer];
    
    // CornerANnotation
    cornerAnnotation = [self createCornerAnnotation];
    
    // setup FPS
    auto fpsUpdateCallback = [self setupFpsCounterCallback];
    self.renderer->AddObserver(vtkCommand::EndEvent, fpsUpdateCallback);
    
    // setup progress bar
    self.progressBarVtk = vtkSmartPointer<vtkProgressBarRepresentation>::New();
    
    self.progressBarVtk->SetProgressRate(0.4);
    self.progressBarVtk->SetPosition(0.4, 0.4);
    self.progressBarVtk->SetProgressBarColor(0.2, 0.4, 0);
    self.progressBarVtk->SetBackgroundColor(1, 1, 0.5);
    self.progressBarVtk->DrawBackgroundOn();
    
    // VTK Logic
    self.vtkGestureHandler = [[VTKGestureHandler alloc] initWithVtkView:self.vtkView];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//     Load object
    [self setupInitialRenderContent];
}

- (void)dealloc {
    self.renderer->RemoveAllObservers();
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/// DidSet for revertablePolyData
- (void)setRevertablePolyData:(vtkSmartPointer<vtkPolyData>)revertablePolyData {
    _revertablePolyData = revertablePolyData;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.revertButton setEnabled:true];
    });
}

// MARK: Renderer

- (void)setupRenderer
{
    self.renderer = vtkSmartPointer<vtkRenderer>::New();
    self.renderer->SetBackground(0.3, 0.12, 0.3);
    self.renderer->SetBackground2(0.12, 0.12, 0.40);
    self.renderer->GradientBackgroundOn();
    self.vtkView.renderWindow->AddRenderer(self.renderer);
}

- (void)setupInitialRenderContent
{
    // Load initial data
    if (_particlesBuffer != nil) {
        [self loadPointCloudFromBuffer:_particlesBuffer captureSize:_captureSize];
    } else if (self.initialUrl) {
        [self loadFile:self.initialUrl];
        self.initialUrl = nil;
    } else {
        // load default point cloud by passing nil
        [self loadFileInternal:nil];
    }
}

// MARK: Gestures

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
    ] inMode:UIDocumentPickerModeImport];
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
    [self resetCameraAndUpdate];
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
    if (!self.isViewLoaded) {
        self.initialUrl = url;
        return;
    }
    
    // First Check if scene is empty.
    if (self.renderer->GetActors()->GetNumberOfItems() == 0) {
        // Directly load the file. Not necessary to reset the scene as there's nothing to reset.
        [self loadFileInternal:url];
    }
    else {
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Import"
                                                                                 message:@"There are other objects in the scene."
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        // Completion handler for selected action in alertController.
        void (^onSelectedAction)(UIAlertAction*) = ^(UIAlertAction* action) {
            // Reset the scene if "Replace" was selected.
            if (action.style == UIAlertActionStyleCancel) {
                self.renderer->RemoveAllViewProps();
                // save current in previous
                self.revertablePolyData = self.polyData;
                // make current empty
                self.polyData = vtkSmartPointer<vtkPolyData>::New();
                // render nothing to flush
                [self renderAndDisplay:self.polyData];
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
    }
}

- (void)loadFileInternal:(NSURL*)url
{
    [self showActivityIndicator:true info:@"Loading file..."];
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(backgroundQueue, ^{
        self.revertablePolyData = self.polyData;
        self.polyData = [VTKLoader loadFromURL: url];
        // is pure points, requiers glyphing
        if (self.polyData->GetNumberOfPolys() == 0) {
            auto renderablePointCloudPolyData = [self maskAndGlyphPointCloudPolydata:self.polyData];
            [self renderSync:renderablePointCloudPolyData];
        } else {
            [self renderSync:self.polyData];
        }
        [self showActivityIndicator:false];
        [self resetCameraAndUpdate]; // trigger the update
    });
}

// MARK: - Opening MTL Buffer

- (void)loadPointCloudFromBuffer:(id<MTLBuffer>)particlesBuffer captureSize:(int)captureSize
{
    [self showActivityIndicator:true info:@"Loading capture..."];
    dispatch_async(highPriorityDispatchQueue, ^{
        auto pointCloudPolyDataFromMTLBuffer = [VTKLoader loadPointCloudFromBuffer:particlesBuffer captureSize:captureSize];
        self.revertablePolyData = nil;
        self.polyData = pointCloudPolyDataFromMTLBuffer;
        auto renderablePointCloudPolyData = [self maskAndGlyphPointCloudPolydata:self.polyData];
        [self showActivityIndicator:false];
        [self renderSync:renderablePointCloudPolyData];
        [self resetCameraAndUpdate]; // trigger the update
    });
}

// MARK: - Button actions
- (void)resetCameraAndUpdate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.renderer->ResetCameraClippingRange();
        self.renderer->ResetCamera();
        [self.view setNeedsDisplay];
        [self.vtkView setNeedsDisplay];
    });
}

- (void)statisticalOutlierRemovalFiltering
{
    [self showActivityIndicator:true info:@"Outlier filtering..."];
    dispatch_async(highPriorityDispatchQueue, ^{
        auto vertexGlyphFilter = vtkSmartPointer<vtkVertexGlyphFilter>::New();
        vertexGlyphFilter->SetInputData(self.polyData);
        vertexGlyphFilter->Update();
        
        auto statisticalRemovalPolyDataAlgorithm = [VTKPointsProcessors statisticalOutlierRemovalWithSampleSize:80
                                                                                                 inputAlgorithm:vertexGlyphFilter];
        
        self.revertablePolyData = self.polyData;
        self.polyData = statisticalRemovalPolyDataAlgorithm->GetOutput();
        
        auto renderablePointCloudPolydata = [self maskAndGlyphPointCloudPolydata:self.polyData];
        [self showActivityIndicator:false];
        [self renderAndDisplaySync:renderablePointCloudPolydata];
    });
}

- (void)cellDownSampling
{
    [self showActivityIndicator:true info:@"Cell downsampling..."];
    dispatch_async(highPriorityDispatchQueue, ^{
        auto vertexGlyphFilter = vtkSmartPointer<vtkVertexGlyphFilter>::New();
        vertexGlyphFilter->SetInputData(self.polyData);
        vertexGlyphFilter->Update();
        
        auto cleanedPolyDataAlgorithm = [VTKPolyDataProcessors cleanPolyDataWithTolerance:0.005 inputAlgorithm:vertexGlyphFilter];
        self.revertablePolyData = self.polyData;
        self.polyData = cleanedPolyDataAlgorithm->GetOutput();
        
        auto renderablePointCloudPolydata = [self maskAndGlyphPointCloudPolydata:self.polyData];
        [self renderAndDisplaySync:renderablePointCloudPolydata];
        [self showActivityIndicator:false];
//        [self renderAndDisplaySync:self.polyData];
    });
}

- (void)surfaceReconstruction
{
    [self showActivityIndicator:true info:@"Surface reconstruction..."];
    dispatch_async(highPriorityDispatchQueue, ^{
        auto vertexGlyphFilter = vtkSmartPointer<vtkVertexGlyphFilter>::New();
        vertexGlyphFilter->SetInputData(self.polyData);
        vertexGlyphFilter->Update();
        
        auto surfaceReconstructionAlgorithm = [VTKPolyDataProcessors surfaceReconstruction:vertexGlyphFilter];
        self.revertablePolyData = self.polyData;
        self.polyData = surfaceReconstructionAlgorithm->GetOutput();
        [self showActivityIndicator:false];
        [self renderAndDisplaySync:self.polyData];
    });
}

- (void)revert
{
    if (self.revertablePolyData == nil) {
        return;
    }
    // Swap
    auto swapHolder = self.revertablePolyData;
    self.revertablePolyData = self.polyData;
    self.polyData = swapHolder;
    // is pure points, requiers glyphing
    if (self.polyData->GetNumberOfPolys() == 0) {
        auto renderablePointCloudPolyData = [self maskAndGlyphPointCloudPolydata:self.polyData];
        [self renderAndDisplay:renderablePointCloudPolyData];
    } else {
        [self renderAndDisplay:self.polyData];
    }
}

- (void)exportWithType:(SupportedExportType)type
{ [self exportWithType:type binary:true]; }
- (void)exportWithType:(SupportedExportType)type binary:(bool)binary
{
    auto fileManager = [NSFileManager defaultManager];
    auto timestamp = [[[NSUUID UUID] UUIDString] substringToIndex:4];
    auto fileName = [NSString stringWithFormat:@"pointCloudKit_%@", timestamp];
    auto fileExtension = [NSString stringWithUTF8String:pathExtensionFor(type)];
    auto fileUti = [NSString stringWithUTF8String:utiFor(type).c_str()];
    auto temporaryUrl = [[[fileManager temporaryDirectory] URLByAppendingPathComponent:fileName]
                         URLByAppendingPathExtension:fileExtension];
    
    [self showActivityIndicator:true info:@"Exporting..."];
    dispatch_async(highPriorityDispatchQueue, ^{
        [VTKExporter writeTo:temporaryUrl.path polyData:self.polyData type:type binary:binary];
        // configure export location picker
        if (self.documentInteractionController == nil) {
            self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:temporaryUrl];
            [self.documentInteractionController setDelegate:self];
        } else {
            [self.documentInteractionController setURL:temporaryUrl];
        }
        [self.documentInteractionController setName:fileName];
        [self.documentInteractionController setUTI:fileUti];
        [self showActivityIndicator:false];
        [self presentDocumentInteractionController];
    });
}

// MARK: - Helpers

// Get polydata, clean it if too big (mask), glyph it, and return the glyphed polydata ready to be rendered
- (vtkSmartPointer<vtkPolyData>)maskAndGlyphPointCloudPolydata:(vtkPolyData*)polyData
{
    // hack to start with algo instead data to streamline the processors
    auto polydataAlgorithm = vtkSmartPointer<vtkAppendPolyData>::New();
    polydataAlgorithm->AddInputData(polyData);
    polydataAlgorithm->Update();
    
    [self showActivityIndicator:true info:@"Rendering point cloud..."];
    vtkSmartPointer<vtkPolyDataAlgorithm> pointsPolyDataAlgorithm;
    /// Masking ---------------------------------------------------------------------------
    if (polyData->GetNumberOfPoints() > 250000) {
        int ratio = (int)(polyData->GetNumberOfPoints() / 250000);
        auto maskingAlgorithm = [VTKPointsProcessors maskingWithRatio:ratio
                                                       inputAlgorithm:polydataAlgorithm];
        // Filtered input to reduce size and not kill the memory
        pointsPolyDataAlgorithm = maskingAlgorithm;
        
        NSString *message = [NSString stringWithFormat:@"The points cloud is a bit heavy for a mobile device, hence it's been downsampled by a factor of %d (initially %lld points, now %lld). \n This is only affecting the rendering, processors on the left and export will still take the original dataset as input.",
                              ratio,
                              polyData->GetNumberOfPoints(),
                              maskingAlgorithm->GetOutput()->GetNumberOfPoints()];
        [self showAlertWithTitle:@"Warning" andMesage:message additionalAtions:nil];
    } else {
        // Raw input
        pointsPolyDataAlgorithm = polydataAlgorithm;
    }
    
    /// GLYPHING ---------------------------------------------------------------------------
    // Calculate Bounds and Range of PolyData
    double bounds[6];
    double range[3];
    pointsPolyDataAlgorithm->GetOutput()->GetBounds(bounds);
    for (int i = 0; i < 3; ++i) {
        range[i] = bounds[2 * i + 1] - bounds[2 * i];
    }
    auto maxRange = std::max(std::max(range[0], range[1]), range[2]);
    double sphereRadius = maxRange * .0015;
    auto glyphedAlgorithm = [VTKPointsProcessors glyphingWith:sphereRadius
                                               inputAlgorithm:pointsPolyDataAlgorithm];
    [self showActivityIndicator:false];
    return glyphedAlgorithm->GetOutput();
}

- (void)render:(vtkPolyData*)polyData
{
    auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();
    auto actor  = vtkSmartPointer<vtkActor>::New();
    // MAPPER
    mapper->SetInputData(polyData);
    // Polydata ACTOR
    actor->SetMapper(mapper);
    // Cleanup
    self.renderer->RemoveAllViewProps();
    // Add new stuff
    self.renderer->AddActor(actor);
    // Re add static elements
    self.renderer->AddViewProp(cornerAnnotation);
    self.renderer->AddViewProp(self.progressBarVtk);
}

- (void)renderSync:(vtkPolyData*)polyData
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self render:polyData];
    });
}

- (void)renderAndDisplay:(vtkPolyData*)polyData
{
    [self render:polyData];
    // request redraw
    [self.view setNeedsDisplay];
    [self.vtkView setNeedsDisplay];
}

- (void)renderAndDisplaySync:(vtkPolyData*)polyData
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self renderAndDisplay:polyData];
        [self.view setNeedsDisplay];
        [self.vtkView setNeedsDisplay];
    });
}

- (vtkSmartPointer<vtkCallbackCommand>)setupFpsCounterCallback
{
    auto callback = vtkSmartPointer<vtkCallbackCommand>::New();
    callback->SetCallback(CallbackFunction);
    return callback;
}
void CallbackFunction(vtkObject* caller, long unsigned int vtkNotUsed(eventId), void* vtkNotUsed(clientData), void* vtkNotUsed(callData))
{
    vtkRenderer* renderer = static_cast<vtkRenderer*>(caller);
    double timeInSeconds = renderer->GetLastRenderTimeInSeconds();
    std::string fpsString;
    fpsString = std::to_string((int)(1.0 / timeInSeconds)) + "fps";
    auto position = vtkCornerAnnotation::TextPosition::LowerEdge;
    cornerAnnotation->SetText(position, fpsString.c_str());
    
}

- (vtkSmartPointer<vtkCornerAnnotation>)createCornerAnnotation
{
    auto cornerAnnotation = vtkSmartPointer<vtkCornerAnnotation>::New();
    cornerAnnotation->SetLinearFontScaleFactor(8);
    cornerAnnotation->SetNonlinearFontScaleFactor(4);
    cornerAnnotation->SetMaximumFontSize(32);
    cornerAnnotation->GetTextProperty()->SetColor(0.2, 0.6, 0.2);
    return cornerAnnotation;
}

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

- (void) showActivityIndicator:(bool)show { [self showActivityIndicator:show info:@""]; }
- (void) showActivityIndicator:(bool)show info:(NSString*)info
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressBarVtk->SetVisibility(show);
        [UIView animateWithDuration:0.5 animations:^{
            self.inProgressLabel.text = info;
            self.inProgressLabel.hidden = !show;
            [self enabledVtkControls:!show];
            if (show) {
                self.activityIndicator.hidden = NO;
                [self.activityIndicator startAnimating];
                [self.view bringSubviewToFront:self.activityIndicator];
            } else {
                self.activityIndicator.hidden = YES;
                [self.activityIndicator stopAnimating];
            }
        }];
    });
}

- (void) presentDocumentInteractionController
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Present document interaction controller
        [self.documentInteractionController presentOptionsMenuFromBarButtonItem:self.exportBarButtonItem animated:true];
    });
}

- (void) enabledVtkControls:(bool)enable
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.importButton setEnabled:enable];
        [self.exportBarButtonItem setEnabled:enable];
        [self.resetCameraPositionButton setEnabled:enable];
        [self.outlierFilterButton setEnabled:enable];
//        [self.simplifyCloudButton setEnabled:enable];
//        [self.surfaceReconstructionButton setEnabled:enable];
        [self.revertButton setEnabled:(self.revertablePolyData != nil)];
    });
}

@end

