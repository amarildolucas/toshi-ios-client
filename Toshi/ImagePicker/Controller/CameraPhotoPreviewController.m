#import "CameraPhotoPreviewController.h"

#import <objc/runtime.h>

#import "CameraShotMetadata.h"
#import "PhotoEditorValues.h"
#import "PhotoEditorUtils.h"
#import "ImageUtils.h"
#import "Hacks.h"
#import "UIImage+TG.h"

#import "ImageView.h"
#import "ModernGalleryZoomableScrollView.h"

#import "FullscreenContainerView.h"
#import "OverlayControllerWindow.h"
#import "PhotoEditorController.h"
#import "PhotoEditorTabController.h"
#import "PhotoToolbarView.h"
#import "PhotoEditorAnimation.h"

#import "MediaAssetsLibrary.h"
#import "UIImage+MediaEditableItem.h"
#import "PaintingData.h"

#import "Common.h"
#import "PhotoCaptionInputMixin.h"

@interface CameraPhotoPreviewWrapperView : UIView

@end

@implementation CameraPhotoPreviewWrapperView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view != self)
        return view;
    
    return nil;
}

@end

@interface CameraPhotoPreviewController () <UIScrollViewDelegate>
{
    MediaEditingContext *_editingContext;
    
    UIImage *_image;
    CameraShotMetadata *_metadata;
    
    CameraPhotoPreviewWrapperView *_wrapperView;
    UIView *_transitionParentView;
    ModernGalleryZoomableScrollView *_scrollView;
    ImageView *_imageView;
    UIView *_temporaryRepView;
    CGSize _imageSize;
    
    PhotoToolbarView *_portraitToolbarView;
    PhotoToolbarView *_landscapeToolbarView;
    
    bool _transitionInProgress;
    bool _dismissing;
    
    NSString *_backButtonTitle;
    
    PhotoCaptionInputMixin *_captionMixin;
    CGFloat _scrollViewVerticalOffset;
}

@property (nonatomic, weak) PhotoEditorController *editorController;

@end

@implementation CameraPhotoPreviewController

- (instancetype)initWithImage:(UIImage *)image metadata:(CameraShotMetadata *)metadata
{
    return [self initWithImage:image metadata:metadata backButtonTitle:TGLocalized(@"Retake")];
}

- (instancetype)initWithImage:(UIImage *)image metadata:(CameraShotMetadata *)metadata backButtonTitle:(NSString *)backButtonTitle
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
        _metadata = metadata;
        _imageSize = image.size;
        
        _editingContext = [[MediaEditingContext alloc] init];
        
        self.automaticallyManageScrollViewInsets = false;
        
        _backButtonTitle = backButtonTitle;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    object_setClass(self.view, [FullscreenContainerView class]);
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor clearColor];
    
    _transitionParentView = [[UIView alloc] initWithFrame:self.view.bounds];
    _transitionParentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_transitionParentView];
    
    CGRect containerFrame = self.view.bounds;
    CGSize fittedSize = ScaleToSize(_image.size, containerFrame.size);
    
    _scrollView = [[ModernGalleryZoomableScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.clipsToBounds = false;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.showsVerticalScrollIndicator = false;
    [self.view addSubview:_scrollView];
    
    _imageView = [[ImageView alloc] initWithFrame:CGRectMake(0, 0, fittedSize.width, fittedSize.height)];
    [self.view addSubview:_imageView];
    
    __weak CameraPhotoPreviewController *weakSelf = self;
    void (^fadeOutRepView)(void) = ^
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_temporaryRepView == nil)
            return;
        
        UIView *repView = strongSelf->_temporaryRepView;
        strongSelf->_temporaryRepView = nil;
        [UIView animateWithDuration:0.2f animations:^
         {
             repView.alpha = 0.0f;
         } completion:^(__unused BOOL finished)
         {
             [repView removeFromSuperview];
         }];
    };
    
    MediaEditingContext *editingContext = _editingContext;
    
    SSignal *assetSignal = [SSignal single:_image];
    SSignal *imageSignal = assetSignal;
    if (editingContext != nil)
    {
        imageSignal = [[[editingContext imageSignalForItem:_image] deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(id result)
                       {
                           __strong CameraPhotoPreviewController *strongSelf = weakSelf;
                           if (strongSelf == nil)
                               return [SSignal complete];
                           
                           if (result == nil)
                           {
                               return [[assetSignal deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                                       {
                                           fadeOutRepView();
                                       }];
                           }
                           else if ([result isKindOfClass:[UIView class]])
                           {
                               [strongSelf _setTemporaryRepView:result];
                               return [[SSignal single:nil] deliverOn:[SQueue mainQueue]];
                           }
                           else
                           {
                               return [[[SSignal single:result] deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                                       {
                                           fadeOutRepView();
                                       }];
                           }
                       }];
    }
    
    [_imageView setSignal:[[imageSignal deliverOn:[SQueue mainQueue]] afterNext:^(id next)
                           {
                               __strong CameraPhotoPreviewController *strongSelf = weakSelf;
                               if (strongSelf == nil)
                                   return;
                               
                               if ([next isKindOfClass:[UIImage class]])
                                   strongSelf->_imageSize = ((UIImage *)next).size;
                               
                               [strongSelf reset];
                           }]];
    
    _wrapperView = [[CameraPhotoPreviewWrapperView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    void (^cancelPressed)(void) = ^
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.retakePressed != nil)
            strongSelf.retakePressed();
        
        [strongSelf transitionOutWithCompletion:^
         {
             [strongSelf dismiss];
         }];
    };
    
    void (^donePressed)(void) = ^
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_dismissing)
            return;
        
        strongSelf->_dismissing = true;
        strongSelf.view.userInteractionEnabled = false;
    
            [[[MediaAssetsLibrary sharedLibrary] saveAssetWithImage:strongSelf->_image] startWithNext:nil];
            {
                [[[[[[editingContext fullSizeImageUrlForItem:strongSelf->_image] filter:^bool(id result)
                     {
                         return [result isKindOfClass:[NSURL class]];
                     }] startOn:[SQueue concurrentDefaultQueue]] deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(NSURL *url)
                  {
                      return [[[MediaAssetsLibrary sharedLibrary] saveAssetWithImageAtUrl:url] onCompletion:^
                              {
                                  __strong MediaEditingContext *strongEditingContext = editingContext;
                                  [strongEditingContext description];
                              }];
                  }] startWithNext:nil];
            }
        
        SSignal *originalSignal = [[[SSignal single:strongSelf->_image] map:^id(UIImage *image)
                                    {
                                        return PhotoEditorCrop(image, nil, UIImageOrientationUp, 0, CGRectMake(0, 0, image.size.width, image.size.height), false, CGSizeMake(1280, 1280), image.size, true);
                                    }] startOn:[SQueue concurrentDefaultQueue]];
        
        SSignal *imageSignal = originalSignal;
        if (editingContext != nil)
        {
            imageSignal = [[[[editingContext imageSignalForItem:strongSelf->_image withUpdates:true] filter:^bool(id result)
                             {
                                 return result == nil || ([result isKindOfClass:[UIImage class]] && !((UIImage *)result).degraded);
                             }] take:1] mapToSignal:^SSignal *(id result)
                           {
                               if (result == nil)
                               {
                                   return originalSignal;
                               }
                               else if ([result isKindOfClass:[UIImage class]])
                               {
                                   UIImage *image = (UIImage *)result;
                                   image.edited = true;
                                   return [SSignal single:image];
                               }
                               
                               return [SSignal complete];
                           }];
        }
        
        NSString *caption = [editingContext captionForItem:strongSelf->_image];
        NSArray *stickers = [editingContext adjustmentsForItem:strongSelf->_image].paintingData.stickers;
        [[imageSignal deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *result)
         {
              strongSelf.sendPressed(result, caption, stickers);
         }];
    };
    
    void (^tabPressed)(PhotoEditorTab) = ^(PhotoEditorTab tab)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf presentPhotoEditorWithTab:tab];
    };
    
    PhotoEditorTab tabs = PhotoEditorNoneTab;
    if (self.allowCaptions)
        tabs |= PhotoEditorCaptionTab;
    
    tabs |= PhotoEditorCropTab;
    
    if (iosMajorVersion() >= 7)
    {
        tabs |= PhotoEditorToolsTab;
    }
    
    _portraitToolbarView = [[PhotoToolbarView alloc] initWithBackButtonTitle:_backButtonTitle doneButtonTitle:TGLocalized(@"Send") accentedDone:false solidBackground:false];
    [_portraitToolbarView setToolbarTabs:tabs animated:false];
    _portraitToolbarView.cancelPressed = cancelPressed;
    _portraitToolbarView.donePressed = donePressed;
    _portraitToolbarView.tabPressed = tabPressed;
    [_wrapperView addSubview:_portraitToolbarView];
    
    _landscapeToolbarView = [[PhotoToolbarView alloc] initWithBackButtonTitle:_backButtonTitle doneButtonTitle:TGLocalized(@"Send") accentedDone:false solidBackground:false];
    [_landscapeToolbarView setToolbarTabs:tabs animated:false];
    _landscapeToolbarView.cancelPressed = cancelPressed;
    _landscapeToolbarView.donePressed = donePressed;
    _landscapeToolbarView.tabPressed = tabPressed;
    [_wrapperView addSubview:_landscapeToolbarView];
    
    _captionMixin = [[PhotoCaptionInputMixin alloc] init];
    _captionMixin.panelParentView = ^UIView *
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        return strongSelf->_wrapperView;
    };
    
    _captionMixin.panelFocused = ^
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    };
    
    _captionMixin.finishedWithCaption = ^(NSString *caption)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_editingContext setCaption:caption forItem:strongSelf->_image];
        
        PhotoEditorValues *values = (PhotoEditorValues *)[strongSelf->_editingContext adjustmentsForItem:strongSelf->_image];
        [strongSelf updateEditorButtonsForEditorValues:values];
    };
    
    _captionMixin.keyboardHeightChanged = ^(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        CGFloat offset = 0.0f;
        if (keyboardHeight > 0)
            offset = -keyboardHeight / 2.0f;
        
        [UIView animateWithDuration:duration delay:0.0f options:animationCurve animations:^
         {
             [strongSelf setScrollViewVerticalOffset:offset];
         } completion:nil];
    };
    _captionMixin.suggestionContext = self.suggestionContext;
    [_captionMixin createInputPanelIfNeeded];
}

- (void)_setTemporaryRepView:(UIView *)view
{
    [_temporaryRepView removeFromSuperview];
    _temporaryRepView = view;
    
    _imageSize = ScaleToSize(view.frame.size, self.view.frame.size);
    
    view.hidden = _imageView.hidden;
    view.frame = CGRectMake((self.view.frame.size.width - _imageSize.width) / 2.0f, (self.view.frame.size.height - _imageSize.height) / 2.0f, _imageSize.width, _imageSize.height);
    
    [self.view insertSubview:view belowSubview:_wrapperView];
}

- (void)dismiss
{
    if (self.overlayWindow != nil)
    {
        [super dismiss];
    }
    else
    {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self transitionIn];
}

#pragma mark - Transition

- (void)transitionIn
{
    _transitionInProgress = true;
    
//    _captionMixin.inputPanel.alpha = 0.0f;
//    _portraitToolbarView.alpha = 0.0f;
//    _landscapeToolbarView.alpha = 0.0f;
//    
//    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveLinear animations:^
//     {
         _captionMixin.inputPanel.alpha = 1.0f;
         _portraitToolbarView.alpha = 1.0f;
         _landscapeToolbarView.alpha = 1.0f;
    // } completion:nil];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    CGSize referenceSize = [self referenceViewSizeForOrientation:self.interfaceOrientation];
    CGRect referenceFrame = CGRectZero;
    if (self.beginTransitionIn != nil)
        referenceFrame = self.beginTransitionIn();
    
    CGRect containerFrame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
    CGSize fittedSize = ScaleToSize(_imageView.image.size, containerFrame.size);
    CGRect targetFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                    containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                    fittedSize.width,
                                    fittedSize.height);
    
    CGFloat referenceAspectRatio = referenceFrame.size.width / referenceFrame.size.height;
    CGFloat targetAspectRatio = targetFrame.size.width / targetFrame.size.height;
    
    if (ABS(targetAspectRatio - referenceAspectRatio) > 0.03f)
    {
        CGSize newSize = CGSizeZero;
        if (referenceFrame.size.width > referenceFrame.size.height)
            newSize = CGSizeMake(referenceFrame.size.width, _imageView.image.size.height * referenceFrame.size.width / _imageView.image.size.width);
        else
            newSize = CGSizeMake(_imageView.image.size.width * referenceFrame.size.height / _imageView.image.size.height, referenceFrame.size.height);
        
        referenceFrame = CGRectMake(CGRectGetMidX(referenceFrame) - newSize.width / 2,
                                    CGRectGetMidY(referenceFrame) - newSize.height / 2,
                                    newSize.width, newSize.height);
    }
    
    _imageView.frame = referenceFrame;
   
    _transitionInProgress = false;
    [_scrollView addSubview:_imageView];
    
    
    [self reset];
    if (self.finishedTransitionIn != nil)
        self.finishedTransitionIn();
}

- (void)transitionOutWithCompletion:(void (^)(void))completion
{
    _transitionInProgress = true;
    
    self.view.backgroundColor = [UIColor clearColor];
    
    CGRect frame = [self.view convertRect:_imageView.frame fromView:_scrollView];
    [self.view addSubview:_imageView];
    _imageView.frame = frame;
    
    CGSize referenceSize = [self referenceViewSizeForOrientation:self.interfaceOrientation];
    CGRect referenceFrame = _imageView.frame;
    
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        referenceFrame = CGRectMake(referenceSize.height - referenceFrame.size.height - referenceFrame.origin.y,
                                    referenceFrame.origin.x,
                                    referenceFrame.size.height, referenceFrame.size.width);
    }
    else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        referenceFrame = CGRectMake(referenceFrame.origin.y,
                                    referenceSize.width - referenceFrame.size.width - referenceFrame.origin.x,
                                    referenceFrame.size.height, referenceFrame.size.width);
    }
    
    CGRect targetFrame = CGRectZero;
    if (self.beginTransitionOut != nil)
        targetFrame = self.beginTransitionOut(referenceFrame);
    
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
    {
        targetFrame = CGRectMake(referenceSize.width - targetFrame.size.height - targetFrame.origin.y,
                                 targetFrame.origin.x,
                                 targetFrame.size.height, targetFrame.size.width);
    }
    else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        targetFrame = CGRectMake(targetFrame.origin.y,
                                 referenceSize.height - targetFrame.size.width - targetFrame.origin.x,
                                 targetFrame.size.height, targetFrame.size.width);
    }
    
    CGFloat referenceAspectRatio = referenceFrame.size.width / referenceFrame.size.height;
    CGFloat targetAspectRatio = targetFrame.size.width / targetFrame.size.height;
    
    if (ABS(targetAspectRatio - referenceAspectRatio) > 0.03f)
    {
        CGSize newSize = CGSizeZero;
        if (targetFrame.size.width > targetFrame.size.height)
            newSize = CGSizeMake(targetFrame.size.width, _imageView.image.size.height * targetFrame.size.width / _imageView.image.size.width);
        else
            newSize = CGSizeMake(_imageView.image.size.width * targetFrame.size.height / _imageView.image.size.height, targetFrame.size.height);
        
        targetFrame = CGRectMake(CGRectGetMidX(targetFrame) - newSize.width / 2,
                                 CGRectGetMidY(targetFrame) - newSize.height / 2,
                                 newSize.width, newSize.height);
    }
    
    POPSpringAnimation *animation = [PhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    animation.fromValue = [NSValue valueWithCGRect:_imageView.frame];
    animation.toValue = [NSValue valueWithCGRect:targetFrame];
    [_imageView pop_addAnimation:animation forKey:@"frame"];
    
    [UIView animateWithDuration:0.3f animations:^
     {
         _imageView.alpha = 0.0f;
         _portraitToolbarView.alpha = 0.0f;
         _landscapeToolbarView.alpha = 0.0f;
         _captionMixin.inputPanel.alpha = 0.0f;
     } completion:^(__unused BOOL finished)
     {
         if (completion != nil)
             completion();
     }];
}

#pragma mark - Scroll View

- (void)scrollViewDidZoom:(UIScrollView *)__unused scrollView
{
    [self adjustZoom];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view atScale:(CGFloat)__unused scale
{
    [self adjustZoom];
    
    if (_scrollView.zoomScale < _scrollView.normalZoomScale - FLT_EPSILON)
    {
        [Hacks setAnimationDurationFactor:0.5f];
        [_scrollView setZoomScale:_scrollView.normalZoomScale animated:true];
        [Hacks setAnimationDurationFactor:1.0f];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    if (_imageView.superview == scrollView)
        return _imageView;
    
    return nil;
}

- (CGSize)contentSize
{
    return _imageSize;
}

- (void)reset
{
    CGSize contentSize = [self contentSize];
    
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 1.0f;
    _scrollView.normalZoomScale = 1.0f;
    _scrollView.zoomScale = 1.0f;
    _scrollView.contentSize = contentSize;
    _imageView.frame = CGRectMake(0.0f, 0.0f, contentSize.width, contentSize.height);
    
    [self adjustZoom];
    _scrollView.zoomScale = _scrollView.normalZoomScale;
}

- (void)adjustZoom
{
    CGSize contentSize = [self contentSize];
    CGSize boundsSize = _scrollView.frame.size;
    if (contentSize.width < FLT_EPSILON || contentSize.height < FLT_EPSILON || boundsSize.width < FLT_EPSILON || boundsSize.height < FLT_EPSILON)
        return;
    
    CGFloat scaleWidth = boundsSize.width / contentSize.width;
    CGFloat scaleHeight = boundsSize.height / contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    CGFloat maxScale = MAX(scaleWidth, scaleHeight);
    maxScale = MAX(maxScale, minScale * 3.0f);
    
    if (ABS(maxScale - minScale) < 0.01f)
        maxScale = minScale;
    
    if (_scrollView.minimumZoomScale != 0.05f)
        _scrollView.minimumZoomScale = 0.05f;
    if (_scrollView.normalZoomScale != minScale)
        _scrollView.normalZoomScale = minScale;
    if (_scrollView.maximumZoomScale != maxScale)
        _scrollView.maximumZoomScale = maxScale;
    
    CGRect contentFrame = _imageView.frame;
    
    if (boundsSize.width > contentFrame.size.width)
        contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0f;
    else
        contentFrame.origin.x = 0;
    
    if (boundsSize.height > contentFrame.size.height)
        contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0f;
    else
        contentFrame.origin.y = 0;
    
    _imageView.frame = contentFrame;
}

#pragma mark -

- (void)updateEditorButtonsForEditorValues:(PhotoEditorValues *)editorValues
{
    PhotoEditorTab highlightedButtons = [PhotoEditorTabController highlightedButtonsForEditorValues:editorValues forAvatar:false];
    [_portraitToolbarView setEditButtonsHighlighted:highlightedButtons];
    [_landscapeToolbarView setEditButtonsHighlighted:highlightedButtons];
}

- (UIView *)transitionContentView
{
    if (_temporaryRepView != nil)
        return _temporaryRepView;
    
    return _imageView;
}

- (CGRect)transitionViewContentRect
{
    UIView *contentView = [self transitionContentView];
    return [self.view convertRect:contentView.frame fromView:contentView.superview];
}

- (void)presentPhotoEditorWithTab:(PhotoEditorTab)tab
{
    __weak CameraPhotoPreviewController *weakSelf = self;
    
    id<MediaEditableItem> editableMediaItem = _image;
    
    UIView *referenceView = [self transitionContentView];
    CGRect refFrame = [self transitionViewContentRect];
    UIImage *screenImage = nil;
    if ([referenceView isKindOfClass:[UIImageView class]])
        screenImage = [(UIImageView *)referenceView image];
    
    PhotoEditorValues *editorValues = (PhotoEditorValues *)[_editingContext adjustmentsForItem:_image];
    NSString *caption = [_editingContext captionForItem:_image];
    
    PhotoEditorController *controller = [[PhotoEditorController alloc] initWithItem:editableMediaItem intent:PhotoEditorControllerFromCameraIntent adjustments:editorValues caption:caption screenImage:screenImage availableTabs:_portraitToolbarView.currentTabs selectedTab:tab];
    controller.editingContext = _editingContext;
    self.editorController = controller;
    controller.metadata = _metadata;
    controller.suggestionContext = self.suggestionContext;
    controller.didFinishRenderingFullSizeImage = ^(UIImage *image)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_editingContext setFullSizeImage:image forItem:strongSelf->_image];
    };
    controller.willFinishEditing = ^(PhotoEditorValues *editorValues, id temporaryRep, bool hasChanges)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (hasChanges)
        {
            [strongSelf->_editingContext setAdjustments:editorValues forItem:strongSelf->_image];
            [strongSelf->_editingContext setTemporaryRep:temporaryRep forItem:strongSelf->_image];
        }
    };
    controller.didFinishEditing = ^(PhotoEditorValues *editorValues, UIImage *resultImage, __unused UIImage *thumbnailImage, bool hasChanges)
    {
#ifdef DEBUG
        if (editorValues != nil && hasChanges)
            NSAssert(resultImage != nil, @"resultImage should not be nil");
#endif
        
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (hasChanges)
            [strongSelf->_editingContext setImage:resultImage thumbnailImage:nil forItem:strongSelf->_image synchronous:false];
        
        PhotoEditorValues *values = !hasChanges ? (PhotoEditorValues *)[strongSelf->_editingContext adjustmentsForItem:strongSelf->_image] : editorValues;
        [strongSelf updateEditorButtonsForEditorValues:values];
        
        [strongSelf reset];
    };
    
    controller.captionSet = ^(NSString *caption)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf reset];
        
        [strongSelf->_editingContext setCaption:caption forItem:strongSelf->_image];
    };
    
    controller.requestToolbarsHidden = ^(bool hidden, bool animated)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setToolbarsHidden:hidden animated:animated];
    };
    
    controller.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        [strongSelf editorTransitionIn];
        
        if (strongSelf.photoEditorShown != nil)
            strongSelf.photoEditorShown();
        
        strongSelf->_imageView.hidden = true;
        strongSelf->_temporaryRepView.hidden = true;
        
        *parentView = strongSelf->_transitionParentView;
        *referenceFrame = refFrame;
        
        [strongSelf reset];
        
        if (iosMajorVersion() >= 7)
            [strongSelf setNeedsStatusBarAppearanceUpdate];
        else
            [[UIApplication sharedApplication] setStatusBarHidden:true];
        
        return referenceView;
    };
    
    controller.beginTransitionOut = ^UIView *(CGRect *referenceFrame, UIView **parentView)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        [strongSelf editorTransitionOut];
        
        *parentView = strongSelf->_transitionParentView;
        *referenceFrame = [strongSelf transitionViewContentRect];
        
        return [strongSelf transitionContentView];
    };
    
    controller.finishedTransitionOut = ^(__unused bool saved)
    {
        __strong CameraPhotoPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.photoEditorHidden != nil)
            strongSelf.photoEditorHidden();
        
        strongSelf->_imageView.hidden = false;
        strongSelf->_temporaryRepView.hidden = false;
        
        if (iosMajorVersion() >= 7)
            [strongSelf setNeedsStatusBarAppearanceUpdate];
        else
            [[UIApplication sharedApplication] setStatusBarHidden:false];
    };
    
    controller.requestThumbnailImage = ^(id<MediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    controller.requestOriginalScreenSizeImage = ^(id<MediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    
    controller.requestOriginalFullSizeImage = ^(id<MediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem originalImageSignal:position];
    };
    
    controller.view.clipsToBounds = true;
    
    [self presentViewController:controller animated:NO completion:nil];
}

- (void)setToolbarsHidden:(bool)hidden animated:(bool)animated
{
    if (hidden)
    {
        [_portraitToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
        [_landscapeToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
    }
    else
    {
        [_portraitToolbarView transitionInAnimated:animated transparent:true];
        [_landscapeToolbarView transitionInAnimated:animated transparent:true];
    }
}

- (void)editorTransitionIn
{
    [UIView animateWithDuration:0.2 animations:^
     {
         _captionMixin.inputPanel.alpha = 0.0f;
     }];
}

- (void)editorTransitionOut
{
    [UIView animateWithDuration:0.3 animations:^
     {
         _captionMixin.inputPanel.alpha = 1.0f;
     }];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [_imageView pop_removeAllAnimations];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)setScrollViewVerticalOffset:(CGFloat)offset
{
    _scrollViewVerticalOffset = offset;
    
    CGRect scrollViewFrame = _scrollView.frame;
    scrollViewFrame.origin.y = offset;
    _scrollView.frame = scrollViewFrame;
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    UIInterfaceOrientation originalOrientation = orientation;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        _landscapeToolbarView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSizeForOrientation:originalOrientation];
    
    [_captionMixin setContentAreaHeight:self.view.frame.size.height];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    
    _landscapeToolbarView.interfaceOrientation = orientation;
    
    CGFloat portraitToolbarViewBottomEdge = screenSide;
    if (TGIsPad())
        portraitToolbarViewBottomEdge = screenEdges.bottom;
    _portraitToolbarView.frame = CGRectMake(screenEdges.left, portraitToolbarViewBottomEdge - PhotoEditorToolbarSize, referenceSize.width, PhotoEditorToolbarSize);
    
    UIEdgeInsets captionEdgeInsets = screenEdges;
    captionEdgeInsets.bottom = _portraitToolbarView.frame.size.height;
    [_captionMixin updateLayoutWithFrame:self.view.bounds edgeInsets:captionEdgeInsets];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
             {
                 _landscapeToolbarView.frame = CGRectMake(screenEdges.left, screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
             }];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
             {
                 _landscapeToolbarView.frame = CGRectMake(screenEdges.right - [_landscapeToolbarView landscapeSize], screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
             }];
        }
            break;
            
        default:
        {
            _landscapeToolbarView.frame = CGRectMake(_landscapeToolbarView.frame.origin.x, screenEdges.top, [_landscapeToolbarView landscapeSize], referenceSize.height);
        }
            break;
    }
    
    if (_transitionInProgress)
        return;
    
    if (!CGRectEqualToRect(_scrollView.frame, self.view.bounds))
    {
        _scrollView.frame = CGRectMake(0.0f, _scrollViewVerticalOffset, self.view.bounds.size.width, self.view.bounds.size.height);
        [self reset];
    }
}

@end
