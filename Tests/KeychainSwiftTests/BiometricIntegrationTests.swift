import XCTest
import LocalAuthentication
@testable import KeychainSwift

/**
 Integration tests for biometric/passcode-protected keychain items.

 These tests perform REAL keychain operations with access control and will trigger
 actual system authentication prompts (Face ID, Touch ID, or passcode).

 **Requirements:**
 - Must run on a PHYSICAL device (not the Simulator — no Secure Enclave)
 - Device must have a passcode set
 - Device must have biometrics enrolled (for biometric-specific tests)
 - The `NSFaceIDUsageDescription` key must be present in the test target's Info.plist
   (if targeting a Face ID device)

 **How to run:**
 - Run from Xcode on a connected physical device
 - You will be prompted to authenticate multiple times — complete each prompt to pass the tests.
 - Tests that cannot run on the current device (e.g., biometric tests on a device without
   biometrics) will be skipped automatically.

 **Note:** These tests are excluded from CI/automated test runs by default since they
 require interactive user authentication. To run them, target a physical device in Xcode.
*/
class BiometricIntegrationTests: XCTestCase {

  var keychain: KeychainSwift!

  /// Whether the current device supports biometric authentication
  private var deviceSupportsBiometrics: Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  /// Whether the current device has a passcode set
  private var deviceHasPasscode: Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
  }

  /// Whether access-controlled keychain items can actually be stored.
  /// On macOS test runners via SPM, entitlements may be missing (-34018).
  /// This performs a probe write + delete to check.
  private var canStoreAccessControlledItems: Bool {
    let probe = KeychainSwiftAccessControl.devicePasscode()
    guard let secAC = try? probe.createSecAccessControl() else { return false }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: "__biotest_probe__",
      kSecValueData as String: Data([0]),
      kSecAttrAccessControl as String: secAC
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecSuccess {
      // Clean up the probe item
      let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "__biotest_probe__"
      ]
      SecItemDelete(deleteQuery as CFDictionary)
      return true
    }
    return false
  }

  override func setUp() {
    super.setUp()
    keychain = KeychainSwift(keyPrefix: "biotest_")
    // Clean up any leftover test items
    try? keychain.delete("biometric_string")
    try? keychain.delete("biometric_data")
    try? keychain.delete("biometric_bool")
    try? keychain.delete("passcode_string")
    try? keychain.delete("user_presence_string")
  }

  override func tearDown() {
    // Clean up test items
    try? keychain.delete("biometric_string")
    try? keychain.delete("biometric_data")
    try? keychain.delete("biometric_bool")
    try? keychain.delete("passcode_string")
    try? keychain.delete("user_presence_string")
    super.tearDown()
  }

  // MARK: - Biometric (Face ID / Touch ID) round-trip tests
  //
  // These tests store an item with biometric access control, then read it back.
  // The system will prompt you for Face ID / Touch ID during the read.

  func testBiometricCurrentSet_stringRoundTrip() throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")

    // Store with biometricCurrentSet — item is invalidated if biometrics change
    try keychain.set("biometric_secret_value", forKey: "biometric_string",
                     withAccessControl: .biometricCurrentSet())

    // Read back — this will trigger a Face ID / Touch ID prompt.
    // Authenticate successfully to pass the test.
    let value = try keychain.get("biometric_string",
                                  authenticationPrompt: "Authenticate to verify biometric test")

    XCTAssertEqual("biometric_secret_value", value)
  }

  func testBiometricCurrentSet_dataRoundTrip() throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")

    let originalData = "biometric_data_payload".data(using: .utf8)!
    try keychain.set(originalData, forKey: "biometric_data",
                     withAccessControl: .biometricCurrentSet())

    // Authenticate when prompted
    let retrievedData = try keychain.getData("biometric_data",
                                              authenticationPrompt: "Authenticate for data test")

    XCTAssertEqual(originalData, retrievedData)
  }

  func testBiometricCurrentSet_boolRoundTrip() throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")

    try keychain.set(true, forKey: "biometric_bool",
                     withAccessControl: .biometricCurrentSet())

    // Authenticate when prompted
    let value = try keychain.getBool("biometric_bool",
                                      authenticationPrompt: "Authenticate for bool test")

    XCTAssertEqual(true, value)
  }

  // MARK: - Device passcode round-trip test

  func testDevicePasscode_stringRoundTrip() throws {
    try XCTSkipUnless(deviceHasPasscode,
                      "Skipping: device does not have a passcode set")
    try XCTSkipUnless(canStoreAccessControlledItems,
                      "Skipping: access-controlled keychain items not supported in this environment")

    try keychain.set("passcode_secret", forKey: "passcode_string",
                     withAccessControl: .devicePasscode())

    // This will prompt for the device passcode
    let value = try keychain.get("passcode_string",
                                  authenticationPrompt: "Enter passcode to verify test")

    XCTAssertEqual("passcode_secret", value)
  }

  // MARK: - User presence round-trip test

  func testUserPresence_stringRoundTrip() throws {
    try XCTSkipUnless(deviceHasPasscode,
                      "Skipping: device does not have a passcode set")
    try XCTSkipUnless(canStoreAccessControlledItems,
                      "Skipping: access-controlled keychain items not supported in this environment")

    try keychain.set("presence_secret", forKey: "user_presence_string",
                     withAccessControl: .userPresence())

    // System chooses biometric or passcode
    let value = try keychain.get("user_presence_string",
                                  authenticationPrompt: "Verify your identity")

    XCTAssertEqual("presence_secret", value)
  }

  // MARK: - Async round-trip test

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func testBiometricCurrentSet_asyncRoundTrip() async throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")

    try keychain.set("async_biometric_value", forKey: "biometric_string",
                     withAccessControl: .biometricCurrentSet())

    // Read via async wrapper — authentication prompt on background thread
    let value = try await keychain.getAsync("biometric_string",
                                             authenticationPrompt: "Async biometric test")

    XCTAssertEqual("async_biometric_value", value)
  }

  // MARK: - LAContext reuse test

  func testLAContextReuse_multipleReads() throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")

    // Store two items with biometric protection
    try keychain.set("value_one", forKey: "biometric_string",
                     withAccessControl: .biometricCurrentSet())
    try keychain.set("value_two".data(using: .utf8)!, forKey: "biometric_data",
                     withAccessControl: .biometricCurrentSet())

    // Pre-authenticate with LAContext — user authenticates ONCE
    let context = LAContext()
    let expectation = self.expectation(description: "LAContext authentication")
    var authSuccess = false

    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Authenticate once for multi-read test") { success, _ in
      authSuccess = success
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 30.0)
    try XCTSkipUnless(authSuccess, "User did not authenticate")

    // Read both items using the pre-authenticated context — no additional prompts
    let value1 = try keychain.get("biometric_string", authenticationContext: context)
    let value2 = try keychain.getData("biometric_data", authenticationContext: context)

    XCTAssertEqual("value_one", value1)
    XCTAssertEqual("value_two".data(using: .utf8)!, value2)
  }

  // MARK: - User cancellation test
  //
  // This test is iOS-only because macOS may auto-authenticate via Touch ID
  // without showing a cancellable prompt. On iOS, you MUST tap "Cancel"
  // when the Face ID / Touch ID dialog appears to pass this test.

  #if os(iOS)
  @available(iOS 13.0, *)
  func testBiometric_userCancellation() throws {
    try XCTSkipUnless(deviceSupportsBiometrics,
                      "Skipping: device does not support biometrics")
    try XCTSkipUnless(canStoreAccessControlledItems,
                      "Skipping: access-controlled keychain items not supported in this environment")

    try keychain.set("cancel_test", forKey: "biometric_string",
                     withAccessControl: .biometricCurrentSet())

    // Show an alert to warn the user that the NEXT prompt must be cancelled.
    let alertExpectation = self.expectation(description: "User acknowledged cancellation instructions")

    DispatchQueue.main.async {
      guard let scene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .first,
            let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        alertExpectation.fulfill()
        return
      }

      let alert = UIAlertController(
        title: "Cancellation Test",
        message: "After you tap OK, a biometric prompt will appear. CANCEL or DISMISS that prompt to pass this test.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        alertExpectation.fulfill()
      })
      rootVC.present(alert, animated: true)
    }

    wait(for: [alertExpectation], timeout: 30.0)

    // Now the biometric prompt appears — the user should CANCEL it.
    XCTAssertThrowsError(
      try keychain.get("biometric_string",
                       authenticationPrompt: "CANCEL THIS PROMPT to pass the test")
    ) { error in
      let keychainError = error as? KeychainError
      // errSecUserCanceled (-128) or errSecAuthFailed (-25293)
      XCTAssertTrue(
        keychainError == .userCanceled || keychainError == .authFailed,
        "Expected userCanceled or authFailed, got \(String(describing: keychainError))"
      )
    }
  }
  #endif
}
