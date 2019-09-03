# DryAliyunOSS-iOS
iOS: 简化阿里云OSS 

## 官网:
* [阿里云](https://help.aliyun.com/document_detail/32055.html?spm=a2c4g.11174283.6.1062.45eb7da2khQHqQ)
* [Github](https://github.com/aliyun/aliyun-oss-ios-sdk/blob/master/README-CN.md)

## Prerequisites
* iOS 10.0+
* Swift 5.0+


## Installation
* pod 'DryAliyunOSS-iOS'

## Featuress
### 初始化客户端
```
DryAliyunOSS.initClient(withEndPoint: "", delegate: delegate, config: nil)
```

### 从服务端动态获取阿里云OSSToken相关数据
```
实现DryAliyunOSSDelegate代理方法:
public func aliyunOSSToken(_ resp: @escaping (_ tAccessKey: String?, _ tSecretKey: String?, _ tToken: String?, _ expirationTimeInGMTFormat: String?) -> Void) {

}
```

### 图片上传
1. 单图上传
```
DryAliyunOSS.uploadImage(withBucket: "", imageMode: .png, image: image, objectKey: "", respProgress: { (objectKey, bytesSent, totalBytesSent, totalBytesExpectedToSend) in

}, respError: { (errorCode) in

}) { (objectKey) in

}
```
2. 多图片上传示例:
```
/// GCD Group
let group: DispatchGroup = DispatchGroup()

/// 回调队列(串行队列)
let completionQueue: DispatchQueue = DispatchQueue.main

/// 任务队列(并发队列)
let taskQueue: DispatchQueue = DispatchQueue.global()

/// 成功标记
var isSuccess: Bool = true

/// 启动队列任务
group.enter()

----------->此处代码多次执行<-----------
DryAliyunOSS.uploadImage(withBucket: "", imageMode: .png, image: image, objectKey: "", taskQueue: taskQueue, completionQueue: completionQueue, respProgress: { (objectKey, bytesSent, totalBytesSent, totalBytesExpectedToSend) in

}, respError: { (errorCode) in
    isSuccess = false
    group.leave()
}) { (objectKey) in
    group.leave()
}
----------->此处代码多次执行<-----------

/// 队列组任务结束
group.notify(queue: completionQueue) {

    if isSuccess {

    }else {

    }
}
```

### 图片下载
1. 单图下载
```
DryAliyunOSS.downloadImage(withBucket: "", objectKey: "", isCustomSize: false, imageWidth: nil, imageHeight: nil, respProgress: { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in

}, respError: { (errorCode) in

}) { (image) in

}
```
2. 多图下载传示例
```
/// GCD Group
let group: DispatchGroup = DispatchGroup()

/// 回调队列(串行队列)
let completionQueue: DispatchQueue = DispatchQueue.main

/// 任务队列(并发队列)
let taskQueue: DispatchQueue = DispatchQueue.global()

/// 成功标志
var isSuccess: Bool = true

/// 启动队列任务
group.enter()

----------->此处代码多次执行<-----------
DryAliyunOSS.downloadImage(withBucket: "", objectKey: "", isCustomSize: false, imageWidth: nil, imageHeight: nil, taskQueue: taskQueue, completionQueue: completionQueue, respProgress: { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in

}, respError: { (errorCode) in
    isSuccess = false
    group.leave()
}) { (image) in
    group.leave()
}
----------->此处代码多次执行<-----------

/// 队列任务结束
group.notify(queue: completionQueue) {

    if isSuccess {
    
    }else {
    
    }
}
```
