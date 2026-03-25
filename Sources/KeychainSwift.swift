import Security
import Foundation

/**

A collection of helper functions for saving text and data in the keychain.

*/
open class KeychainSwift: @unchecked Sendable {
  
  var lastQueryParameters: [String: Any]? // Used by the unit tests

  var keyPrefix = "" // Can be useful in test.
  
  /**

  Specify an access group that will be used to access keychain items. Access groups can be used to share keychain items between applications. When access group value is nil all application access groups are being accessed. Access group name is used by all functions: set, get, delete and clear.

  */
  open var accessGroup: String? { _accessGroup }
  private let _accessGroup: String?
  
  /**
   
  Specifies whether the items can be synchronized with other devices through iCloud. Setting this property to true will
   add the item to other devices with the `set` method and obtain synchronizable items with the `get` command. Deleting synchronizable items will remove them from all devices. In order for keychain synchronization to work the user must enable "Keychain" in iCloud settings.
   
  Does not work on macOS.
   
  */
  open var synchronizable: Bool { _synchronizable }
  private let _synchronizable: Bool

  private let lock = NSLock()

  /**
  
   Instantiate a KeychainSwift object
   
  - parameter keyPrefix: a prefix that is added before the key in get/set methods. Note that `clear` method still clears everything from the Keychain.
  - parameter accessGroup: Access groups can be used to share keychain items between applications. When access group value is nil all application access groups are being accessed. Access group name is used by all functions: set, get, delete and clear.
  - parameter synchronizable: Specifies whether the items can be synchronized with other devices through iCloud. Setting this property to true will add the item to other devices with the `set` method and obtain synchronizable items with the `get` command. Deleting synchronizable items will remove them from all devices. In order for keychain synchronization to work the user must enable "Keychain" in iCloud settings. Does not work on macOS.

  */
  public init(keyPrefix: String = "", accessGroup: String? = nil, synchronizable: Bool = false) {
    self.keyPrefix = keyPrefix
    _accessGroup = accessGroup
    _synchronizable = synchronizable
  }
  
  /**
  
  Stores the text value in the keychain item under the given key.
  
  - parameter key: Key under which the text value is stored in the keychain.
  - parameter value: Text string to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the text in the keychain item.
    By default the `.accessibleWhenUnlocked` option is used that permits the data to be accessed only
    while the device is unlocked by the user. Mutually exclusive with `withAccessControl`.
  - parameter withAccessControl: Access control configuration requiring user authentication
    (e.g., biometrics or passcode) to read the item. Mutually exclusive with `withAccess`.
    When provided, `kSecAttrAccessControl` is used instead of `kSecAttrAccessible`.

  */
  open func set(_ value: String, forKey key: String,
                  withAccess access: KeychainSwiftAccessOptions? = nil,
                  withAccessControl accessControl: KeychainSwiftAccessControl? = nil) throws {
    
    if let value = value.data(using: String.Encoding.utf8) {
      try set(value, forKey: key, withAccess: access, withAccessControl: accessControl)
    } else {
      throw KeychainError(errSecInvalidEncoding)
    }
  }

  /**
  
  Stores the data in the keychain item under the given key.
  
  - parameter key: Key under which the data is stored in the keychain.
  - parameter value: Data to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the text in the keychain item.
    By default the `.accessibleWhenUnlocked` option is used that permits the data to be accessed only
    while the device is unlocked by the user. Mutually exclusive with `withAccessControl`.
  - parameter withAccessControl: Access control configuration requiring user authentication
    (e.g., biometrics or passcode) to read the item. Mutually exclusive with `withAccess`.
    When provided, `kSecAttrAccessControl` is used instead of `kSecAttrAccessible`.
  
  - Important: Access-controlled items cannot be synchronized via iCloud Keychain.
    Setting `synchronizable = true` with `withAccessControl` will throw an error.
  
  */
  open func set(_ value: Data, forKey key: String,
    withAccess access: KeychainSwiftAccessOptions? = nil,
    withAccessControl accessControl: KeychainSwiftAccessControl? = nil) throws {
    
    // Validate: withAccess and withAccessControl are mutually exclusive.
    // kSecAttrAccessible and kSecAttrAccessControl cannot coexist in the same query.
    if access != nil && accessControl != nil {
      throw KeychainError(errSecParam)
    }
    
    // Validate: access-controlled items are device-bound and cannot sync via iCloud Keychain.
    if accessControl != nil && synchronizable {
      throw KeychainError(errSecParam)
    }
    
    // The lock prevents the code to be run simultaneously
    // from multiple threads which may result in crashing
    lock.lock()
    defer { lock.unlock() }
    
    try deleteNoLock(key) // Delete any existing key before saving it

    let prefixedKey = keyWithPrefix(key)
      
    var query: [String : Any] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey,
      KeychainSwiftConstants.valueData   : value
    ]

    // Use access control (biometric/passcode) or simple accessibility, never both.
    // SecAccessControl embeds the accessibility level, so kSecAttrAccessible is not needed.
    if let accessControl = accessControl {
      let secAccessControl = try accessControl.createSecAccessControl()
      query[KeychainSwiftConstants.accessControl] = secAccessControl
    } else {
      let accessible = access?.value ?? KeychainSwiftAccessOptions.defaultOption.value
      query[KeychainSwiftConstants.accessible] = accessible
    }
      
    addAccessGroupWhenPresent(&query)
    addSynchronizableIfRequired(&query, addingItems: true)
    lastQueryParameters = query
    
    try throwIfFailed(SecItemAdd(query as CFDictionary, nil))
  }

  /**

  Stores the boolean value in the keychain item under the given key.

  - parameter key: Key under which the value is stored in the keychain.
  - parameter value: Boolean to be written to the keychain.
  - parameter withAccess: Value that indicates when your app needs access to the value in the keychain item.
    By default the `.accessibleWhenUnlocked` option is used that permits the data to be accessed only
    while the device is unlocked by the user. Mutually exclusive with `withAccessControl`.
  - parameter withAccessControl: Access control configuration requiring user authentication
    (e.g., biometrics or passcode) to read the item. Mutually exclusive with `withAccess`.
    When provided, `kSecAttrAccessControl` is used instead of `kSecAttrAccessible`.

  */
  open func set(_ value: Bool, forKey key: String,
    withAccess access: KeychainSwiftAccessOptions? = nil,
    withAccessControl accessControl: KeychainSwiftAccessControl? = nil) throws {
  
    let bytes: [UInt8] = value ? [1] : [0]
    let data = Data(bytes)

    try set(data, forKey: key, withAccess: access, withAccessControl: accessControl)
  }

  /**
  
  Retrieves the text value from the keychain that corresponds to the given key.
  
  - parameter key: The key that is used to read the keychain item.
  - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode
    prompt when reading an access-controlled item. If nil, no prompt text is added.
  - parameter authenticationContext: Optional pre-authenticated `LAContext` (from LocalAuthentication)
    to reuse a previous authentication. Pass this to avoid repeated biometric prompts when
    reading multiple protected items. Must be an `LAContext` instance.
  - returns: The text value from the keychain. Returns nil if unable to read the item.
  
  - Important: If the item has access control, this call blocks the calling thread while the
    system authentication UI is displayed. Call from a background thread, not the main thread.
  
  */
  open func get(_ key: String,
                authenticationPrompt: String? = nil,
                authenticationContext: AnyObject? = nil) throws -> String? {
    if let data = try getData(key, authenticationPrompt: authenticationPrompt,
                              authenticationContext: authenticationContext) {
      
      if let currentString = String(data: data, encoding: .utf8) {
        return currentString
      }
      
      throw KeychainError(errSecInvalidEncoding)
    }

    return nil
  }

  /**
  
  Retrieves the data from the keychain that corresponds to the given key.
  
  - parameter key: The key that is used to read the keychain item.
  - parameter asReference: If true, returns the data as reference (needed for things like NEVPNProtocol).
  - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode
    prompt when reading an access-controlled item. If nil, no prompt text is added.
  - parameter authenticationContext: Optional pre-authenticated `LAContext` (from LocalAuthentication)
    to reuse a previous authentication. Pass this to avoid repeated biometric prompts when
    reading multiple protected items. Must be an `LAContext` instance.
  - returns: The text value from the keychain. Returns nil if unable to read the item.
  
  - Important: If the item has access control, this call blocks the calling thread while the
    system authentication UI is displayed. Call from a background thread, not the main thread.
  - Throws: `KeychainError.userCanceled` if the user dismisses the authentication prompt.
    `KeychainError.authFailed` if authentication fails.
    `KeychainError.interactionNotAllowed` if the app cannot display the authentication UI
    (e.g., while in the background).
  
  */
  open func getData(_ key: String, asReference: Bool = false,
                    authenticationPrompt: String? = nil,
                    authenticationContext: AnyObject? = nil) throws -> Data? {
    // The lock prevents the code to be run simultaneously
    // from multiple threads which may result in crashing
    lock.lock()
    defer { lock.unlock() }
    
    let prefixedKey = keyWithPrefix(key)
    
    var query: [String: Any] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey,
      KeychainSwiftConstants.matchLimit  : kSecMatchLimitOne
    ]
    
    if asReference {
      query[KeychainSwiftConstants.returnReference] = kCFBooleanTrue
    } else {
      query[KeychainSwiftConstants.returnData] =  kCFBooleanTrue
    }

    // Add authentication parameters for access-controlled items.
    // These are only used when the item was stored with SecAccessControl.
    if let prompt = authenticationPrompt {
      query[KeychainSwiftConstants.useOperationPrompt] = prompt
    }

    if let context = authenticationContext {
      query[KeychainSwiftConstants.useAuthenticationContext] = context
    }
    
    addAccessGroupWhenPresent(&query)
    addSynchronizableIfRequired(&query, addingItems: false)
    lastQueryParameters = query
    
    var result: AnyObject?
    
    let lastResultCode = withUnsafeMutablePointer(to: &result) {
      SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
    }
    
    if lastResultCode != errSecItemNotFound {
      try throwIfFailed(lastResultCode)
    }
    
    return result as? Data
  }

  /**

  Retrieves the boolean value from the keychain that corresponds to the given key.

  - parameter key: The key that is used to read the keychain item.
  - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode
    prompt when reading an access-controlled item. If nil, no prompt text is added.
  - parameter authenticationContext: Optional pre-authenticated `LAContext` (from LocalAuthentication)
    to reuse a previous authentication. Pass this to avoid repeated biometric prompts when
    reading multiple protected items. Must be an `LAContext` instance.
  - returns: The boolean value from the keychain. Returns nil if unable to read the item.

  */
  open func getBool(_ key: String,
                    authenticationPrompt: String? = nil,
                    authenticationContext: AnyObject? = nil) throws -> Bool? {
    guard let data = try getData(key, authenticationPrompt: authenticationPrompt,
                                 authenticationContext: authenticationContext) else { return nil }
    guard let firstBit = data.first else { return nil }
    return firstBit == 1
  }

  /**

  Deletes the single keychain item specified by the key.
  
  - parameter key: The key that is used to delete the keychain item.
  - returns: True if the item was successfully deleted.
  
  */
  @discardableResult
  open func delete(_ key: String) throws -> Bool {
    // The lock prevents the code to be run simultaneously
    // from multiple threads which may result in crashing
    lock.lock()
    defer { lock.unlock() }
    
    return try deleteNoLock(key)
  }
  
  /**
  Return all keys from keychain
   
  - returns: An string array with all keys from the keychain.
   
  */
  public var allKeys: [String] {
    lock.lock()
    defer { lock.unlock() }
      
    // Note: returnData is intentionally included. On macOS, it filters results to only
    // items this process can access. For access-controlled items with kSecMatchLimitAll,
    // items requiring interactive authentication are silently skipped rather than triggering
    // individual biometric prompts.
    var query: [String: Any] = [
      KeychainSwiftConstants.klass : kSecClassGenericPassword,
      KeychainSwiftConstants.returnData : true,
      KeychainSwiftConstants.returnAttributes: true,
      KeychainSwiftConstants.returnReference: true,
      KeychainSwiftConstants.matchLimit: KeychainSwiftConstants.secMatchLimitAll
    ]
  
    addAccessGroupWhenPresent(&query)
    addSynchronizableIfRequired(&query, addingItems: false)

    var result: AnyObject?

    let lastResultCode = withUnsafeMutablePointer(to: &result) {
      SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
    }
    
    if lastResultCode == noErr {
      return (result as? [[String: Any]])?.compactMap {
        $0[KeychainSwiftConstants.attrAccount] as? String } ?? []
    }
    
    return []
  }
    
  /**
   
  Same as `delete` but is only accessed internally, since it is not thread safe.
   
   - parameter key: The key that is used to delete the keychain item.
   - returns: True if the item was successfully deleted.
   
   */
   @discardableResult
   func deleteNoLock(_ key: String) throws -> Bool {
    let prefixedKey = keyWithPrefix(key)
    
    var query: [String: Any] = [
      KeychainSwiftConstants.klass       : kSecClassGenericPassword,
      KeychainSwiftConstants.attrAccount : prefixedKey
    ]
    
    addAccessGroupWhenPresent(&query)
    addSynchronizableIfRequired(&query, addingItems: false)
    lastQueryParameters = query
    
    let lastResultCode = SecItemDelete(query as CFDictionary)
    
    guard lastResultCode != errSecItemNotFound else { return false }
      
    try throwIfFailed(lastResultCode)
    return true
  }

  /**
  
  Deletes all Keychain items used by the app. Note that this method deletes all items regardless of the prefix settings used for initializing the class.
  
  */
  open func clear() throws {
    // The lock prevents the code to be run simultaneously
    // from multiple threads which may result in crashing
    lock.lock()
    defer { lock.unlock() }
    
    var query: [String: Any] = [ kSecClass as String : kSecClassGenericPassword ]
    addAccessGroupWhenPresent(&query)
    addSynchronizableIfRequired(&query, addingItems: false)
    lastQueryParameters = query
    
    try throwIfFailed(SecItemDelete(query as CFDictionary))
  }
  
  /// Returns the key with currently set prefix.
  func keyWithPrefix(_ key: String) -> String {
    return "\(keyPrefix)\(key)"
  }
  
  func addAccessGroupWhenPresent(_ items: inout [String: Any]) {
    guard let accessGroup = accessGroup else { return }
    
    items[KeychainSwiftConstants.accessGroup] = accessGroup
  }
  
  /**
 
  Adds kSecAttrSynchronizable: kSecAttrSynchronizableAny` item to the dictionary when the `synchronizable` property is true.
   
   - parameter items: The dictionary where the kSecAttrSynchronizable items will be added when requested.
   - parameter addingItems: Use `true` when the dictionary will be used with `SecItemAdd` method (adding a keychain item). For getting and deleting items, use `false`.
   
   - returns: the dictionary with kSecAttrSynchronizable item added if it was requested. Otherwise, it returns the original dictionary.
 
  */
  func addSynchronizableIfRequired(_ items: inout [String: Any], addingItems: Bool) {
    if !synchronizable { return }
    items[KeychainSwiftConstants.attrSynchronizable] = addingItems == true ? true : kSecAttrSynchronizableAny
  }
  
  @inlinable
  func throwIfFailed(_ status: OSStatus) throws {
    if status != noErr {
      throw KeychainError(status)
    }
  }
}

// MARK: - Async Wrappers

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension KeychainSwift {

  /**
   Asynchronously retrieves the text value from the keychain that corresponds to the given key.

   This dispatches the keychain read to a background thread, preventing the biometric/passcode
   system UI from blocking the main thread or the Swift concurrency cooperative thread pool.

   - parameter key: The key that is used to read the keychain item.
   - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode prompt.
   - returns: The text value from the keychain, or nil if the item was not found.
   - throws: `KeychainError.userCanceled` if the user dismisses the authentication prompt.
  */
  public func getAsync(_ key: String,
                     authenticationPrompt: String? = nil) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let value = try self.get(key, authenticationPrompt: authenticationPrompt)
          continuation.resume(returning: value)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /**
   Asynchronously retrieves data from the keychain that corresponds to the given key.

   This dispatches the keychain read to a background thread, preventing the biometric/passcode
   system UI from blocking the main thread or the Swift concurrency cooperative thread pool.

   - parameter key: The key that is used to read the keychain item.
   - parameter asReference: If true, returns the data as reference (needed for NEVPNProtocol).
   - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode prompt.
   - returns: The data from the keychain, or nil if the item was not found.
   - throws: `KeychainError.userCanceled` if the user dismisses the authentication prompt.
  */
  public func getDataAsync(_ key: String, asReference: Bool = false,
                         authenticationPrompt: String? = nil) async throws -> Data? {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let data = try self.getData(key, asReference: asReference,
                                      authenticationPrompt: authenticationPrompt)
          continuation.resume(returning: data)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /**
   Asynchronously retrieves a boolean value from the keychain that corresponds to the given key.

   This dispatches the keychain read to a background thread, preventing the biometric/passcode
   system UI from blocking the main thread or the Swift concurrency cooperative thread pool.

   - parameter key: The key that is used to read the keychain item.
   - parameter authenticationPrompt: Optional text displayed in the system biometric/passcode prompt.
   - returns: The boolean value from the keychain, or nil if the item was not found.
   - throws: `KeychainError.userCanceled` if the user dismisses the authentication prompt.
  */
  public func getBoolAsync(_ key: String,
                         authenticationPrompt: String? = nil) async throws -> Bool? {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let value = try self.getBool(key, authenticationPrompt: authenticationPrompt)
          continuation.resume(returning: value)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
