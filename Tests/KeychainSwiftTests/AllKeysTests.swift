//
//  AllKeysTests.swift
//  KeychainSwiftTests
//
//  Created by Lucas Paim on 02/01/20.
//  Copyright © 2020 Evgenii Neumerzhitckii. All rights reserved.
//

import XCTest
@testable import KeychainSwift


class AllKeysTests: XCTestCase {
  
  var obj: TestableKeychainSwift!
  
  override func setUp() {
    super.setUp()
    
    obj = TestableKeychainSwift()
    try? obj.clear()
  }
  
  // MARK: - allKeys
  func testAddSynchronizableGroup_addItemsFalse() {
    let items: [String] = [
      "one", "two"
    ]
    
    items.enumerated().forEach { enumerator in
      try? self.obj!.set("\(enumerator.offset)", forKey: enumerator.element)
    }
    
    // On macOS, allKeys may return items from other apps in the same keychain.
    // Check that our keys are present rather than an exact match.
    let allKeys = Set(obj.allKeys)
    XCTAssertTrue(allKeys.contains("one"), "allKeys should contain 'one'")
    XCTAssertTrue(allKeys.contains("two"), "allKeys should contain 'two'")
    
    try? obj.clear()
    // After clearing, our keys should no longer be present.
    // Note: on macOS, allKeys may still return system-level items from other apps,
    // so we check that our specific keys were removed rather than asserting empty.
    let remainingKeys = obj.allKeys
    XCTAssertFalse(remainingKeys.contains("one"))
    XCTAssertFalse(remainingKeys.contains("two"))
    
  }
}
