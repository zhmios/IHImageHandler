
import Foundation
import Accelerate
import CoreImage

extension CVPixelBuffer {
    
   
    var pixelHeight: Int {
        CVPixelBufferGetHeight(self)
    }
    
    var pixelWidth: Int {
        CVPixelBufferGetWidth(self)
    }
    func pixelUnlockAction(_ flags: CVPixelBufferLockFlags) {
        CVPixelBufferUnlockBaseAddress(self, flags)
    }
    
    func pixeLock(_ flags: CVPixelBufferLockFlags) {
        CVPixelBufferLockBaseAddress(self, flags)
    }
    var byteRowData: Int {
        CVPixelBufferGetBytesPerRow(self)
    }
  
    
    var baseMemoryData: UnsafeMutableRawPointer? {
        CVPixelBufferGetBaseAddress(self)
    }
    
    var byteEveryPixelData: Int {
        byteRowData / pixelWidth
    }
    
    var imagePixelData: Data? {
        pixeLock(.readOnly)
        defer {
            pixelUnlockAction(.readOnly)
        }
        guard let baseAddress = baseMemoryData else {
            return nil
        }
                
        if byteRowData == pixelWidth * byteEveryPixelData {
            return Data(bytesNoCopy: baseAddress,
                        count: byteRowData * pixelHeight,
                        deallocator: .none)
        }
        
        var data = Data(capacity: pixelWidth * byteEveryPixelData * pixelHeight)
        for row in 0..<pixelHeight {
            let rowData = Data(bytesNoCopy: baseAddress.advanced(by: row * byteRowData),
                               count: pixelWidth * byteEveryPixelData,
                               deallocator: .none)
            data.append(rowData)
        }
        
        return data
    }
    
    static func makeExtension32BGRA(from ciImage: CIImage,
                                    ciContext: CIContext = CIContext(),
                                    heightExtended: Int,
                                    widthExtended: Int = 0) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(ciImage.extent.width) + widthExtended,
                            Int(ciImage.extent.height) + heightExtended,
                            kCVPixelFormatType_32BGRA,
                            nil,
                            &pixelBuffer)
        
        if let pixelBuffer = pixelBuffer {
            ciContext.render(ciImage, to: pixelBuffer)
        }
        
        return pixelBuffer
    }
    
    
    static func make32BGRAData(from ciImage: CIImage, ciContext: CIContext = CIContext()) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(ciImage.extent.width),
                            Int(ciImage.extent.height),
                            kCVPixelFormatType_32BGRA,
                            nil,
                            &pixelBuffer)
        
        if let pixelBuffer = pixelBuffer {
            ciContext.render(ciImage, to: pixelBuffer)
        }
        
        return pixelBuffer
    }
    static func getSpaceWidth24RGB(for width: Int) -> Int {
        var pixelBuffer: CVPixelBuffer!
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            1,
                            kCVPixelFormatType_24RGB,
                            nil,
                            &pixelBuffer)
        pixelBuffer.pixeLock(.readOnly)
        defer { pixelBuffer.pixelUnlockAction(.readOnly) }
        
        return pixelBuffer.byteRowData - 3 * pixelBuffer.pixelWidth
    }
   
    func handelToRGB() -> CVPixelBuffer? {
      
        var fromBufferData = vImage_Buffer()
        let inputCVFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(self).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(inputCVFormat,
                                          CGColorSpaceCreateDeviceRGB())
        var dataFormater = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue | CGImageByteOrderInfo.order32Little.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent)

        var error = vImageBuffer_InitWithCVPixelBuffer(&fromBufferData,
                                                   &dataFormater,
                                                   self,
                                                   inputCVFormat,
                                                   nil,
                                                   vImage_Flags(kvImageNoFlags))
    
        guard error == kvImageNoError else {
            return nil
        }
        
        defer {
            free(fromBufferData.data)
        }

        var destinationBuffer = vImage_Buffer()

        error = vImageBuffer_Init(&destinationBuffer,
                                  fromBufferData.height,
                                  fromBufferData.width,
                                  24,
                                  vImage_Flags(kvImageNoFlags))

        guard error == kvImageNoError else {
            return nil
        }
        
        defer {
            free(destinationBuffer.data)
        }
        
        vImageConvert_BGRA8888toRGB888(&fromBufferData,
                                       &destinationBuffer,
                                       vImage_Flags(kvImageNoFlags))
        
        var outputPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            CVPixelBufferGetWidth(self),
                            CVPixelBufferGetHeight(self),
                            kCVPixelFormatType_24RGB,
                            nil,
                            &outputPixelBuffer)
        guard let outputPixelBuffer = outputPixelBuffer else {
            return nil
        }
        
       
        let outputCVImageFormater = vImageCVImageFormat_CreateWithCVPixelBuffer(outputPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(outputCVImageFormater,
                                          CGColorSpaceCreateDeviceRGB())
        var outputFormater = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent)
        
        error = vImageBuffer_CopyToCVPixelBuffer(&destinationBuffer,
                                                 &outputFormater,
                                                 outputPixelBuffer,
                                                 outputCVImageFormater,
                                                 nil,
                                                 vImage_Flags(kvImageNoFlags))

        guard error == kvImageNoError else {
            return nil
        }
        
        return outputPixelBuffer
    }
    
    func imageCopy(from data: Data) {
        pixeLock(.init(rawValue: 0))
        defer { pixelUnlockAction(.init(rawValue: 0)) }
        
        guard let baseAddress = baseMemoryData else {
            return
        }
        
        if byteRowData == pixelWidth * byteEveryPixelData {
            let numberOfBytesToCopy = min(data.count, pixelHeight * byteRowData)
            
            data.withUnsafeBytes { pointer in
                memcpy(baseAddress,
                       pointer.baseAddress,
                       numberOfBytesToCopy)
            }
            return
        }
        let remainderData = data.count % (pixelWidth*byteEveryPixelData)
        var dataShowHeight = data.count/(pixelWidth*byteEveryPixelData)
      
       
        if remainderData != 0 {
           
            dataShowHeight = dataShowHeight + 1
        }
        
      
        if data.count > pixelWidth * byteEveryPixelData * pixelHeight {
            for row in 0..<pixelHeight {
                data.withUnsafeBytes { pointer in
                    memcpy(baseAddress.advanced(by: byteRowData * row),
                           pointer.baseAddress?.advanced(by: byteEveryPixelData * pixelWidth * row),
                           pixelWidth * byteEveryPixelData)
                }
            }
        } else {
            for row in 0..<dataShowHeight {
                data.advanced(by: pixelWidth * byteEveryPixelData * row)
                    .withUnsafeBytes { pointer in
                        var numberOfBytesToCopy = pixelWidth * byteEveryPixelData
                        if pointer.count < pixelWidth * byteEveryPixelData {
                            numberOfBytesToCopy = remainderData
                        }
                        memcpy(baseAddress.advanced(by: byteRowData * row),
                               pointer.baseAddress,
                               numberOfBytesToCopy)
                }
            }
        }
    }
    
}
