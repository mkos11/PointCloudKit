//
//  VTKViewerViewController.h
//  VTKViewer
//
//  Created by Max Smolens on 6/19/17.
//  Copyright © 2017 Kitware, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

@interface VTKViewerViewController
: UIViewController<UIGestureRecognizerDelegate, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate>

- (instancetype _Nonnull)initWithCoder:(NSCoder *_Nonnull)coder
                       particlesBuffer:(id<MTLBuffer>_Nullable)particlesBuffer
                           captureSize:(int)captureSize;

- (void)loadFiles:(nonnull NSArray<NSURL*>*)urls;

@end
