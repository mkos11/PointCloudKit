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
: UIViewController<UIGestureRecognizerDelegate, UIDocumentPickerDelegate>

- (instancetype _Nonnull)initWithCoder:(NSCoder *_Nonnull)coder particlesBuffer:(id<MTLBuffer>_Nonnull)particlesBuffer;

- (void)loadFiles:(nonnull NSArray<NSURL*>*)urls;

@end
