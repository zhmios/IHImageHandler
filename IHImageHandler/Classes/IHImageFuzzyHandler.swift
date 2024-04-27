import UIKit
import Foundation
import CryptoKit

open class IHImageFuzzyHandler: NSObject {
    lazy var currentContext = CIContext()
    lazy var dataQueue = DispatchQueue(label: "com.handleImageEncryptor", target: .global())

func handleDecrypt(_ imageData: CIImage,
                         using key: String,
                         completion: @escaping ImageFuzzyHandler) {
        if imageData.extent.width < 10 || imageData.extent.height < 2 {
            return completion(.failure(IHFuzzyError.invalidSourceData))
        }
        
        guard let iamgePixelBuffer = CVPixelBuffer.make32BGRAData(from: imageData,
                                                               ciContext: currentContext),
              let rgbPixelBuffer = iamgePixelBuffer.handelToRGB() else {
            return completion(.failure(IHFuzzyError.fuzzyError))
        }
        
        guard var imageEveryPixelData = rgbPixelBuffer.imagePixelData else {
            return completion(.failure(IHFuzzyError.fuzzyError))
        }
        
        let (nonce, tag, widthPadding) = handleTagAndNonce(from: &imageEveryPixelData,
                           width: rgbPixelBuffer.pixelWidth,
                           height: rgbPixelBuffer.pixelHeight)
        
        guard let nonce = nonce,
              let sealedBox = try? AES.GCM.SealedBox(nonce: nonce,
                                                     ciphertext: imageEveryPixelData,
                                                     tag: tag) else {
            return completion(.failure(IHFuzzyError.invalidSourceData))
        }
        
        let imageKey = SymmetricKey(dataSource: key)
        guard let decryptedData = try? AES.GCM.open(sealedBox, using: imageKey) else {
            return completion(.failure(IHFuzzyError.invalidString))
        }
        
        rgbPixelBuffer.imageCopy(from: decryptedData)
        
        let decryptedImage = CIImage(cvPixelBuffer: rgbPixelBuffer)
        let rect = CGRect(x: 0, y: 0,
                          width: decryptedImage.extent.width - CGFloat(widthPadding),
                          height: decryptedImage.extent.height - 1)
        let dataImage = decryptedImage.cropped(to: rect)
        
        completion(.success(IHFuzzyedImage(ciImageData: dataImage)))
    }
    
    public func handleDecrypt(_ imageData: Data,
                         using keyString: String,
                         completion: @escaping ImageFuzzyHandler) {
         dataQueue.async { [weak self] in
             guard !keyString.isEmpty else {
                 return completion(.failure(IHFuzzyError.invalidString))
             }
             
             guard let imageData = CIImage(data: imageData) else {
                 return completion(.failure(IHFuzzyError.invalidSourceData))
             }
             
             self?.handleDecrypt(imageData, using: keyString, completion: completion)
         }
     }
     
    
func handleTagAndNonce(from data: inout Data, width: Int, height: Int) -> (nonce: AES.GCM.Nonce?, tag: Data, widthPadding: Int) {
        let lastIndex = 3 * width * (height - 1)
        let tagDataRange = lastIndex+12...lastIndex+27
        let tag = data[tagDataRange]
        let widthPadding = Int(data[lastIndex+28])
        let nonceRange = lastIndex...lastIndex+11
        let nonceData = try? AES.GCM.Nonce(data: data[nonceRange])
        data.removeLast(3 * width)
        
        return (nonceData, tag, widthPadding)
    }



    func handleDataDecrypt(_ ciImage: CIImage,
                        using keyString: String,
                        completion: @escaping ImageFuzzyHandler) {
        dataQueue.async { [weak self] in
            guard !keyString.isEmpty else {
                return completion(.failure(IHFuzzyError.invalidString))
            }
            
            self?.handleDecrypt(ciImage, using: keyString, completion: completion)
        }
    }

    func handleImageDecrypt(_ uiImage: UIImage,
                      using keyString: String,
                      completion: @escaping ImageFuzzyHandler) {
        dataQueue.async { [weak self] in
            guard !keyString.isEmpty else {
                return completion(.failure(IHFuzzyError.invalidString))
            }
            
            guard let cgImage = uiImage.cgImage else {
                return completion(.failure(IHFuzzyError.invalidSourceData))
            }
            let ciImage = CIImage(cgImage: cgImage)
            
            self?.handleDecrypt(ciImage, using: keyString, completion: completion)
        }
    }
    

 
}
