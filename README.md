# WDNetwork
WDNetwork是在AFNetworking网络请求库上的简单封装，目前可以使用*GET*和*POST*请求，采用的是链式编程

## Install

* 源码
* 拖拽 `WDNetwork`文件夹到项目中
* Import文件：`#import "WDPageView.h"
* Cocoapods
* `pod 'WDNetwork'`
* Import文件：`#import <WDPageView.h>`

## How To Use

#### 设置全局统一的请求头，请求参数，超时时长等
````objective-c
WDNetwork.sharedNetwork
.addHeaders(@{@"":@""})
.addParams(@{@"":@""})
.processResponseObject((id)^(NSURLRequest *request, id responseObject) {
/**
* 处理响应数据，解密响应数据等
*/
return responseObject;
});
````

这里设置的所有属性都是对所有请求有效的，而`processResponseObjec`则可以统一修改所有请求返回的数据，可用于统一解密服务器返回的数据

#### 请求

* GET

````objective-c
WDNetwork.sharedNetwork
.GET(url)
.timeoutInterval(10.0)
.headers(@{@"":@""})
.params(@{@"":@""})
.success(^(id responseObj) {
/**
* code
*/ 
}).failure(^(NSError *error) {
/**
* code
*/ 
}).resume();
````

* POST

````objective-c
WDNetwork.sharedNetwork
.POST(url)
.timeoutInterval(10.0)
.headers(@{@"":@""})
.params(@{@"":@""})
.success(^(id responseObj) {
/**
* code
*/ 
}).failure(^(NSError *error) {
/**
* code
*/ 
}).resume();
````

*WDNetwork*的实例方法**GET**和**POST**都会返回新的**WDNetworkTask**对象，可对**WDNetworkTask**设置其请求头和请求参数

> 注意：对**WDNetworkTask**设置的属性会覆盖全局的



### END

这个网络请求框架刚开始封装，功能不完善，后续会继续完善
