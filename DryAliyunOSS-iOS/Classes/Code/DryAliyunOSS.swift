//
//  DryAliyunOSS.swift
//  DryAliyunOSS
//
//  Created by Ruiying Duan on 2019/5/2.
//

import UIKit
import AliyunOSSiOS

//MARK: - 图片类型
public enum DryAliyunImageMode {
    /// PNG图片
    case png
    /// JPEG图片
    case jpeg
}

//MARK: - 错误类型
public enum DryAliyunErrCode {
    /// 客户端未初始化
    case clientErr
    /// 参数异常
    case paramsErr
    /// 图片转换异常
    case imageConvertErr
    /// 图片上传失败
    case imagePutErr
    /// 图片下载失败
    case imageGetErr
}

//MARK: - DryAliyunOSSDelegate
public protocol DryAliyunOSSDelegate: class {
    
    /// @说明 从服务端动态获取阿里云OSSToken相关数据
    /// @参数 resp:   后台提供的OSSFederationToken参数(tAccessKey、tSecretKey、tToken、expirationTimeInGMTFormat)
    /// @返回 void
    func aliyunOSSToken(_ resp: @escaping (_ tAccessKey: String?, _ tSecretKey: String?, _ tToken: String?, _ expirationTimeInGMTFormat: String?) -> Void)
}

//MARK: - DryAliyunOSS
public class DryAliyunOSS: NSObject {

    /// OSS客户端(多个endpoint需要对应多个client，client必须和app生命周期一致，不能是局部变量)
    var client: OSSClient?
    /// 代理
    weak var delegate: DryAliyunOSSDelegate?
    
    /// 单例
    private static let instance: DryAliyunOSS = DryAliyunOSS()
    @discardableResult
    static func shared() -> DryAliyunOSS {
        return instance
    }
    
    /// 构造
    private override init() {}
    
    /// 析构
    deinit {
        
        self.client = nil
        self.delegate = nil
    }
}

//MARK: - 初始化
extension DryAliyunOSS {
    
    /// @说明 初始化客户端
    /// @参数 endPoint:   需要使用https://前缀的URL
    /// @参数 delegate:   代理
    /// @参数 config:     配置
    /// @返回 void
    public static func initClient(withEndPoint endPoint: String,
                                  delegate: DryAliyunOSSDelegate,
                                  config: OSSClientConfiguration? = nil) {
        
        /// 设置代理
        DryAliyunOSS.shared().delegate = delegate
        
        /// 阿里云代理验证，使用上传、下载API时，回调此处验证阿里云federationToken是否过期
        let credential: OSSFederationCredentialProvider = OSSFederationCredentialProvider(federationTokenGetter: {() -> OSSFederationToken? in
            
            /// 初始化阻塞
            let tcs = OSSTaskCompletionSource<AnyObject>.init()
            
            /// 初始化OSSFederationToken
            let stcToken = OSSFederationToken()
            
            /// 获取OSSFederationToken参数
            DryAliyunOSS.shared().delegate?.aliyunOSSToken({ (tAccessKey, tSecretKey, tToken, GMTFormat) in
                
                /// OSSFederationToken
                if tAccessKey != nil && tSecretKey != nil && tToken != nil && GMTFormat != nil {
                    stcToken.tAccessKey = tAccessKey!
                    stcToken.tSecretKey = tSecretKey!
                    stcToken.tToken = tToken!
                    stcToken.expirationTimeInGMTFormat = GMTFormat!
                }
                
                /// 移除阻塞
                tcs.setResult(nil)
            })
            
            /// 等待任务结束
            tcs.task.waitUntilFinished()
            
            /// 返回stcToken
            return stcToken
        })
        
        /// 配置
        let tmpConfig: OSSClientConfiguration?
        if config != nil {
            tmpConfig = config
        }else {
            tmpConfig = OSSClientConfiguration()
            tmpConfig!.maxRetryCount = 3
            tmpConfig!.timeoutIntervalForRequest = 60
            tmpConfig!.timeoutIntervalForResource = TimeInterval(24 * 60 * 60)
            tmpConfig!.maxConcurrentRequestCount = 60
        }

        /// 创建客户端
        DryAliyunOSS.shared().client = OSSClient.init(endpoint: endPoint, credentialProvider: credential, clientConfiguration: tmpConfig!)
    }
}

//MARK: - 图片上传
extension DryAliyunOSS {
    
    /// @说明 图片上传
    /// @参数 bucket:             阿里云bucket
    /// @参数 imageMode:          图片类型
    /// @参数 image:              图片数据
    /// @参数 objectKey:          图片唯一标识
    /// @参数 taskQueue:          执行队列(并发队列 Concurrent Dispatch Queue)
    /// @参数 completionQueue:    回调队列(串行队列 Serial Dispatch Queue)
    /// @参数 respProgress:       进度回调(当前上传速度，已经上传总长度，一共需要上传的总长度)(单位: Byte)
    /// @参数 respError:          失败回调(DryAliyunErrCode)
    /// @参数 respSuccess:        成功回调(objectKey)
    /// @返回 void
    public static func uploadImage(withBucket bucket: String,
                                   imageMode: DryAliyunImageMode,
                                   image: UIImage,
                                   objectKey: String,
                                   taskQueue: DispatchQueue? = nil,
                                   completionQueue: DispatchQueue? = nil,
                                   respProgress: @escaping (Int64, Int64, Int64) -> Void,
                                   respError: @escaping (DryAliyunErrCode) -> Void,
                                   respSuccess: @escaping (String) -> Void) {
        
        /// 检查(客户端)
        if DryAliyunOSS.shared().client == nil {
            respError(.clientErr)
            return
        }
        
        /// 配置contentType，参考: https://docs.aliyun.com/#/pub/oss/api-reference/object&PutObject
        var imageData: Data? = nil
        var contentType: String? = nil
        switch imageMode {
        case .png:
            imageData = image.pngData()
            contentType = "image/png"
        case .jpeg:
            imageData = image.jpegData(compressionQuality: 0)
            contentType = "image/jpeg"
        }
        
        if imageData == nil || contentType == nil {
            respError(.imageConvertErr)
            return
        }
        
        /// Put Request
        let request: OSSPutObjectRequest = OSSPutObjectRequest()
        request.uploadingData = imageData!
        request.bucketName = bucket
        request.objectKey = objectKey
        request.contentType = contentType!
        request.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
            /// 进度回调
            respProgress(bytesSent, totalBytesSent, totalBytesExpectedToSend)
        }
        
        /// 执行任务的队列(并发队列)
        var localTaskQueue: DispatchQueue = DispatchQueue.global()
        if taskQueue != nil {
            localTaskQueue = taskQueue!
        }
        
        /// 任务完成后回调队列(串行队列)
        var localCompletionQueue: DispatchQueue = DispatchQueue.main
        if completionQueue != nil {
            localCompletionQueue = completionQueue!
        }
        
        /// 上传(并发队列异步执行)
        localTaskQueue.async {
            
            let put: OSSTask = DryAliyunOSS.shared().client!.putObject(request)
            put.continue({ (aTask: OSSTask) -> Any? in
                
                /// 成功回调objectKey(串行队列异步执行)
                if aTask.error == nil {
                    localCompletionQueue.sync {
                        respSuccess(objectKey)
                    }
                    return nil
                }
                
                /// 失败回调错误码(串行队列异步执行)
                localCompletionQueue.async {
                    respError(.imagePutErr)
                }
                return nil
            })
            put.waitUntilFinished()
        }
    }
}

//MARK: - 图片下载
extension DryAliyunOSS {
    
    /// @说明 图片下载
    /// @参数 bucket:             阿里云bucket
    /// @参数 objectKey:          图片的objectKey
    /// @参数 isCustomSize:       是否自定义图片宽高
    /// @参数 imageWidth:         图片宽度(可选参数)
    /// @参数 imageHeight:        图片高度(可选参数)
    /// @参数 taskQueue:          执行队列(并发队列 Concurrent Dispatch Queue)
    /// @参数 completionQueue:    回调队列(串行队列 Serial Dispatch Queue)
    /// @参数 respProgress:       进度回调(当前上传速度，已经上传总长度，一共需要上传的总长度)(单位: Byte)
    /// @参数 respError:          失败回调(DryAliyunErrCode)
    /// @参数 respSuccess:        成功回调(UIImage)
    /// @返回 void
    public static func downloadImage(withBucket bucket: String,
                                     objectKey: String,
                                     isCustomSize: Bool,
                                     imageWidth: String? = nil,
                                     imageHeight: String? = nil,
                                     taskQueue: DispatchQueue? = nil,
                                     completionQueue: DispatchQueue? = nil,
                                     respProgress: @escaping (Int64, Int64, Int64) -> Void,
                                     respError: @escaping (DryAliyunErrCode) -> Void,
                                     respSuccess: @escaping (UIImage) -> Void) {
        
        /// 检查(客户端)
        if DryAliyunOSS.shared().client == nil {
            respError(.clientErr)
            return
        }
        
        /// Get Request
        let request: OSSGetObjectRequest = OSSGetObjectRequest()
        request.bucketName = bucket
        request.objectKey = objectKey
        request.downloadProgress = { (bytesWritten: Int64,totalBytesWritten : Int64, totalBytesExpectedToWrite: Int64) -> Void in
            /// 进度回调
            respProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        }
        
        /// 是否自定义图片大小
        if isCustomSize && imageWidth != nil && imageHeight != nil {
            request.xOssProcess = "image/resize,m_lfit,w_\(imageWidth!),h_\(imageHeight!)"
        }
        
        /// 执行任务的队列(并发队列)
        var localTaskQueue: DispatchQueue = DispatchQueue.global()
        if taskQueue != nil {
            localTaskQueue = taskQueue!
        }
        
        /// 任务完成后回调队列(串行队列)
        var localCompletionQueue: DispatchQueue = DispatchQueue.main
        if completionQueue != nil {
            localCompletionQueue = completionQueue!
        }
        
        /// 下载(并发队列异步执行)
        localTaskQueue.async {
            
            let get: OSSTask = DryAliyunOSS.shared().client!.getObject(request)
            get.continue( { (aTask: OSSTask) -> Any? in
                
                /// 数据解析
                if aTask.error == nil && aTask.result != nil && aTask.result as? OSSGetObjectResult != nil {
                    
                    let result = aTask.result as! OSSGetObjectResult
                    let downloadedData: Data = result.downloadedData
                    if let image = UIImage.init(data: downloadedData) {
                        
                        /// 成功回调objectKey(串行队列异步执行)
                        localCompletionQueue.sync {
                            respSuccess(image)
                        }
                        return nil
                    }
                }
                
                /// 失败回调错误码(串行队列异步执行)
                localCompletionQueue.sync {
                    respError(.imageGetErr)
                }
                return nil
            })
            get.waitUntilFinished()
        }
    }
}
