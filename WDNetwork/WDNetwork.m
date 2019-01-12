//
//  WDNetwork.m
//  Demo
//
//  Created by warden on 2019/1/12.
//  Copyright © 2019 warden. All rights reserved.
//

#import "WDNetwork.h"
#import <AFHTTPSessionManager.h>
#import "AFNetworkActivityIndicatorManager.h"
#import <objc/runtime.h>
#import <pthread.h>

#define HTTPTimeout 30

static inline void _wd_dispatch_async_on_main_queue(void (^block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

NSString * const WDNetworkReachabilityDidChangeNotification = @"com.warden.network.reachability.change";
NSString * const WDNetworkReachabilityNotificationStatusKey = @"WDNetworkReachabilityNotificationStatusKey";

@interface WDNetworkConfig : NSObject <NSCopying>

@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) BOOL shouldUseCookies;

@property (nonatomic, assign) WDNetworkRequestSerializer requestSerializer;
@property (nonatomic, assign) WDNetworkResponseSerializer responseSerializer;

@property (nonatomic, strong) NSMutableDictionary *headers;
@property (nonatomic, strong) NSMutableDictionary *params;

@end

@implementation WDNetworkConfig

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    WDNetworkConfig *config = [WDNetworkConfig new];
    unsigned int count;
    objc_property_t *propertys = class_copyPropertyList(WDNetworkConfig.class, &count);
    for (int i = 0; i < count; i++) {
        objc_property_t property = propertys[i];
        const char *keyChar = property_getName(property);
        NSString *key = [NSString stringWithUTF8String:keyChar];
        id value = [self valueForKey:key];
        if ([value conformsToProtocol:@protocol(NSMutableCopying)]) {
            [config setValue:[value mutableCopy] forKey:key];
        } else {
            if ([value conformsToProtocol:@protocol(NSCopying)]) {
                [config setValue:[value copy] forKey:key];
            } else {
                [config setValue:value forKey:key];
            }
        }
    }
    free(propertys);
    return config;
}

#pragma mark - Getter

- (NSMutableDictionary *)headers {
    if (!_headers) {
        _headers = [NSMutableDictionary dictionary];
    }
    return _headers;
}

- (NSMutableDictionary *)params {
    if (!_params) {
        _params = [NSMutableDictionary dictionary];
    }
    return _params;
}

@end

@class WDNetworkTask;

@protocol WDNetworkTaskDelegate <NSObject>

- (NSURLSessionDataTask *)dataTaskForTask:(WDNetworkTask *)task
                    requestuploadProgress:(WDNetworkProgressBlock) uploadProgressBlock
                         downloadProgress:(WDNetworkProgressBlock) downloadProgressBlock
                        completionHandler:(void (^)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler;

- (id)task:(WDNetworkTask *)task processResponseObject:(id)responseObject;

@end

@interface WDNetworkTask ()

@property (nonatomic, weak) id<WDNetworkTaskDelegate> delegate;

@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) WDNetworkConfig *config;

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

@property (nonatomic, copy) WDNetworkProgressBlock uploadProgressBlock;
@property (nonatomic, copy) WDNetworkProgressBlock downloadProgressBlock;
@property (nonatomic, copy) WDNetworkResponseSuccessBlock successBlock;
@property (nonatomic, copy) WDNetworkResponseFailureBlock failureBlock;

- (instancetype)initWithMethod:(NSString *)method url:(NSString *)url config:(WDNetworkConfig *)config;

@end

@implementation WDNetworkTask

- (instancetype)initWithMethod:(NSString *)method url:(NSString *)url config:(WDNetworkConfig *)config {
    if (self = [self init]) {
        self.method = method;
        self.url = url;
        self.config = config;
    }
    return self;
}

- (WDNetworkTask * _Nonnull (^)(NSString * _Nonnull))userAgent {
    return ^id(NSString *userAgent) {
        self.config.userAgent = userAgent;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(NSTimeInterval))timeoutInterval {
    return ^id(NSTimeInterval timeoutInterval) {
        self.config.timeoutInterval = timeoutInterval;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(BOOL))shouldUseCookies {
    return ^id(BOOL shouldUseCookies) {
        self.config.shouldUseCookies = shouldUseCookies;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(WDNetworkRequestSerializer))requestSerializer {
    return ^id(WDNetworkRequestSerializer requestSerializer) {
        self.config.requestSerializer = requestSerializer;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(WDNetworkResponseSerializer))responseSerializer {
    return ^id(WDNetworkResponseSerializer responseSerializer) {
        self.config.responseSerializer = responseSerializer;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(NSDictionary * _Nonnull))headers {
    return ^id(NSDictionary *headers) {
        if (headers.count > 0) {
            [self.config.headers addEntriesFromDictionary:headers];
        }
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(NSDictionary * _Nonnull))params {
    return ^id(NSDictionary *params) {
        if (params.count > 0) {
            [self.config.params addEntriesFromDictionary:params];
        }
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(WDNetworkResponseSuccessBlock _Nonnull))success {
    return ^id(WDNetworkResponseSuccessBlock success) {
        self.successBlock = success;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(WDNetworkResponseFailureBlock _Nonnull))failure {
    return ^id(WDNetworkResponseFailureBlock failure) {
        self.failureBlock = failure;
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(void))resume {
    return ^id(void) {
        [self _resume];
        return self;
    };
}

- (WDNetworkTask * _Nonnull (^)(void))cancel {
    return ^id(void) {
        [self _cancel];
        return self;
    };
}

#pragma mark - Private

- (void)_resume {
    AFHTTPRequestSerializer *requestSerializer;
    if (self.config.requestSerializer == WDNetworkRequestSerializerJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    } else {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    }
    
    NSError *error;
    NSMutableURLRequest *request = [requestSerializer requestWithMethod:self.method URLString:self.url parameters:nil error:&error];
    if (error) {
        
        return;
    }
    
    request.timeoutInterval = self.config.timeoutInterval;
    request.HTTPShouldHandleCookies = self.config.shouldUseCookies;
    
    for (NSString *key in self.config.headers.allKeys) {
        [request setValue:self.config.headers[key] forHTTPHeaderField:key];
    }
    
    if (self.config.userAgent) {
        [request setValue:self.config.userAgent forHTTPHeaderField:@"User-Agent"];
    }
    
    self.request = [requestSerializer requestBySerializingRequest:request withParameters:self.config.params error:&error];
    if (error) {
        
        return;
    }
    
    __weak typeof(self) weak_self = self;
    self.dataTask = [self.delegate dataTaskForTask:self requestuploadProgress:^(NSProgress * _Nonnull progress) {
        _wd_dispatch_async_on_main_queue(^{
            if (self.uploadProgressBlock) {
                self.uploadProgressBlock(progress);
            }
        });
    } downloadProgress:^(NSProgress * _Nonnull progress) {
        _wd_dispatch_async_on_main_queue(^{
            if (self.downloadProgressBlock) {
                self.downloadProgressBlock(progress);
            }
        });
    } completionHandler:^(NSURLResponse *response, id  _Nullable responseObject, NSError * _Nullable error) {
        __strong typeof(weak_self) self = weak_self;
        if (self == nil) {
            return ;
        }
        id responseObj = responseObject;
        if (error == nil) {
            if ([responseObj isKindOfClass:NSData.class]) {
                AFHTTPResponseSerializer *respSerializer;
                if (self.config.responseSerializer == WDNetworkResponseSerializerHTTP) {
                    respSerializer = [AFHTTPResponseSerializer serializer];
                } else {
                    respSerializer = [AFJSONResponseSerializer serializer];
                }
                responseObj = [respSerializer responseObjectForResponse:response data:responseObj error:&error];
            }
            if (error == nil) {
                if (self.delegate) {
                    responseObj = [self.delegate task:self processResponseObject:responseObj];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (self.failureBlock) {
                    self.failureBlock(error);
                }
            } else {
                if (self.successBlock) {
                    self.successBlock(responseObj);
                }
            }
        });
    }];
    [self.dataTask resume];
}

- (void)_cancel {
    [self.dataTask cancel];
}

@end

@interface WDNetwork () <WDNetworkTaskDelegate>

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WDNetworkTask *> *tasks;

@property (nonatomic, strong) WDNetworkConfig *config;
@property (nonatomic, strong) dispatch_queue_t completionQueue;
@property (nonatomic, copy) WDNetworkProcessResponseObjectBlock processBlock;

@end

@implementation WDNetwork

+ (instancetype)sharedNetwork {
    static WDNetwork *network;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        network = [[WDNetwork alloc] init];
    });
    return network;
}

- (instancetype)init {
    if (self = [super init]) {
        [self initDefaultConfig];
    }
    return self;
}

- (void)initDefaultConfig {
    self.timeoutInterval = HTTPTimeout;
    self.shouldUseCookies = YES;
    self.config.requestSerializer = WDNetworkRequestSerializerHTTP;
    self.config.responseSerializer = WDNetworkResponseSerializerJSON;
    
    self.completionQueue = dispatch_queue_create("com.warden.network.completion", DISPATCH_QUEUE_CONCURRENT);
    [self.sessionManager setCompletionQueue:self.completionQueue];
    
    __weak typeof(self) weak_self = self;
    [self.sessionManager setTaskDidCompleteBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSError * _Nullable error) {
        __strong typeof(weak_self) self = weak_self;
        if (self == nil) {
            return ;
        }
        NSString *taskId = @(task.taskIdentifier).stringValue;
        [self.tasks removeObjectForKey:taskId];
    }];
}

#pragma mark - Normal

- (WDNetwork * _Nonnull (^)(NSDictionary * _Nonnull))addHeaders {
    return ^id(NSDictionary *headers) {
        if (headers.count > 0) {
            [self.config.headers addEntriesFromDictionary:headers];
        }
        return self;
    };
}

- (WDNetwork * _Nonnull (^)(NSArray * _Nonnull))removeHeaders {
    return ^id(NSArray *headers) {
        for (NSString *key in headers) {
            if ([key isKindOfClass:NSString.class]) {
                [self.config.headers removeObjectForKey:key];
            }
        }
        return self;
    };
}

- (WDNetwork * _Nonnull (^)(NSDictionary * _Nonnull))addParams {
    return ^id(NSDictionary *params) {
        if (params.count > 0) {
            [self.config.params addEntriesFromDictionary:params];
        }
        return self;
    };
}

- (WDNetwork * _Nonnull (^)(NSArray * _Nonnull))removeParams {
    return ^id(NSArray *params) {
        for (NSString *key in params) {
            if ([key isKindOfClass:NSString.class]) {
                [self.config.params removeObjectForKey:key];
            }
        }
        return self;
    };
}

- (WDNetwork * _Nonnull (^)(WDNetworkProcessResponseObjectBlock _Nonnull))processResponseObject {
    return ^id(WDNetworkProcessResponseObjectBlock processBlock) {
        self.processBlock = processBlock;
        return self;
    };
}

#pragma mark - Task

- (WDNetworkTask * _Nullable (^)(NSString * _Nonnull))GET {
    return ^id(NSString *url) {
        return self.networkTask(@"GET", url);
    };
}

- (WDNetworkTask * _Nullable (^)(NSString * _Nonnull))POST {
    return ^id(NSString *url) {
        return self.networkTask(@"POST", url);
    };
}

- (WDNetworkTask * _Nullable (^)(NSString * _Nonnull, NSString * _Nonnull))networkTask {
    return ^id(NSString * method, NSString *url) {
        NSString *urlStr = url;
        if ([NSURL URLWithString:urlStr] == nil) {
            urlStr = [self encodeWithUTF8:urlStr];
            if ([NSURL URLWithString:urlStr] == nil) {
                return nil;
            }
        }
        WDNetworkTask *task = [[WDNetworkTask alloc] initWithMethod:method url:url config:self.config];
        task.delegate = self;
        return task;
    };
}

#pragma mark - URL 中文编码

- (NSString *)encodeWithUTF8:(NSString *)str {
    return [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
}

#pragma mark - WDNetworkTaskDelegate

- (NSURLSessionDataTask *)dataTaskForTask:(WDNetworkTask *)task
                    requestuploadProgress:(WDNetworkProgressBlock)uploadProgressBlock
                         downloadProgress:(WDNetworkProgressBlock)downloadProgressBlock
                        completionHandler:(void (^)(NSURLResponse *, id _Nullable, NSError * _Nullable))completionHandler {
    NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:task.request uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    NSString *taskId = @(dataTask.taskIdentifier).stringValue;
    @synchronized (self.tasks) {
        [self.tasks setValue:task forKey:taskId];
    }
    return dataTask;
}

- (id)task:(WDNetworkTask *)task processResponseObject:(id)responseObject {
    if (self.processBlock) {
        return self.processBlock(task.request.copy, responseObject);
    }
    return responseObject;
}

#pragma mark - Setter

- (void)setUserAgent:(NSString *)userAgent {
    _userAgent = userAgent;
    self.config.userAgent = userAgent;
}

- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval {
    _timeoutInterval = timeoutInterval;
    self.config.timeoutInterval = timeoutInterval;
}

- (void)setShouldUseCookies:(BOOL)shouldUseCookies {
    _shouldUseCookies = shouldUseCookies;
    self.config.shouldUseCookies = shouldUseCookies;
}

#pragma mark - Getter

- (NSDictionary *)headers {
    return self.config.headers.copy;
}

- (NSDictionary *)params {
    return self.config.params.copy;
}

- (AFHTTPSessionManager *)sessionManager {
    if (!_sessionManager) {
        _sessionManager = [AFHTTPSessionManager manager];
        
        _sessionManager = [AFHTTPSessionManager manager];
        
        /*!
         设置请求服务器类型为 http
         json: [AFJSONRequestSerializer serializer](常用)
         http: [AFHTTPRequestSerializer serializer](加密的使用这个)
         */
        [AFHTTPRequestSerializer serializer].timeoutInterval = self.timeoutInterval;
        [AFHTTPRequestSerializer serializer].cachePolicy = NSURLRequestReloadIgnoringCacheData;
        [AFJSONRequestSerializer serializer].timeoutInterval = self.timeoutInterval;
        [AFJSONRequestSerializer serializer].cachePolicy = NSURLRequestReloadIgnoringCacheData;
        
        /*!
         设置服务器返回类型为 json
         json: [AFJSONResponseSerializer serializer](常用)
         http: [AFHTTPResponseSerializer serializer](加密的使用这个)
         */
        [AFHTTPResponseSerializer serializer].acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", @"application/javascript", nil];
        [AFJSONResponseSerializer serializer].acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain", @"application/javascript", nil];
        
        /*!
         HTTPS参数请求设置
         */
        _sessionManager.securityPolicy.allowInvalidCertificates = YES;
        _sessionManager.securityPolicy.validatesDomainName = NO;
    }
    return _sessionManager;
}

- (NSMutableDictionary<NSString *,WDNetworkTask *> *)tasks {
    if (!_tasks) {
        _tasks = [NSMutableDictionary dictionary];
    }
    return _tasks;
}

- (WDNetworkConfig *)config {
    if (!_config) {
        _config = [[WDNetworkConfig alloc] init];
    }
    return _config;
}

#pragma mark - 网络监听

+ (void)startNetworkMonitoring {
    /*! 1.获得网络监控的管理者 */
    AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
    /*! 当使用AF发送网络请求时,只要有网络操作,那么在状态栏(电池条)wifi符号旁边显示  菊花提示 */
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    /*! 2.设置网络状态改变后的处理 */
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        /*! 当网络状态改变了, 就会调用这个block */
        WDNetworkStatus wdStatus;
        switch (status)
        {
            case AFNetworkReachabilityStatusUnknown:
                NSLog(@"网络未知");
                wdStatus = WDNetworkStatusUnknown;
                break;
            case AFNetworkReachabilityStatusNotReachable:
                NSLog(@"网络不可达");
                wdStatus = WDNetworkStatusNotReachable;
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                NSLog(@"蜂窝 网络");
                wdStatus = WDNetworkStatusReachableViaWWAN;
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                NSLog(@"WiFi 网络");
                wdStatus = WDNetworkStatusReachableViaWiFi;
                break;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:WDNetworkReachabilityDidChangeNotification object:nil userInfo:@{WDNetworkReachabilityNotificationStatusKey:@(wdStatus)}];
        });
    }];
    
    [manager startMonitoring];
}

/*!
 *  是否有网
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachable
{
    return [AFNetworkReachabilityManager sharedManager].isReachable;
}

/*!
 *  是否是手机网络
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachableViaWWAN
{
    return [AFNetworkReachabilityManager sharedManager].isReachableViaWWAN;
}

/*!
 *  是否是 WiFi 网络
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachableViaWiFi
{
    return [AFNetworkReachabilityManager sharedManager].isReachableViaWiFi;
}

@end
