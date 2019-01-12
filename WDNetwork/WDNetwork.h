//
//  WDNetwork.h
//  Demo
//
//  Created by warden on 2019/1/12.
//  Copyright © 2019 warden. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WDNetworkDefine.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const WDNetworkReachabilityDidChangeNotification;
extern NSString * const WDNetworkReachabilityNotificationStatusKey;

/*! 判断是否有网 */
#ifndef kHasNetwork
#define kHasNetwork [WDNetwork isReachable]
#endif

/*! 判断是否为手机网络 */
#ifndef kIsViaWWAN
#define kIsViaWWAN [WDNetwork isReachableViaWWAN]
#endif

/*! 判断是否为WiFi网络 */
#ifndef kIsWiFi
#define kIsWiFi [WDNetwork isWiFiNetwork]
#endif

typedef void(^WDNetworkDidReceiveResponseBlock)(NSHTTPURLResponse *httpURLResponse);
typedef void(^WDNetworkProgressBlock)(NSProgress *progress);
typedef void(^WDNetworkResponseSuccessBlock)(id _Nullable responseObj);
typedef void(^WDNetworkResponseFailureBlock)(NSError * _Nonnull error);
typedef id(^WDNetworkProcessResponseObjectBlock)(NSURLRequest *request, id _Nullable responseObj);

@interface WDNetworkTask : NSObject



- (WDNetworkTask *(^)(NSString *))userAgent;
- (WDNetworkTask *(^)(NSTimeInterval))timeoutInterval;
- (WDNetworkTask *(^)(BOOL))shouldUseCookies;

- (WDNetworkTask *(^)(WDNetworkRequestSerializer))requestSerializer;    ///< 默认 HTTP
- (WDNetworkTask *(^)(WDNetworkResponseSerializer))responseSerializer;  ///< 默认 JSON

- (WDNetworkTask *(^)(NSDictionary *))headers;
- (WDNetworkTask *(^)(NSDictionary *))params;

//- (WDNetworkTask *(^)(WDNetworkProgressBlock))uploadProgress;
//- (WDNetworkTask *(^)(WDNetworkProgressBlock))downloadProgress;
- (WDNetworkTask *(^)(WDNetworkResponseSuccessBlock))success;
- (WDNetworkTask *(^)(WDNetworkResponseFailureBlock))failure;

- (WDNetworkTask *(^)(void))resume;
- (WDNetworkTask *(^)(void))cancel;

@end

@interface WDNetwork : NSObject

+ (instancetype)sharedNetwork;

@property (nonatomic, copy) NSString *userAgent;                ///< User-Agent
@property (nonatomic, assign) NSTimeInterval timeoutInterval;   ///< 超时时长，默认是30s
@property (nonatomic, assign) BOOL shouldUseCookies;            ///< 是否使用Cookies

@property (nonatomic, readonly) NSDictionary *headers;  ///< 默认请求头
- (WDNetwork *(^)(NSDictionary *))addHeaders;           ///< 添加默认请求头
- (WDNetwork *(^)(NSArray *))removeHeaders;             ///< 移除默认请求头

@property (nonatomic, readonly) NSDictionary *params;   ///< 默认请求参数
- (WDNetwork *(^)(NSDictionary *))addParams;            ///< 添加默认请求参数
- (WDNetwork *(^)(NSArray *))removeParams;              ///< 移除默认请求参数

- (WDNetwork *(^)(WDNetworkProcessResponseObjectBlock))processResponseObject;

- (WDNetworkTask * _Nullable (^)(NSString *))GET;
- (WDNetworkTask * _Nullable (^)(NSString *))POST;

/**
 监测网络
 */
+ (void)startNetworkMonitoring;

/*!
 *  是否有网
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachable;


/*!
 *  是否是 蜂窝 网络
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachableViaWWAN;

/*!
 *  是否是 WiFi 网络
 *
 *  @return YES, 反之:NO
 */
+ (BOOL)isReachableViaWiFi;

@end

NS_ASSUME_NONNULL_END
