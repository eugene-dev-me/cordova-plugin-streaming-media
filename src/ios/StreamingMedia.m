#import "StreamingMedia.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "LandscapeVideo.h"
#import "PortraitVideo.h"
#import <Photos/Photos.h>

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
//#import "MPAudioDeviceController.h"


@interface StreamingMedia()
- (void)parseOptions:(NSDictionary *) options type:(NSString *) type;
- (void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type;
- (void)setBackgroundColor:(NSString *)color;
- (void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType;
- (UIImage*)getImage: (NSString *)imageName;
- (void)startPlayer:(NSString*)uri;
- (void)moviePlayBackDidFinish:(NSNotification*)notification;
- (void)cleanup;
@end

@implementation StreamingMedia {
    NSString* callbackId;
    AVPlayerViewController *moviePlayer;
    BOOL shouldAutoClose;
    UIColor *backgroundColor;
    UIImageView *imageView;
    BOOL initFullscreen;
    BOOL playerStarted;

    NSString *mOrientation;
    NSString *videoType;
    AVPlayer *movie;
}

NSString * const TYPE_VIDEO = @"VIDEO";
NSString * const TYPE_AUDIO = @"AUDIO";
NSString * const DEFAULT_IMAGE_SCALE = @"center";

-(void)parseOptions:(NSDictionary *)options type:(NSString *) type {
    // Common options
    mOrientation = options[@"orientation"] ?: @"default";

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"shouldAutoClose"]) {
        shouldAutoClose = [[options objectForKey:@"shouldAutoClose"] boolValue];
    } else {
        shouldAutoClose = YES;
    }
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
        [self setBackgroundColor:[options objectForKey:@"bgColor"]];
    } else {
        backgroundColor = [UIColor blackColor];
    }

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"initFullscreen"]) {
        initFullscreen = [[options objectForKey:@"initFullscreen"] boolValue];
    } else {
        initFullscreen = YES;
    }

    if ([type isEqualToString:TYPE_AUDIO]) {
        videoType = TYPE_AUDIO;

        // bgImage
        // bgImageScale
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImage"]) {
            NSString *imageScale = DEFAULT_IMAGE_SCALE;
            if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImageScale"]) {
                imageScale = [options objectForKey:@"bgImageScale"];
            }
            [self setImage:[options objectForKey:@"bgImage"] withScaleType:imageScale];
        }
        // bgColor
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
            NSLog(@"Found option for bgColor");
            [self setBackgroundColor:[options objectForKey:@"bgColor"]];
        } else {
            backgroundColor = [UIColor blackColor];
        }
    } else {
        // Reset overlay on video player after playing audio
        [self cleanup];
    }
    // No specific options for video yet
}

-(void)playasset:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    NSLog(@"play called");
    callbackId = command.callbackId;
    NSString *assetId  = [command.arguments objectAtIndex:0];
    [self parseOptions:[command.arguments objectAtIndex:1] type:type];

    PHFetchResult<PHAsset*>* fetchResultAssets
    = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil];

    PHAsset* asset = fetchResultAssets.firstObject;

    PHVideoRequestOptions* reqOptions = [[PHVideoRequestOptions alloc] init];
    reqOptions.networkAccessAllowed = YES;


    __typeof__(self) __weak weakSelf = self;


    [[PHImageManager defaultManager]
            requestAVAssetForVideo:asset
            options:reqOptions
            resultHandler:^(AVAsset * avasset, AVAudioMix * audioMix, NSDictionary * info) {

            [weakSelf startPlayerAsset:avasset];
    }];
}

-(void)playurl:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    NSLog(@"play called");
    callbackId = command.callbackId;
    NSString *mediaUrl  = [command.arguments objectAtIndex:0];
    [self parseOptions:[command.arguments objectAtIndex:1] type:type];

    [self startPlayerURL:mediaUrl];
}

-(void)stop:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    NSLog(@"stop called");
    callbackId = command.callbackId;
    if (moviePlayer.player) {
        [moviePlayer.player pause];
    }
}

-(void)playVideoAsset:(CDVInvokedUrlCommand *) command {
    NSLog(@"playvideo called");
    [self ignoreMute];
    [self playasset:command type:[NSString stringWithString:TYPE_VIDEO]];
}

-(void)getAirPlayActive:(CDVInvokedUrlCommand *) command {
    bool air_play_active = [self isAirplayOn];
    NSLog(air_play_active ? @"Yes 1" : @"No 1");

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:air_play_active];

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}

-(void)setPrePlay:(CDVInvokedUrlCommand *) command {
    playerStarted = false;
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}

-(void)playVideoURL:(CDVInvokedUrlCommand *) command {
    NSLog(@"playvideo called");
    [self ignoreMute];
    [self playurl:command type:[NSString stringWithString:TYPE_VIDEO]];
}

-(void)playAudio:(CDVInvokedUrlCommand *) command {
    NSLog(@"playaudio called");
    [self ignoreMute];
    [self play:command type:[NSString stringWithString:TYPE_AUDIO]];
}

-(void)stopAudio:(CDVInvokedUrlCommand *) command {
    [self stop:command type:[NSString stringWithString:TYPE_AUDIO]];
}

-(void)removeVideo:(CDVInvokedUrlCommand *) command {
    [self _removeVideo];
}

-(void)_removeVideo {
    if (moviePlayer) {
        [moviePlayer.player pause];
        [moviePlayer dismissViewControllerAnimated:NO completion:nil];
        moviePlayer = nil;
    }

    playerStarted = false;

    [self fireEvent:@"Closed"];
}


// Ignore the mute button
-(void)ignoreMute {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

-(void) setBackgroundColor:(NSString *)color {
    NSLog(@"setbackgroundcolor called");
    if ([color hasPrefix:@"#"]) {
        // HEX value
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:color];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        backgroundColor = [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
    } else {
        // Color name
        NSString *selectorString = [[color lowercaseString] stringByAppendingString:@"Color"];
        SEL selector = NSSelectorFromString(selectorString);
        UIColor *colorObj = [UIColor blackColor];
        if ([UIColor respondsToSelector:selector]) {
            colorObj = [UIColor performSelector:selector];
        }
        backgroundColor = colorObj;
    }
}

-(UIImage*)getImage: (NSString *)imageName {
    NSLog(@"getimage called");
    UIImage *image = nil;
    if (imageName != (id)[NSNull null]) {
        if ([imageName hasPrefix:@"http"]) {
            // Web image
            image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageName]]];
        } else if ([imageName hasPrefix:@"www/"]) {
            // Asset image
            image = [UIImage imageNamed:imageName];
        } else if ([imageName hasPrefix:@"file://"]) {
            // Stored image
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSURL URLWithString:imageName] path]]];
        } else if ([imageName hasPrefix:@"data:"]) {
            // base64 encoded string
            NSURL *imageURL = [NSURL URLWithString:imageName];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            image = [UIImage imageWithData:imageData];
        } else {
            // explicit path
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:imageName]];
        }
    }
    return image;
}

- (void)orientationChanged:(NSNotification *)notification {
    NSLog(@"orientationchanged called");
    if (imageView != nil) {
        // adjust imageView for rotation
        imageView.bounds = moviePlayer.contentOverlayView.bounds;
        imageView.frame = moviePlayer.contentOverlayView.frame;
    }
}

- (void)handleScreenDidDisconnectNotification:(NSNotification *)notification {
    NSLog(@"screen did disconnect called");
}

- (void)handleScreenDidConnectNotification:(NSNotification *)notification {
    NSLog(@"screen did connect");
}

- (void)audioRouteHasChangedNotification:(NSNotification *)notification {
    NSLog(@"audio route has changed notification");
}


-(void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType {
    NSLog(@"setimage called");
    imageView = [[UIImageView alloc] initWithFrame:self.viewController.view.bounds];

    if (imageScaleType == nil) {
        NSLog(@"imagescaletype was NIL");
        imageScaleType = DEFAULT_IMAGE_SCALE;
    }

    if ([imageScaleType isEqualToString:@"stretch"]){
        // Stretches image to fill all available background space, disregarding aspect ratio
        imageView.contentMode = UIViewContentModeScaleToFill;
    } else if ([imageScaleType isEqualToString:@"fit"]) {
        // fits entire image perfectly
        imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else if ([imageScaleType isEqualToString:@"aspectStretch"]) {
        // Stretches image to fill all possible space while retaining aspect ratio
        imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        // Places image in the center of the screen
        imageView.contentMode = UIViewContentModeCenter;
        //moviePlayer.backgroundView.contentMode = UIViewContentModeCenter;
    }

    [imageView setImage:[self getImage:imagePath]];
}

-(void)startPlayerAsset:(AVAsset*)asset {
    NSLog(@"startplayer called");

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    movie =  [AVPlayer playerWithPlayerItem:playerItem];

    dispatch_async(dispatch_get_main_queue(), ^{
       // handle orientation
       [self handleOrientation];

       // handle gestures
       [self handleGestures];

       [moviePlayer setPlayer:movie];
       [moviePlayer setShowsPlaybackControls:YES];
       [moviePlayer setUpdatesNowPlayingInfoCenter:YES];

       if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }

       // present modally so we get a close button

        [self.viewController presentViewController:moviePlayer animated:NO completion:^(void){
            [moviePlayer.player play];
        }];

       // add audio image and background color
       if ([videoType isEqualToString:TYPE_AUDIO]) {
           if (imageView != nil) {
               [moviePlayer.contentOverlayView setAutoresizesSubviews:YES];
               [moviePlayer.contentOverlayView addSubview:imageView];
           }
           moviePlayer.contentOverlayView.backgroundColor = backgroundColor;
           [self.viewController.view addSubview:moviePlayer.view];
       }

       // setup listners
       [self handleListeners];
    });
}

-(void)startPlayerURL:(NSString*)uri {
    NSLog(@"startplayer called");
    NSURL *url             =  [NSURL URLWithString:uri];
    movie                  =  [AVPlayer playerWithURL:url];

    // handle orientation
    [self handleOrientation];

    // handle gestures
    [self handleGestures];

    [moviePlayer setPlayer:movie];
    [moviePlayer setShowsPlaybackControls:YES];
    [moviePlayer setUpdatesNowPlayingInfoCenter:YES];
//    [moviePlayer viewDidDisappear:<#(BOOL)#>]

    if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }

    // present modally so we get a close button
    [self.viewController presentViewController:moviePlayer animated:NO completion:^(void){
        [moviePlayer.player play];
    }];

    // add audio image and background color
    if ([videoType isEqualToString:TYPE_AUDIO]) {
        if (imageView != nil) {
            [moviePlayer.contentOverlayView setAutoresizesSubviews:YES];
            [moviePlayer.contentOverlayView addSubview:imageView];
        }
        moviePlayer.contentOverlayView.backgroundColor = backgroundColor;
        [self.viewController.view addSubview:moviePlayer.view];
    }

    // setup listners
    [self handleListeners];
}

- (void) handleListeners {

    // Listen for re-maximize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // Listen for minimize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    // Listen for playback finishing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];

    // Listen for errors
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];

    // Listen for orientation change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    // Listen for orientation change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleScreenDidDisconnectNotification:)
                                                 name:UIScreenDidDisconnectNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleScreenDidConnectNotification:)
                                                 name:UIScreenDidConnectNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteHasChangedNotification:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];


    if(moviePlayer) {
        [moviePlayer addObserver:self forKeyPath:@"view.frame" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:nil];
    }



    /* Listen for click on the "Done" button

     // Deprecated.. AVPlayerController doesn't offer a "Done" listener... thanks apple. We'll listen for an error when playback finishes
     [[NSNotificationCenter defaultCenter] addObserver:self
     selector:@selector(doneButtonClick:)
     name:MPMoviePlayerWillExitFullscreenNotification
     object:nil];
     */
}


- (BOOL)isAudioSessionUsingAirplayOutputRoute
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSLog(@"Outputs: %@", [[session currentRoute] outputs]);

    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [session setActive:YES error:nil];

//    NSMutableArray *routes = [NSMutableArray array];




//    [view addSubview:volumeView];


    return false;
}

- (BOOL)isAirplayOn
{
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription* currentRoute = audioSession.currentRoute;

    for (AVAudioSessionPortDescription* outputPort in currentRoute.outputs){
        if ([outputPort.portType isEqualToString:AVAudioSessionPortAirPlay])
            return YES;
    }
    return NO;
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"view.frame"]) {
        CGRect newValue = [change[NSKeyValueChangeNewKey]CGRectValue];
        CGFloat y = newValue.origin.y;
        if (y != 0) {
            [self _removeVideo];

            //when animated
//            if(playerStarted) {
//                NSLog(@"Video Closed");
//                [self _removeVideo];
//            } else {
//                playerStarted = true;
//            }

        }
     }

    bool is_air_play_on = [self isAirplayOn];
}

- (void) fireEvent:(NSString*)event
{
    NSString* js = @"plugins.streamingMedia.fireEvent('closed')";

    [self.commandDelegate evalJs:js];
}

- (void) handleGestures {
    // Get buried nested view
    UIView *contentView = [moviePlayer.view valueForKey:@"contentView"];

    // loop through gestures, remove swipes
    for (UIGestureRecognizer *recognizer in contentView.gestureRecognizers) {
        NSLog(@"gesture loop ");
        NSLog(@"%@", recognizer);
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
    }
}

- (void) handleOrientation {
    // hnadle the subclassing of the view based on the orientation variable
    if ([mOrientation isEqualToString:@"landscape"]) {
        moviePlayer            =  [[LandscapeAVPlayerViewController alloc] init];
    } else if ([mOrientation isEqualToString:@"portrait"]) {
        moviePlayer            =  [[PortraitAVPlayerViewController alloc] init];
    } else {
        moviePlayer            =  [[AVPlayerViewController alloc] init];
    }
}

- (void) handleScreenDidDisconnectNotification {
    NSLog(@"screendisconnected");
}

- (void) handleScreenDidConnectNotification {
    NSLog(@"screendisconnected");
}


- (void) appDidEnterBackground:(NSNotification*)notification {
    NSLog(@"appDidEnterBackground");

    if (moviePlayer && movie && videoType == TYPE_AUDIO)
    {
        NSLog(@"did set player layer to nil");
        [moviePlayer setPlayer: nil];
    }
}

- (void) appDidBecomeActive:(NSNotification*)notification {
    NSLog(@"appDidBecomeActive");

    if (moviePlayer && movie && videoType == TYPE_AUDIO)
    {
        NSLog(@"did reinstate playerlayer");
        [moviePlayer setPlayer:movie];
    }
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    NSLog(@"Playback did finish with auto close being %d, and error message being %@", shouldAutoClose, notification.userInfo);
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSNumber *errorValue = [notificationUserInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSString *errorMsg;
    if (errorValue) {
        NSError *mediaPlayerError = [notificationUserInfo objectForKey:@"error"];
        if (mediaPlayerError) {
            errorMsg = [mediaPlayerError localizedDescription];
        } else {
            errorMsg = @"Unknown error.";
        }
        NSLog(@"Playback failed: %@", errorMsg);
    }

    if (shouldAutoClose || [errorMsg length] != 0) {
        [self cleanup];
        CDVPluginResult* pluginResult;
        if ([errorMsg length] != 0) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMsg];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }
}


- (void)cleanup {
    NSLog(@"Clean up called");
    imageView = nil;
    initFullscreen = false;
    backgroundColor = nil;

    // Remove playback finished listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemDidPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove playback finished error listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemFailedToPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove orientation change listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];

    if (moviePlayer) {
        [moviePlayer.player pause];
        [moviePlayer dismissViewControllerAnimated:NO completion:nil];
        moviePlayer = nil;
    }
}
@end
