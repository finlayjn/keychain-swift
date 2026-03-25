import Foundation
import Security

/// Constants used by the library
public struct KeychainSwiftConstants {
  /// Specifies a Keychain access group. Used for sharing Keychain items between apps.
  public static var accessGroup: String { return toString(kSecAttrAccessGroup) }
  
  /**
   
   A value that indicates when your app needs access to the data in a keychain item. The default value is AccessibleWhenUnlocked. For a list of possible values, see KeychainSwiftAccessOptions.
   
   */
  public static var accessible: String { return toString(kSecAttrAccessible) }
  
  /// Used for specifying a String key when setting/getting a Keychain value.
  public static var attrAccount: String { return toString(kSecAttrAccount) }

  /// Used for specifying synchronization of keychain items between devices.
  public static var attrSynchronizable: String { return toString(kSecAttrSynchronizable) }
  
  /// An item class key used to construct a Keychain search dictionary.
  public static var klass: String { return toString(kSecClass) }
  
  /// Specifies the number of values returned from the keychain. The library only supports single values.
  public static var matchLimit: String { return toString(kSecMatchLimit) }
  
  /// A return data type used to get the data from the Keychain.
  public static var returnData: String { return toString(kSecReturnData) }
  
  /// Used for specifying a value when setting a Keychain value.
  public static var valueData: String { return toString(kSecValueData) }
    
  /// Used for returning a reference to the data from the keychain
  public static var returnReference: String { return toString(kSecReturnPersistentRef) }
  
  /// A key whose value is a Boolean indicating whether or not to return item attributes
  public static var returnAttributes : String { return toString(kSecReturnAttributes) }
    
  /// A value that corresponds to matching an unlimited number of items
  public static var secMatchLimitAll : String { return toString(kSecMatchLimitAll) }

  // MARK: - Access Control

  /// Specifies a `SecAccessControl` object that governs access to the keychain item,
  /// including biometric, passcode, or user presence requirements.
  /// Mutually exclusive with `accessible` (`kSecAttrAccessible`).
  public static var accessControl: String { return toString(kSecAttrAccessControl) }

  /// A string displayed in the system authentication prompt (Face ID / Touch ID / passcode)
  /// when reading an access-controlled keychain item. Pass this in the query dictionary
  /// to customize the reason shown to the user.
  public static var useOperationPrompt: String { return toString(kSecUseOperationPrompt) }

  /// An `LAContext` object used to authenticate access to keychain items.
  /// Passing a pre-authenticated `LAContext` allows reusing a single authentication
  /// for multiple keychain reads within the context's validity window, avoiding
  /// repeated biometric prompts.
  public static var useAuthenticationContext: String { return toString(kSecUseAuthenticationContext) }

  static func toString(_ value: CFString) -> String {
    return value as String
  }
}


