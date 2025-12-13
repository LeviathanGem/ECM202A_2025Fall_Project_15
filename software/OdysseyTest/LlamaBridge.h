//
//  LlamaBridge.h
//  OdysseyTest
//
//  Thin Objective-C++ bridge around the llama.cpp C API (via LlamaFramework xcframework).
//  This exposes a small, Swifty interface that we can call from Swift.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LlamaBridge : NSObject

/// Initialize llama backend, load model and create a context.
/// Returns nil if the model cannot be loaded.
- (nullable instancetype)initWithModelPath:(NSString *)modelPath;

/// Generate a response for the given prompt.
/// NOTE: Implementation will be filled in a later step.
- (NSString *)generateResponse:(NSString *)prompt
                     maxTokens:(int)maxTokens
                   temperature:(float)temperature
                          topP:(float)topP
                         error:(NSError * _Nullable * _Nullable)error;

/// Explicitly free model and context resources.
- (void)unload;

@end

NS_ASSUME_NONNULL_END


