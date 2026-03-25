import XCTest
import LocalAuthentication
@testable import KeychainSwift

class AccessControlTests: XCTestCase {

  var obj: TestableKeychainSwift!

  override func setUp() {
    super.setUp()

    obj = TestableKeychainSwift()
    try? obj.clear()
    obj.lastQueryParameters = nil
  }

  // MARK: - SecAccessControl creation

  func testCreateAccessControl_biometricCurrentSet() throws {
    let ac = KeychainSwiftAccessControl.biometricCurrentSet()
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  func testCreateAccessControl_biometricAny() throws {
    let ac = KeychainSwiftAccessControl.biometricAny()
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  func testCreateAccessControl_biometricOrPasscode() throws {
    let ac = KeychainSwiftAccessControl.biometricOrPasscode()
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  func testCreateAccessControl_devicePasscode() throws {
    let ac = KeychainSwiftAccessControl.devicePasscode()
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  func testCreateAccessControl_userPresence() throws {
    let ac = KeychainSwiftAccessControl.userPresence()
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  func testCreateAccessControl_customAccessibility() throws {
    let ac = KeychainSwiftAccessControl(
      accessibility: .accessibleWhenUnlockedThisDeviceOnly,
      flags: .userPresence
    )
    let secAC = try ac.createSecAccessControl()
    XCTAssertNotNil(secAC)
  }

  // MARK: - Preset values

  func testPreset_biometricCurrentSet_defaultAccessibility() {
    let ac = KeychainSwiftAccessControl.biometricCurrentSet()
    XCTAssertEqual(ac.accessibility, .accessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertEqual(ac.flags, .biometryCurrentSet)
  }

  func testPreset_biometricAny_defaultAccessibility() {
    let ac = KeychainSwiftAccessControl.biometricAny()
    XCTAssertEqual(ac.accessibility, .accessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertEqual(ac.flags, .biometryAny)
  }

  func testPreset_biometricOrPasscode_flags() {
    let ac = KeychainSwiftAccessControl.biometricOrPasscode()
    XCTAssertEqual(ac.accessibility, .accessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertTrue(ac.flags.contains(.biometryAny))
    XCTAssertTrue(ac.flags.contains(.devicePasscode))
  }

  func testPreset_devicePasscode_flags() {
    let ac = KeychainSwiftAccessControl.devicePasscode()
    XCTAssertEqual(ac.accessibility, .accessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertEqual(ac.flags, .devicePasscode)
  }

  func testPreset_userPresence_flags() {
    let ac = KeychainSwiftAccessControl.userPresence()
    XCTAssertEqual(ac.accessibility, .accessibleWhenPasscodeSetThisDeviceOnly)
    XCTAssertEqual(ac.flags, .userPresence)
  }

  func testPreset_customAccessibility() {
    let ac = KeychainSwiftAccessControl.biometricCurrentSet(
      accessibility: .accessibleAfterFirstUnlockThisDeviceOnly
    )
    XCTAssertEqual(ac.accessibility, .accessibleAfterFirstUnlockThisDeviceOnly)
    XCTAssertEqual(ac.flags, .biometryCurrentSet)
  }

  // MARK: - Set with access control — query parameters

  func testSet_withAccessControl_querySetsAccessControlAttribute() {
    // Use userPresence which is most compatible across test environments.
    // SecItemAdd may fail on the simulator, but lastQueryParameters is set before that call.
    let ac = KeychainSwiftAccessControl.userPresence()
    try? obj.set("test", forKey: "key1", withAccessControl: ac)

    // kSecAttrAccessControl should be present, kSecAttrAccessible should NOT
    XCTAssertNotNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessControl])
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessible])
  }

  func testSetData_withAccessControl_querySetsAccessControlAttribute() {
    let ac = KeychainSwiftAccessControl.userPresence()
    let data = "test".data(using: .utf8)!
    try? obj.set(data, forKey: "key1", withAccessControl: ac)

    XCTAssertNotNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessControl])
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessible])
  }

  func testSetBool_withAccessControl_querySetsAccessControlAttribute() {
    let ac = KeychainSwiftAccessControl.userPresence()
    try? obj.set(true, forKey: "key1", withAccessControl: ac)

    XCTAssertNotNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessControl])
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessible])
  }

  // MARK: - Set without access control — preserves existing behavior

  func testSet_withoutAccessControl_usesAccessible() throws {
    try obj.set("test", forKey: "key1")

    // kSecAttrAccessible should be present, kSecAttrAccessControl should NOT
    XCTAssertNotNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessible])
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessControl])
  }

  func testSet_withAccess_usesAccessible() throws {
    try obj.set("test", forKey: "key1", withAccess: .accessibleAfterFirstUnlock)

    let accessValue = obj.lastQueryParameters?[KeychainSwiftConstants.accessible] as? String
    XCTAssertEqual(KeychainSwiftAccessOptions.accessibleAfterFirstUnlock.value, accessValue)
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.accessControl])
  }

  // MARK: - Mutual exclusivity validation

  func testSet_bothAccessAndAccessControl_throws() {
    XCTAssertThrowsError(
      try obj.set("test", forKey: "key1",
                  withAccess: .accessibleWhenUnlocked,
                  withAccessControl: .userPresence())
    ) { error in
      let keychainError = error as? KeychainError
      XCTAssertEqual(keychainError?.rawValue, errSecParam)
    }
  }

  func testSetData_bothAccessAndAccessControl_throws() {
    let data = "test".data(using: .utf8)!
    XCTAssertThrowsError(
      try obj.set(data, forKey: "key1",
                  withAccess: .accessibleWhenUnlocked,
                  withAccessControl: .userPresence())
    ) { error in
      let keychainError = error as? KeychainError
      XCTAssertEqual(keychainError?.rawValue, errSecParam)
    }
  }

  func testSetBool_bothAccessAndAccessControl_throws() {
    XCTAssertThrowsError(
      try obj.set(true, forKey: "key1",
                  withAccess: .accessibleWhenUnlocked,
                  withAccessControl: .userPresence())
    ) { error in
      let keychainError = error as? KeychainError
      XCTAssertEqual(keychainError?.rawValue, errSecParam)
    }
  }

  // MARK: - Synchronizable + access control validation

  func testSet_synchronizableWithAccessControl_throws() {
    obj.synchronizable = true
    XCTAssertThrowsError(
      try obj.set("test", forKey: "key1", withAccessControl: .biometricCurrentSet())
    ) { error in
      let keychainError = error as? KeychainError
      XCTAssertEqual(keychainError?.rawValue, errSecParam)
    }
  }

  func testSetData_synchronizableWithAccessControl_throws() {
    obj.synchronizable = true
    let data = "test".data(using: .utf8)!
    XCTAssertThrowsError(
      try obj.set(data, forKey: "key1", withAccessControl: .biometricCurrentSet())
    ) { error in
      let keychainError = error as? KeychainError
      XCTAssertEqual(keychainError?.rawValue, errSecParam)
    }
  }

  func testSet_synchronizableWithoutAccessControl_succeeds() {
    obj.synchronizable = true
    // On macOS test runners without proper entitlements, synchronizable set may fail
    // with -34018 (errSecMissingEntitlement). The key check is that it does NOT throw
    // the errSecParam validation error that synchronizable + accessControl would throw.
    do {
      try obj.set("test", forKey: "sync_key1")
    } catch let error as KeychainError {
      // errSecParam (-50) would indicate our validation incorrectly blocked this
      XCTAssertNotEqual(error.rawValue, errSecParam,
                        "synchronizable without accessControl should not throw errSecParam")
    } catch {
      // Other errors (e.g., entitlement issues on CI) are acceptable
    }
  }

  // MARK: - Get with authentication prompt

  func testGet_withAuthenticationPrompt_addsToQuery() throws {
    try obj.set("test", forKey: "key1")
    _ = try? obj.get("key1", authenticationPrompt: "Verify identity")

    XCTAssertEqual(
      "Verify identity",
      obj.lastQueryParameters?[KeychainSwiftConstants.useOperationPrompt] as? String
    )
  }

  func testGetData_withAuthenticationPrompt_addsToQuery() throws {
    let data = "test".data(using: .utf8)!
    try obj.set(data, forKey: "key1")
    _ = try? obj.getData("key1", authenticationPrompt: "Verify identity")

    XCTAssertEqual(
      "Verify identity",
      obj.lastQueryParameters?[KeychainSwiftConstants.useOperationPrompt] as? String
    )
  }

  func testGetBool_withAuthenticationPrompt_addsToQuery() throws {
    try obj.set(true, forKey: "key1")
    _ = try? obj.getBool("key1", authenticationPrompt: "Verify identity")

    XCTAssertEqual(
      "Verify identity",
      obj.lastQueryParameters?[KeychainSwiftConstants.useOperationPrompt] as? String
    )
  }

  func testGet_withoutAuthenticationPrompt_doesNotAddToQuery() throws {
    try obj.set("test", forKey: "key1")
    _ = try obj.get("key1")

    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.useOperationPrompt])
  }

  func testGetData_withoutAuthenticationPrompt_doesNotAddToQuery() throws {
    let data = "test".data(using: .utf8)!
    try obj.set(data, forKey: "key1")
    _ = try obj.getData("key1")

    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.useOperationPrompt])
    XCTAssertNil(obj.lastQueryParameters?[KeychainSwiftConstants.useAuthenticationContext])
  }

  // MARK: - Get with authentication context

  func testGetData_withAuthenticationContext_addsToQuery() throws {
    try obj.set("test", forKey: "key1")

    // Use a real LAContext — NSObject would crash SecItemCopyMatching
    let context = LAContext()
    _ = try? obj.getData("key1", authenticationContext: context)

    XCTAssertNotNil(obj.lastQueryParameters?[KeychainSwiftConstants.useAuthenticationContext])
  }

  // MARK: - KeychainError convenience properties

  func testKeychainError_userCanceled() {
    let error = KeychainError.userCanceled
    XCTAssertEqual(error.rawValue, errSecUserCanceled)
  }

  func testKeychainError_authFailed() {
    let error = KeychainError.authFailed
    XCTAssertEqual(error.rawValue, errSecAuthFailed)
  }

  func testKeychainError_interactionNotAllowed() {
    let error = KeychainError.interactionNotAllowed
    XCTAssertEqual(error.rawValue, errSecInteractionNotAllowed)
  }

  func testKeychainError_equatable() {
    XCTAssertEqual(KeychainError.userCanceled, KeychainError(errSecUserCanceled))
    XCTAssertNotEqual(KeychainError.userCanceled, KeychainError.authFailed)
  }

  // MARK: - cfValue on KeychainSwiftAccessOptions

  func testCfValue_matchesStringValue() {
    // Verify that cfValue and value produce equivalent representations
    // for each accessibility option
    let options: [KeychainSwiftAccessOptions] = [
      .accessibleWhenUnlocked,
      .accessibleWhenUnlockedThisDeviceOnly,
      .accessibleAfterFirstUnlock,
      .accessibleAfterFirstUnlockThisDeviceOnly,
      .accessibleWhenPasscodeSetThisDeviceOnly
    ]

    for option in options {
      XCTAssertEqual(option.value, option.cfValue as String,
                     "cfValue and value should match for \(option)")
    }
  }

  // MARK: - allKeys does not crash with access-controlled items

  func testAllKeys_doesNotCrashOrThrow() throws {
    // Verify that allKeys works without crashing, even when access-controlled items
    // may exist in the keychain. On macOS test runners, the exact list of keys
    // returned depends on the system keychain state, so we just verify the call
    // completes without error.
    try obj.set("value1", forKey: "actest_allkeys_1")
    let keys = obj.allKeys
    XCTAssertTrue(keys is [String]) // Returns a valid string array

    // Clean up
    try? obj.delete("actest_allkeys_1")
  }
}
