//
//  WDNetworkDefine.h
//  Demo
//
//  Created by warden on 2019/1/12.
//  Copyright © 2019 warden. All rights reserved.
//

#ifndef WDNetworkDefine_h
#define WDNetworkDefine_h

/// 网络状态
typedef NS_ENUM(NSUInteger, WDNetworkStatus)
{
    /*! 未知网络 */
    WDNetworkStatusUnknown = 0,
    /*! 没有网络 */
    WDNetworkStatusNotReachable,
    /*! 手机 3G/4G 网络 */
    WDNetworkStatusReachableViaWWAN,
    /*! WiFi 网络 */
    WDNetworkStatusReachableViaWiFi
};

/// 请求体序列方式
typedef NS_ENUM(NSUInteger, WDNetworkRequestSerializer)
{
    /*! HTTP序列化 */
    WDNetworkRequestSerializerHTTP = 0,
    /*! JSON序列化 */
    WDNetworkRequestSerializerJSON,
};

/// 响应体体序列方式
typedef NS_ENUM(NSUInteger, WDNetworkResponseSerializer)
{
    /*! HTTP序列化 */
    WDNetworkResponseSerializerHTTP = 0,
    /*! JSON序列化 */
    WDNetworkResponseSerializerJSON,
};

#endif /* WDNetworkDefine_h */
