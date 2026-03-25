//
//  KeychainError.swift
//  KeychainSwift
//
//  Created by Lennard Sprong on 20/02/2025.
//

import Foundation
import Security

public struct KeychainError : RawRepresentable, CustomStringConvertible {
    public init(rawValue: OSStatus) {
        self.rawValue = rawValue
    }
    
    public init(_ code: OSStatus) {
        rawValue = code
    }
    
    /// The result code for the operation.
    public let rawValue: OSStatus
    
    /// Retrieve the localized description for this error. This uses ``/Security/SecCopyErrorMessageString(_:_:)`` internally.
    public var localizedDescription: String {
        if let message = SecCopyErrorMessageString(rawValue, nil) {
            return message as String
        }
        return description
    }
    
    public var description: String {
        "KeychainError(\(rawValue))"
    }
}

extension KeychainError : Equatable {}

extension KeychainError : CustomNSError {
    public static var errorDomain: String { NSOSStatusErrorDomain }
}

extension KeychainError : LocalizedError {
    public var errorDescription: String? { localizedDescription }
}

// MARK: - Authentication Error Constants

extension KeychainError {
    /// The user canceled the authentication prompt (e.g., dismissed Face ID / Touch ID dialog).
    /// Check for this error to handle the case where the user explicitly declines to authenticate.
    public static var userCanceled: KeychainError { KeychainError(errSecUserCanceled) }

    /// Authentication failed (e.g., biometric verification failed after too many attempts,
    /// or the biometric enrollment has changed for an item protected with `.biometryCurrentSet`).
    public static var authFailed: KeychainError { KeychainError(errSecAuthFailed) }

    /// Interaction with the user is required to access the item, but is not allowed in the
    /// current context. This typically occurs when trying to read an access-controlled item
    /// while the app is in the background, or when the device is locked.
    public static var interactionNotAllowed: KeychainError { KeychainError(errSecInteractionNotAllowed) }
}
