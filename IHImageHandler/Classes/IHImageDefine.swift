
import Foundation
import CryptoKit

public typealias ImageFuzzyHandler = (Result<IHFuzzyedImage, Error>) -> (Void)

public enum IHFuzzyError: Error {
    case invalidString
    case invalidSourceData
    case fuzzyError
}

public struct IHFuzzyedImage {
    public var ciImageData: CIImage
    public var uiImageData: UIImage {
        UIImage(ciImage: ciImageData)
    }
    public var pngImageData: Data? {
        CIContext().pngRepresentation(of: ciImageData,
                                    format: .BGRA8,
                                    colorSpace: ciImageData.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!)
    }
}
