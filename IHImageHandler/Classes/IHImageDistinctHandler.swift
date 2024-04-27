

import Foundation
import CryptoKit
import UIKit

open class IHImageDistinctHandler: NSObject {
    lazy var imageQueue = DispatchQueue(label: "com.handleImageEncryptor", target: .global())
    
    lazy var currentContext = CIContext()
    
    public func handleEncrypt(_ imageData: Data,
                         using keyStr: String,
                         completion: @escaping ImageFuzzyHandler) {
           imageQueue.async { [weak self] in
               
               guard !keyStr.isEmpty else {
                   return completion(.failure(IHFuzzyError.invalidString))
               }
               
               guard let imageData = CIImage(data: imageData) else {
                   return completion(.failure(IHFuzzyError.invalidSourceData))
               }
               self?.handleEncrypt(imageData, using: keyStr, completion: completion)
           }
       }

func handleEncrypt(_ imageData: CIImage,
                         using keyString: String,
                         completion: @escaping ImageFuzzyHandler) {
        
        if imageData.extent.width < 10 || imageData.extent.height < 1 {
            return completion(.failure(IHFuzzyError.invalidSourceData))
        }
        
        let spaceWidth = CVPixelBuffer.getSpaceWidth24RGB(for: Int(imageData.extent.width)) / 3
        guard let imagePixelBuffer = CVPixelBuffer.makeExtension32BGRA(from: imageData,
                                                                            ciContext: currentContext,
                                                                            heightExtended: 1,
                                                                            widthExtended: spaceWidth),
              let imagePixelBuffer = imagePixelBuffer.handelToRGB() else {
            return completion(.failure(IHFuzzyError.fuzzyError))
        }
        
        guard var imagePixelData = imagePixelBuffer.imagePixelData else {
            return completion(.failure(IHFuzzyError.fuzzyError))
        }
        
        imagePixelData.removeLast(CVPixelBufferGetWidth(imagePixelBuffer) * 3)
        
        do {
            let key = SymmetricKey(dataSource: keyString)
            let sealedBox = try AES.GCM.seal(imagePixelData, using: key)
            let spaceWidthData = Data([UInt8(spaceWidth)])
            imagePixelBuffer.imageCopy(from: sealedBox.ciphertext + sealedBox.nonce + sealedBox.tag + spaceWidthData)

            let encryptedCIImage = CIImage(cvPixelBuffer: imagePixelBuffer)
            completion(.success(IHFuzzyedImage(ciImageData: encryptedCIImage)))
        } catch {
            completion(.failure(IHFuzzyError.fuzzyError))
        }
    }
    
      func handleDataEncrypt(_ ciImage: CIImage,
                        using keyString: String,
                        completion: @escaping ImageFuzzyHandler) {
          imageQueue.async { [weak self] in
              guard !keyString.isEmpty else {
                  return completion(.failure(IHFuzzyError.invalidString))
              }
              
              self?.handleEncrypt(ciImage, using: keyString, completion: completion)
          }
      }


    
    func handleEncrypt(_ uiImage: UIImage,
                      using keyStr: String,
                      completion: @escaping ImageFuzzyHandler) {
        imageQueue.async { [weak self] in
            guard !keyStr.isEmpty else {
                return completion(.failure(IHFuzzyError.invalidString))
            }
            
            guard let dataImage = uiImage.cgImage else {
                return completion(.failure(IHFuzzyError.invalidSourceData))
            }
            let imageData = CIImage(cgImage: dataImage)
            self?.handleEncrypt(imageData, using: keyStr, completion: completion)
        }
    }
    

}
