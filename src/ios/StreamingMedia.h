#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Cordova/CDVPlugin.h>
#import <AVFoundation/AVFoundation.h>

@interface StreamingMedia : CDVPlugin
@property (nonatomic, strong) AVAudioSession* avSession;

- (void)playVideoAsset:(CDVInvokedUrlCommand*)command;
- (void)playVideoURL:(CDVInvokedUrlCommand*)command;
- (void)playAudio:(CDVInvokedUrlCommand*)command;

@end
