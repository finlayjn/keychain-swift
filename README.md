# Helper functions for storing text in Keychain for iOS, macOS, tvOS and WatchOS

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods Version](https://img.shields.io/cocoapods/v/KeychainSwift.svg?style=flat)](http://cocoadocs.org/docsets/KeychainSwift)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/cocoapods/l/KeychainSwift.svg?style=flat)](http://cocoadocs.org/docsets/KeychainSwift)
[![Platform](https://img.shields.io/cocoapods/p/KeychainSwift.svg?style=flat)](http://cocoadocs.org/docsets/KeychainSwift)

This is a collection of helper functions for saving text and data in the Keychain.
 As you probably noticed Apple's keychain API is a bit verbose. This library was designed to provide shorter syntax for accomplishing a simple task: reading/writing text values for specified keys:

 ```Swift
let keychain = KeychainSwift()
try keychain.set("hello world", forKey: "my key")
let value = try keychain.get("my key")
 ```

The Keychain library includes the following features:

 * <a href="#usage">Get, set and delete string, boolean and Data Keychain items</a>
 * <a href="#keychain_item_access">Specify item access security level</a>
 * <a href="#keychain_access_control">Restrict access with biometrics (Face ID / Touch ID) or passcode</a>
 * <a href="#keychain_synchronization">Synchronize items through iCloud</a>
 * <a href="#keychain_access_groups">Share Keychain items with other apps</a>

## Fork Changes

This fork adds two key enhancements to the original keychain-swift library:

**Biometric & Passcode Access Control** — Store keychain items that require Face ID, Touch ID, or device passcode to read. Built on Apple's `SecAccessControl` APIs with five ready-to-use presets (`.biometricCurrentSet()`, `.biometricAny()`, `.biometricOrPasscode()`, `.devicePasscode()`, `.userPresence()`) and support for custom flag combinations. Includes `authenticationPrompt` and `LAContext` reuse on reads, plus `async` wrappers to keep biometric prompts off the main thread.

**Thread Safety & Sendable** — `KeychainSwift` conforms to `@unchecked Sendable` and `KeychainSwiftAccessControl` conforms to `Sendable`, making the library safe to use with Swift 6 strict concurrency checking.

### Breaking API Changes

This fork contains breaking changes from the upstream library. If you are migrating from the original keychain-swift, you will need to update your call sites:

- **`set`, `get`, `getData`, `getBool`, `delete`, `clear` now `throw`** instead of returning `Bool` or silently failing. Wrap calls in `try` / `try?` / `do-catch`.
- **`accessGroup` and `synchronizable` are now read-only properties**, set via `KeychainSwift(keyPrefix:accessGroup:synchronizable:)` at init time instead of being mutable.
- **`lastResultCode` has been removed.** Errors are now surfaced as thrown `KeychainError` values with the `OSStatus` available via `.rawValue`.

## What's Keychain?

Keychain is a secure storage. You can store all kind of sensitive data in it: user passwords, credit card numbers, secret tokens etc. Once stored in Keychain this information is only available to your app, other apps can't see it. Besides that, operating system makes sure this information is kept and processed securely. For example, text stored in Keychain can not be extracted from iPhone backup or from its file system. Apple recommends storing only small amount of data in the Keychain. If you need to secure something big you can encrypt it manually, save to a file and store the key in the Keychain.


## Setup

There are four ways you can add KeychainSwift to your project.

#### Add source (iOS 7+)

Simply add [KeychainSwiftDistrib.swift](https://github.com/finlayjn/keychain-swift/blob/master/Distrib/KeychainSwiftDistrib.swift) file into your Xcode project.

#### Setup with Carthage (iOS 8+)

Alternatively, add `github "finlayjn/keychain-swift" ~> 25.0` to your Cartfile and run `carthage update`.

#### Setup with CocoaPods (iOS 8+)

If you are using CocoaPods add this text to your Podfile and run `pod install`.

```
use_frameworks!
target 'Your target name'
pod 'KeychainSwift', '~> 25.0'
```


#### Setup with Swift Package Manager (in project)

* In Xcode select *File > Add Packages*.
* Enter this project's URL: https://github.com/finlayjn/keychain-swift.git

#### Setup with Swift Package Manager (in Swift Package)

If you're using KeychainSwift in a Swift package, make sure to specify a `name`. This is because SPM cannot automatically resolve a name for a package that has a different Target name in its `Package.swift` (namely `KeychainSwift`) that differs from the repo link (`keychain-swift`).

```
.package(name: "KeychainSwift", url: "https://github.com/finlayjn/keychain-swift.git", from: "25.0.0")
```

## Legacy Swift versions

Setup a [previous version](https://github.com/evgenyneu/keychain-swift/wiki/Legacy-Swift-versions) of the library if you use an older version of Swift.


## Usage

Add `import KeychainSwift` to your source code unless you used the file setup method.

#### String values

```Swift
let keychain = KeychainSwift()
try keychain.set("hello world", forKey: "my key")
let value = try keychain.get("my key")
```

#### Boolean values


```Swift
let keychain = KeychainSwift()
try keychain.set(true, forKey: "my key")
let flag = try keychain.getBool("my key")
```

#### Data values

```Swift
let keychain = KeychainSwift()
try keychain.set(dataObject, forKey: "my key")
let data = try keychain.getData("my key")
```

#### Removing keys from Keychain

```Swift
try keychain.delete("my key") // Remove single key
try keychain.clear() // Delete everything from app's Keychain. Does not work on macOS.
```

#### Return all keys

```Swift
let keychain = KeychainSwift()
keychain.allKeys // Returns the names of all keys
```

## Advanced options

<h3 id="keychain_item_access">Keychain item access</h3>

Use `withAccess` parameter to specify the security level of the keychain storage.
By default the `.accessibleWhenUnlocked` option is used. It is one of the most restrictive options and provides good data protection.

```Swift
let keychain = KeychainSwift()
try keychain.set("Hello world", forKey: "key 1", withAccess: .accessibleWhenUnlocked)
```

You can use `.accessibleAfterFirstUnlock` if you need your app to access the keychain item while in the background. Note that it is less secure than the `.accessibleWhenUnlocked` option.

See the list of all available [access options](https://github.com/finlayjn/keychain-swift/blob/master/Sources/KeychainSwiftAccessOptions.swift).


<h3 id="keychain_access_control">Restricting access with biometrics or passcode</h3>

Use `withAccessControl` parameter to require user authentication (Face ID, Touch ID, or device passcode) before a keychain item can be read. This provides an additional layer of security beyond device lock state — even if the device is unlocked, the user must authenticate to access the item.

```Swift
let keychain = KeychainSwift()

// Require biometric (Face ID / Touch ID) — invalidated if biometric enrollment changes
try keychain.set("secret", forKey: "my key",
                 withAccessControl: .biometricCurrentSet())

// Require biometric — survives biometric enrollment changes
try keychain.set("secret", forKey: "my key",
                 withAccessControl: .biometricAny())

// Biometric preferred, device passcode as fallback
try keychain.set("secret", forKey: "my key",
                 withAccessControl: .biometricOrPasscode())

// Device passcode only
try keychain.set("secret", forKey: "my key",
                 withAccessControl: .devicePasscode())

// Let the system decide (biometric or passcode)
try keychain.set("secret", forKey: "my key",
                 withAccessControl: .userPresence())
```

You can customize the base accessibility level for any preset:

```Swift
let accessControl = KeychainSwiftAccessControl.biometricCurrentSet(
    accessibility: .accessibleWhenUnlockedThisDeviceOnly
)
try keychain.set("secret", forKey: "my key", withAccessControl: accessControl)
```

Or create a fully custom access control configuration:

```Swift
let accessControl = KeychainSwiftAccessControl(
    accessibility: .accessibleWhenPasscodeSetThisDeviceOnly,
    flags: [.biometryCurrentSet, .or, .devicePasscode]
)
try keychain.set("secret", forKey: "my key", withAccessControl: accessControl)
```

#### Reading access-controlled items

When reading an access-controlled item, the system automatically presents a biometric/passcode prompt. You can provide a prompt message:

```Swift
let value = try keychain.get("my key", authenticationPrompt: "Verify to access your account")
```

**Important:** The biometric prompt blocks the calling thread. Always call `get`/`getData`/`getBool` from a background thread when reading access-controlled items. Use the async variants for convenience:

```Swift
let value = try await keychain.getAsync("my key", authenticationPrompt: "Verify identity")
let data = try await keychain.getDataAsync("my key", authenticationPrompt: "Verify identity")
let flag = try await keychain.getBoolAsync("my key", authenticationPrompt: "Verify identity")
```

#### Reusing authentication with LAContext

To avoid repeated biometric prompts when reading multiple items, pass a pre-authenticated `LAContext`:

```Swift
import LocalAuthentication

let context = LAContext()
context.localizedReason = "Access your accounts"

// Authenticate once
var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }

context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Access your accounts") { success, _ in
    guard success else { return }
    // Reuse the authenticated context for multiple reads
    let token1 = try? keychain.getData("account1", authenticationContext: context)
    let token2 = try? keychain.getData("account2", authenticationContext: context)
}
```

#### Handling authentication errors

```Swift
do {
    let value = try keychain.get("my key", authenticationPrompt: "Verify identity")
} catch let error as KeychainError where error == .userCanceled {
    // User dismissed the biometric prompt
} catch let error as KeychainError where error == .authFailed {
    // Authentication failed (e.g., biometric enrollment changed for .biometryCurrentSet)
} catch let error as KeychainError where error == .interactionNotAllowed {
    // Cannot show authentication UI (e.g., app is in the background)
}
```

#### Important notes on access control

- **`withAccess` and `withAccessControl` are mutually exclusive.** Do not pass both — the accessibility level is embedded in the access control configuration.
- **Access-controlled items cannot be synchronized.** Using `synchronizable = true` with `withAccessControl` will throw an error.
- **Biometric invalidation:** Use `.biometricCurrentSet()` if you want items to become permanently inaccessible when the user adds or removes a fingerprint/face. This protects against a malicious actor adding their own biometric.
- **Simulator limitations:** Biometric-protected keychain items may not work in the iOS Simulator (no Secure Enclave). Test on a physical device for biometric-specific access controls.
- **`NSFaceIDUsageDescription`:** Apps using Face ID must include the `NSFaceIDUsageDescription` key in their `Info.plist` with a description of why the app uses Face ID.


<h3 id="keychain_synchronization">Synchronizing keychain items with other devices</h3>

Pass `synchronizable: true` when initializing `KeychainSwift` to enable keychain items synchronization across user's multiple devices. The synchronization will work for users who have the "Keychain" enabled in the iCloud settings on their devices.

Synchronizable items will be added to other devices with the `set` method and obtained with the `get` command. Deleting a synchronizable item will remove it from all devices.

Note that you do NOT need to enable iCloud or Keychain Sharing capabilities in your app's target for this feature to work.


```Swift
// First device
let keychain = KeychainSwift(synchronizable: true)
try keychain.set("hello world", forKey: "my key")

// Second device
let keychain = KeychainSwift(synchronizable: true)
let value = try keychain.get("my key") // Returns "hello world"
```

We could not get the Keychain synchronization work on macOS.


<h3 id="keychain_access_groups">Sharing keychain items with other apps</h3>

In order to share keychain items between apps on the same device they need to have common *Keychain Groups* registered in *Capabilities > Keychain Sharing* settings. [This tutorial](http://evgenii.com/blog/sharing-keychain-in-ios/) shows how to set it up.

Pass an `accessGroup` when initializing `KeychainSwift` to access shared keychain items. In the following example we specify an access group "CS671JRA62.com.myapp.KeychainGroup" that will be used to set, get and delete an item "my key".

```Swift
let keychain = KeychainSwift(accessGroup: "CS671JRA62.com.myapp.KeychainGroup")

try keychain.set("hello world", forKey: "my key")
let value = try keychain.get("my key")
try keychain.delete("my key")
try keychain.clear()
```

*Note*: there is no way of sharing a keychain item between the watchOS 2.0 and its paired device: https://forums.developer.apple.com/thread/5938

### Setting key prefix

One can pass a `keyPrefix` argument when initializing a `KeychainSwift` object. The string passed in `keyPrefix` argument will be used as a prefix to **all the keys** used in `set`, `get`, `getData` and `delete` methods. Adding a prefix to the keychain keys can be useful in unit tests. This prevents the tests from changing the Keychain keys that are used when the app is launched manually.

Note that `clear` method still clears everything from the Keychain regardless of the prefix used.


```Swift
let keychain = KeychainSwift(keyPrefix: "myTestKey_")
try keychain.set("hello world", forKey: "hello")
// Value will be stored under "myTestKey_hello" key
```

### Error handling

All mutating methods (`set`, `delete`, `clear`) and reading methods (`get`, `getData`, `getBool`) throw a `KeychainError` on failure. Use `do-catch` to handle errors, or `try?` to ignore them:

```Swift
do {
  try keychain.set("hello world", forKey: "my key")
} catch let error as KeychainError {
  print("Keychain error: \(error.localizedDescription) (OSStatus: \(error.rawValue))")
}
```

See [Keychain Result Codes](https://developer.apple.com/documentation/security/1542001-security_framework_result_codes) for possible `rawValue` values.

### Returning data as reference

Use the `asReference: true` parameter to return the data as reference, which is needed for  [NEVPNProtocol](https://developer.apple.com/documentation/networkextension/nevpnprotocol).

```Swift
let keychain = KeychainSwift()
try keychain.set(dataObject, forKey: "my key")
let data = try keychain.getData("my key", asReference: true)
```

## Using KeychainSwift from Objective-C

[This manual](https://github.com/evgenyneu/keychain-swift/wiki/Using-KeychainSwift-in-Objective-C-project) describes how to use KeychainSwift in Objective-C apps.

## ❗️Known critical issue - call to action❗️

It [has been reported](https://github.com/evgenyneu/keychain-swift/issues/15) that the library sometimes returns `nil`  instead of the stored Keychain value. It may be connected with [the Keychain issue](https://forums.developer.apple.com/thread/4743) reported on Apple developer forums. The issue is random and hard to reproduce. If you experienced this problem feel free to create an issue and share your story, so we can find solutions.

## Video tutorial

Thanks to Alex Nagy from [rebeloper.com](https://rebeloper.com/) for creating this two-part [video tutorial](https://www.youtube.com/watch?v=1R-VIzjD4yo&list=PL_csAAO9PQ8bLfPF7JsnF-t4q63WKZ9O9).

<a href="https://www.youtube.com/watch?v=1R-VIzjD4yo&list=PL_csAAO9PQ8bLfPF7JsnF-t4q63WKZ9O9" target="_blank"><img src='graphics/keychain_swift_video_tutorial.jpg' width='800' alt='Keychain Swift video tutorial'></a>

## Demo app

<img src="https://raw.githubusercontent.com/finlayjn/keychain-swift/master/graphics/keychain-swift-demo-3.png" alt="Keychain Swift demo app" width="320">

## Alternative solutions

Here are some other Keychain libraries.

* [DanielTomlinson/Latch](https://github.com/DanielTomlinson/Latch)
* [jrendel/SwiftKeychainWrapper](https://github.com/jrendel/SwiftKeychainWrapper)
* [kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)
* [matthewpalmer/Locksmith](https://github.com/matthewpalmer/Locksmith)
* [s-aska/KeyClip](https://github.com/s-aska/KeyClip)
* [yankodimitrov/SwiftKeychain](https://github.com/yankodimitrov/SwiftKeychain)

## Thanks 👍

* The code is based on this example: [https://gist.github.com/s-aska/e7ad24175fb7b04f78e7](https://gist.github.com/s-aska/e7ad24175fb7b04f78e7)
* Thanks to [diogoguimaraes](https://github.com/diogoguimaraes) for adding Swift Package Manager setup option.
* Thanks to [glyuck](https://github.com/glyuck) for taming booleans.
* Thanks to [pepibumur](https://github.com/pepibumur) for adding macOS, watchOS and tvOS support.
* Thanks to [ezura](https://github.com/ezura) for iOS 7 support.
* Thanks to [mikaoj](https://github.com/mikaoj) for adding keychain synchronization.
* Thanks to [tcirwin](https://github.com/tcirwin) for adding Swift 3.0 support.
* Thanks to [Tulleb](https://github.com/Tulleb) for adding Xcode 8 beta 6 support.
* Thanks to [CraigSiemens](https://github.com/CraigSiemens) for adding Swift 3.1 support.
* Thanks to [maxkramerbcgdv](https://github.com/maxkramerbcgdv) for fixing Package Manager setup in Xcode 8.2.
* Thanks to [elikohen](https://github.com/elikohen) for fixing concurrency issues.
* Thanks to [beny](https://github.com/beny) for adding Swift 4.2 support.
* Thanks to [xuaninbox](https://github.com/xuaninbox) for fixing watchOS deployment target for Xcode 10.
* Thanks to [schayes04](https://github.com/schayes04) for adding Swift 5.0 support.
* Thanks to [mediym41](https://github.com/mediym41) for adding ability to return data as reference.
* Thanks to [AnthonyOliveri](https://github.com/AnthonyOliveri) for adding ability to run unit tests from Swift Package Manager.
* Thanks to [philippec](https://github.com/philippec) for removing deprecated access options.
* Thanks to [lucasmpaim](https://github.com/lucasmpaim) for adding ability to return the names of all keys.



## Feedback is welcome

If you notice any issue, got stuck or just want to chat feel free to create an issue. We will be happy to help you.

## AI Disclosure

Development of the biometric access control feature in this fork was assisted by Claude Opus 4.6 (Anthropic), used via GitHub Copilot.

## License

Keychain Swift is released under the [MIT License](LICENSE).
