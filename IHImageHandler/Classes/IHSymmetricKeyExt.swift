
import Foundation
import CryptoKit

 extension SymmetricKey {
    
    init(dataSource keyStr: String) {
        var sha256 = SHA256()
        let keyData = keyStr.data(using: .utf8)!
        sha256.update(data: keyData)
        let hashedKeyData = Data(sha256.finalize())
        self = SymmetricKey(data: hashedKeyData)
    }
}

