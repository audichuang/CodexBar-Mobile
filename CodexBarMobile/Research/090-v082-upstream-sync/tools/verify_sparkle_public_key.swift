import Foundation
import CryptoKit
let args = CommandLine.arguments
let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: args[1])), options: [], format: nil) as! [String: Any]
let publicKeyData = Data(base64Encoded: plist["SUPublicEDKey"] as! String)!
let signatureData = Data(base64Encoded: args[3])!
let updateData = try Data(contentsOf: URL(fileURLWithPath: args[2]), options: .mappedIfSafe)
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
guard publicKey.isValidSignature(signatureData, for: updateData) else { fatalError("Sparkle client public key does not trust candidate signature") }
print("SPARKLE_CLIENT_PUBLIC_KEY_SIGNATURE_VERIFIED")
