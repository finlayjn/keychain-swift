import Security
import Foundation
import KeychainSwift // You might need to remove this import in your project

/**
 
 This file can be used in your ObjC project if you want to use KeychainSwift Swift library.
 Extend this file to add other functionality for your app.
 
 How to use
 ----------
 
 1. Import swift code in your ObjC file:
 
 #import "YOUR_PRODUCT_MODULE_NAME-Swift.h"
 
 2. Use KeychainSwift in your ObjC code:
 
 - (void)viewDidLoad {
 [super viewDidLoad];
 
 KeychainSwiftCBridge *keychain = [[KeychainSwiftCBridge alloc] init];
 [keychain set:@"Hello World" forKey:@"my key"];
 NSString *value = [keychain get:@"my key"];
 
 3. You might need to remove `import KeychainSwift` import from this file in your project.
 
*/
@objcMembers public class KeychainSwiftCBridge: NSObject {
  let keychain: KeychainSwift

  public init(keyPrefix: String = "", accessGroup: String? = nil, synchronizable: Bool = false) {
    keychain = KeychainSwift(keyPrefix: keyPrefix, accessGroup: accessGroup, synchronizable: synchronizable)
    super.init()
  }

  open var accessGroup: String? {
    return keychain.accessGroup
  }

  open var synchronizable: Bool {
    return keychain.synchronizable
  }


  open func set(_ value: String, forKey key: String) throws {
    try keychain.set(value, forKey: key)
  }

  open func setData(_ value: Data, forKey key: String) throws {
    try keychain.set(value, forKey: key)
  }

  open func setBool(_ value: Bool, forKey key: String) throws {
    try keychain.set(value, forKey: key)
  }

  open func get(_ key: String) throws -> String? {
    return try keychain.get(key)
  }

  open func getData(_ key: String) throws -> Data? {
    return try keychain.getData(key)
  }

  open func getBool(_ key: String) throws -> Bool? {
    return try keychain.getBool(key)
  }

  @discardableResult
  open func delete(_ key: String) throws -> Bool {
    return try keychain.delete(key)
  }

  open func clear() throws {
    try keychain.clear()
  }
}
