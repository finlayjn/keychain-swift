import XCTest
@testable import KeychainSwift

class ClearTests: XCTestCase {
  
  var obj: TestableKeychainSwift!
  
  override func setUp() {
    super.setUp()
    
    obj = TestableKeychainSwift()
  }
  
  func testClear() {
    try? obj.set("hello :)", forKey: "key 1")
    try? obj.set("hello two", forKey: "key 2")
    
    try? obj.clear()
    
    XCTAssert(try obj.get("key 1") == nil)
    XCTAssert(try obj.get("key 2") == nil)
  }
}

