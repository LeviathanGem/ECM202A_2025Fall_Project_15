//
//  LlamaBridge.mm
//  OdysseyTest
//
//  Objective-C++ implementation that talks directly to the llama.cpp C API
//  exposed by the LlamaFramework xcframework.
//

#import "LlamaBridge.h"

// Import the C API from the LlamaFramework xcframework
// The module name is `llama` and the umbrella header is `llama.h`
#import <llama/llama.h>

#import <vector>
#import <string>
#import <algorithm>

@interface LlamaBridge () {
    struct llama_model   * _model;
    struct llama_context * _ctx;
}
@end

@implementation LlamaBridge

- (nullable instancetype)initWithModelPath:(NSString *)modelPath {
    self = [super init];
    if (!self) { return nil; }

    _model = NULL;
    _ctx   = NULL;

    // Initialize backend (safe to call multiple times)
    llama_backend_init();

    struct llama_model_params mparams = llama_model_default_params();
    // Use default GPU/offload settings provided by the library.
    // Just ensure progress callback is disabled for now.
    mparams.progress_callback = NULL;
    mparams.progress_callback_user_data = NULL;

    const char *path = [modelPath fileSystemRepresentation];
    _model = llama_model_load_from_file(path, mparams);
    if (_model == NULL) {
        NSLog(@"[LlamaBridge] Failed to load llama model from file: %s", path);
        return nil;
    }

    struct llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx     = 2048;      // context length
    cparams.n_threads = 2;         // conservative default for mobile

    _ctx = llama_init_from_model(_model, cparams);
    if (_ctx == NULL) {
        NSLog(@"[LlamaBridge] Failed to create llama context");
        llama_model_free(_model);
        _model = NULL;
        return nil;
    }

    return self;
}

- (NSString *)generateResponse:(NSString *)prompt
                     maxTokens:(int)maxTokens
                   temperature:(float)temperature
                          topP:(float)topP
                         error:(NSError * _Nullable * _Nullable)error {
    if (_ctx == NULL || _model == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"LLM context not initialized"}];
        }
        return @"";
    }

    const struct llama_model * model = _model;
    const struct llama_vocab * vocab = llama_model_get_vocab(model);

    // Start fresh for each generation
    llama_kv_self_clear(_ctx);

    // 1) Tokenize the prompt
    std::string promptStr([prompt UTF8String]);
    const int32_t maxPromptTokens = 1024;
    std::vector<llama_token> promptTokens(maxPromptTokens);

    int32_t nPrompt = llama_tokenize(
        vocab,
        promptStr.c_str(),
        (int32_t)promptStr.size(),
        promptTokens.data(),
        maxPromptTokens,
        /*add_special*/ true,
        /*parse_special*/ false);

    if (nPrompt < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:4
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Tokenization failed"}];
        }
        return @"";
    }

    promptTokens.resize(nPrompt);

    // 2) Feed the full prompt
    struct llama_batch batch = llama_batch_get_one(promptTokens.data(), nPrompt);
    int32_t res = llama_decode(_ctx, batch);
    if (res != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:5
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"llama_decode failed for prompt"}];
        }
        return @"";
    }

    // 3) Sampling-based generation loop using llama_sampler_chain
    const llama_token eosId = llama_vocab_eos(vocab);

    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    sparams.no_perf = true;

    struct llama_sampler * smpl = llama_sampler_chain_init(sparams);
    // More deterministic chain: top-k/top-p/temperature followed by greedy
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(20));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(topP, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(smpl, llama_sampler_init_greedy());

    std::vector<llama_token> outTokens;
    outTokens.reserve(maxTokens);

    for (int i = 0; i < maxTokens; ++i) {
        // sample from logits of last token (-1)
        llama_token tokenId = llama_sampler_sample(smpl, _ctx, -1);

        if (tokenId == eosId || tokenId == LLAMA_TOKEN_NULL) {
            break;
        }

        outTokens.push_back(tokenId);

        // accept token to update sampler state
        llama_sampler_accept(smpl, tokenId);

        // decode this new token
        struct llama_batch next = llama_batch_get_one(&tokenId, 1);
        int32_t resStep = llama_decode(_ctx, next);
        if (resStep != 0) {
            break;
        }
    }

    llama_sampler_free(smpl);

    if (outTokens.empty()) {
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:6
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"No tokens generated"}];
        }
        return @"";
    }

    // 4) Detokenize
    const int32_t bufSize = 4096;
    std::vector<char> buf(bufSize);
    int32_t nChars = llama_detokenize(
        vocab,
        outTokens.data(),
        (int32_t)outTokens.size(),
        buf.data(),
        bufSize,
        /*remove_special*/ true,
        /*unparse_special*/ false);

    if (nChars < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"LlamaBridge"
                                         code:7
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Detokenization failed"}];
        }
        return @"";
    }

    NSString *result = [[NSString alloc] initWithBytes:buf.data()
                                                length:(NSUInteger)nChars
                                              encoding:NSUTF8StringEncoding];
    if (!result) {
        result = @"";
    }
    return result;
}

- (void)unload {
    if (_ctx) {
        llama_free(_ctx);
        _ctx = NULL;
    }
    if (_model) {
        llama_model_free(_model);
        _model = NULL;
    }
}

- (void)dealloc {
    [self unload];
}

@end


