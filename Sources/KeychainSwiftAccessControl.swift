import Security
import Foundation

/**

 Represents an access control configuration for keychain items that combines
 an accessibility level with access control flags (e.g., biometric or passcode requirements).

 Use this type with the `withAccessControl` parameter on `set` methods to require
 user authentication (Face ID, Touch ID, or device passcode) when accessing keychain items.

 - Important: `kSecAttrAccessControl` and `kSecAttrAccessible` are mutually exclusive.
   When you provide a `KeychainSwiftAccessControl`, the library uses `kSecAttrAccessControl`
   and does NOT set `kSecAttrAccessible` separately. The accessibility level is embedded
   in the access control object.

 - Important: Access-controlled items cannot be synchronized via iCloud Keychain.
   Attempting to use `synchronizable = true` with access control will throw an error.

 - Important: Reading an access-controlled item triggers a system authentication prompt
   (Face ID, Touch ID, or passcode). This blocks the calling thread until the user
   responds. Always call `get`/`getData`/`getBool` from a background thread, never from
   the main thread.

 ## Presets

 ```swift
 // Biometric only — invalidated when biometric enrollment changes
 let accessControl = KeychainSwiftAccessControl.biometricCurrentSet()

 // Biometric with any enrollment — survives biometric changes
 let accessControl = KeychainSwiftAccessControl.biometricAny()

 // Biometric preferred, device passcode as fallback
 let accessControl = KeychainSwiftAccessControl.biometricOrPasscode()

 // Device passcode only
 let accessControl = KeychainSwiftAccessControl.devicePasscode()

 // System decides (biometric or passcode)
 let accessControl = KeychainSwiftAccessControl.userPresence()
 ```

 ## Custom Configuration

 ```swift
 // Custom flags with custom accessibility
 let accessControl = KeychainSwiftAccessControl(
     accessibility: .accessibleWhenPasscodeSetThisDeviceOnly,
     flags: [.biometryCurrentSet, .or, .devicePasscode]
 )
 ```

*/
public struct KeychainSwiftAccessControl: Sendable {

  // MARK: - Properties

  /// The base accessibility level for the keychain item.
  /// This determines *when* the item can be accessed relative to the device lock state,
  /// and is passed as the first parameter to `SecAccessControlCreateWithFlags`.
  public let accessibility: KeychainSwiftAccessOptions

  /// The access control flags specifying *how* the user must authenticate.
  /// These map directly to `SecAccessControlCreateFlags` values such as
  /// `.biometryCurrentSet`, `.biometryAny`, `.devicePasscode`, and `.userPresence`.
  public let flags: SecAccessControlCreateFlags

  // MARK: - Initialization

  /**
   Creates an access control configuration with the given accessibility and flags.

   - parameter accessibility: The base accessibility level. Defaults to
     `.accessibleWhenPasscodeSetThisDeviceOnly`, which is the most secure option
     and is recommended for biometric-protected items. This ensures items are
     deleted if the device passcode is removed.
   - parameter flags: The `SecAccessControlCreateFlags` to apply. Common values include
     `.biometryCurrentSet`, `.biometryAny`, `.devicePasscode`, and `.userPresence`.
  */
  public init(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly,
    flags: SecAccessControlCreateFlags
  ) {
    self.accessibility = accessibility
    self.flags = flags
  }

  // MARK: - Presets

  /**
   Biometric only — tied to the *current* biometric enrollment.

   If the user adds or removes a fingerprint or Face ID profile after the item is stored,
   the keychain item becomes permanently inaccessible (effectively destroyed). This provides
   the strongest guarantee that a biometric change by a malicious actor cannot unlock
   existing secrets. There is no passcode fallback.

   - parameter accessibility: The base accessibility level.
     Defaults to `.accessibleWhenPasscodeSetThisDeviceOnly`.
   - returns: A configured `KeychainSwiftAccessControl`.
  */
  @available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
  public static func biometricCurrentSet(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly
  ) -> KeychainSwiftAccessControl {
    KeychainSwiftAccessControl(accessibility: accessibility, flags: .biometryCurrentSet)
  }

  /**
   Biometric with any enrolled biometric — survives biometric enrollment changes.

   Access is granted with any currently enrolled biometric (Face ID or Touch ID).
   The item remains accessible even if the user adds or removes biometric profiles
   after storage. There is no passcode fallback.

   - parameter accessibility: The base accessibility level.
     Defaults to `.accessibleWhenPasscodeSetThisDeviceOnly`.
   - returns: A configured `KeychainSwiftAccessControl`.
  */
  @available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
  public static func biometricAny(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly
  ) -> KeychainSwiftAccessControl {
    KeychainSwiftAccessControl(accessibility: accessibility, flags: .biometryAny)
  }

  /**
   Biometric preferred, with device passcode as fallback.

   The system tries biometrics first (Face ID or Touch ID). If biometrics are unavailable
   or the user taps "Enter Password", the device passcode is accepted instead.
   This is the most user-friendly option for access-controlled items.

   - parameter accessibility: The base accessibility level.
     Defaults to `.accessibleWhenPasscodeSetThisDeviceOnly`.
   - returns: A configured `KeychainSwiftAccessControl`.
  */
  @available(macOS 10.13.4, iOS 11.3, watchOS 4.3, tvOS 11.3, *)
  public static func biometricOrPasscode(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly
  ) -> KeychainSwiftAccessControl {
    KeychainSwiftAccessControl(
      accessibility: accessibility,
      flags: [.biometryAny, .or, .devicePasscode]
    )
  }

  /**
   Device passcode only — no biometric authentication.

   The user must enter their device passcode to access the item.
   Biometrics are not offered.

   - parameter accessibility: The base accessibility level.
     Defaults to `.accessibleWhenPasscodeSetThisDeviceOnly`.
   - returns: A configured `KeychainSwiftAccessControl`.
  */
  public static func devicePasscode(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly
  ) -> KeychainSwiftAccessControl {
    KeychainSwiftAccessControl(accessibility: accessibility, flags: .devicePasscode)
  }

  /**
   User presence — lets the system decide the best authentication method.

   The system chooses biometrics or passcode depending on what's available and
   the current context. This is the most flexible option.

   - parameter accessibility: The base accessibility level.
     Defaults to `.accessibleWhenPasscodeSetThisDeviceOnly`.
   - returns: A configured `KeychainSwiftAccessControl`.
  */
  public static func userPresence(
    accessibility: KeychainSwiftAccessOptions = .accessibleWhenPasscodeSetThisDeviceOnly
  ) -> KeychainSwiftAccessControl {
    KeychainSwiftAccessControl(accessibility: accessibility, flags: .userPresence)
  }

  // MARK: - Internal

  /**
   Creates the `SecAccessControl` object from this configuration.

   This calls `SecAccessControlCreateWithFlags` with the configured accessibility
   and flags. The resulting object is used as the value for `kSecAttrAccessControl`
   in keychain queries.

   - throws: `KeychainError` if the access control object could not be created
     (e.g., invalid flag combinations or unsupported accessibility level).
   - returns: A `SecAccessControl` instance ready for use in keychain operations.
  */
  func createSecAccessControl() throws -> SecAccessControl {
    var error: Unmanaged<CFError>?

    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      accessibility.cfValue,
      flags,
      &error
    ) else {
      // Extract the OSStatus from the CFError if available, otherwise use a generic param error
      if let cfError = error?.takeRetainedValue() {
        let nsError = cfError as Error as NSError
        throw KeychainError(OSStatus(nsError.code))
      }
      throw KeychainError(errSecParam)
    }

    return access
  }
}
