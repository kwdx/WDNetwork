//
//  ViewController.m
//  Demo
//
//  Created by warden on 2019/1/12.
//  Copyright © 2019 warden. All rights reserved.
//

#import "ViewController.h"
#import "WDNetwork.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    WDNetwork.sharedNetwork
    .addHeaders(@{@"os":@"iOS"})
    .addParams(@{@"id":@"1"})
    .processResponseObject((id)^(NSURLRequest *request, id responseObject) {
        if ([responseObject isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *muDict = [NSMutableDictionary dictionaryWithDictionary:responseObject];
            [muDict setObject:request.URL forKey:@"URL"];
            return (id)muDict;
        }
        return responseObject;
    }).processRequestObject((id)^(NSString *url, id params) {
        NSMutableDictionary *muParams = [NSMutableDictionary dictionaryWithDictionary:params];
        if ([muParams.allKeys containsObject:@"name"]) {
            muParams[@"name"] = [muParams[@"name"] stringByAppendingString:@"----"];
        }
        return muParams;
    });
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    WDNetwork.sharedNetwork.GET(@"http://httpbin.org/get").timeoutInterval(10.0).headers(@{@"MethodType":@"GET"}).params(@{@"name":@"warden"}).success(^(id responseObj) {
        NSLog(@"-------------- GET --------------");
        NSLog(@"%@", responseObj);
        NSLog(@"-------------- END --------------");
    }).failure(^(NSError *error) {
        NSLog(@"-------------- GET --------------");
        NSLog(@"%@", error);
        NSLog(@"-------------- END --------------");
    }).resume();
    
    WDNetwork.sharedNetwork.POST(@"http://httpbin.org/post").headers(@{@"MethodType":@"POST"}).params(@{@"name":@"warden"}).success(^(id responseObj) {
        NSLog(@"-------------- POST --------------");
        NSLog(@"%@", responseObj);
        NSLog(@"-------------- END --------------");
    }).failure(^(NSError *error) {
        NSLog(@"-------------- POST --------------");
        NSLog(@"%@", error);
        NSLog(@"-------------- END --------------");
    }).resume();
}

@end
