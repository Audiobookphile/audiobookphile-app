//
//  WebAuthnManager.swift
//  Audiobookphile
//
//  Native WebAuthn passkey support (iOS only). Android/Skip builds exclude
//  this file's implementation entirely and degrade to PIN/TOTP fallbacks.
//

import Foundation

#if os(iOS) && !SKIP
import AuthenticationServices
import UIKit
#endif

public enum WebAuthnError: Error {
    case unsupportedPlatform
    case invalidChallenge
    case cancelled
    case assertionFailed
    case registrationFailed
    case controllerError(String)

    public var localizedDescription: String {
        switch self {
        case .unsupportedPlatform:
            return "Passkeys are not supported on this device. Use PIN Code or TOTP instead."
        case .invalidChallenge:
            return "The passkey challenge from the server was invalid."
        case .cancelled:
            return "Passkey authentication was cancelled."
        case .assertionFailed:
            return "Passkey verification failed. Try again."
        case .registrationFailed:
            return "Passkey registration failed."
        case .controllerError(let message):
            return message
        }
    }
}

// MARK: - Base64url codec (shared with API layer expectations)

public enum WebAuthnCodec {
    /// RFC 4648 base64url without padding.
    public static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes base64url (with or without padding).
    public static func base64urlDecode(_ string: String) -> Data? {
        var cleaned = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while cleaned.count % 4 != 0 {
            cleaned += "="
        }
        return Data(base64Encoded: cleaned)
    }
}

// MARK: - Results

public struct PasskeyAssertion: Sendable {
    public let credentialId: String
    public let clientDataJSON: String
    public let authenticatorData: String
    public let signature: String
}

public struct PasskeyRegistration: Sendable {
    public let id: String
    public let clientDataJSON: String
    public let attestationObject: String
}

/// Registration options resolved from the server's WebAuthn register/options payload.
public struct PasskeyRegistrationRequest {
    public let challenge: Data
    public let rpId: String
    public let rpName: String
    public let userID: Data
    public let userName: String
    public let displayName: String
    public let excludeCredentialIds: [Data]
    public let userVerification: String

    public init(
        challenge: Data,
        rpId: String,
        rpName: String,
        userID: Data,
        userName: String,
        displayName: String,
        excludeCredentialIds: [Data] = [],
        userVerification: String = "preferred"
    ) {
        self.challenge = challenge
        self.rpId = rpId
        self.rpName = rpName
        self.userID = userID
        self.userName = userName
        self.displayName = displayName
        self.excludeCredentialIds = excludeCredentialIds
        self.userVerification = userVerification
    }
}

// MARK: - Platform wrapper

#if os(iOS) && !SKIP
public enum WebAuthnManager {
    /// Performs a platform passkey (Face ID / Touch ID / iCloud Keychain) assertion.
    @MainActor
    public static func requestAssertion(
        challenge: Data,
        rpId: String,
        allowCredentials: [WebAuthnAllowedCredential],
        userVerification: String = "preferred"
    ) async throws -> PasskeyAssertion {
#if compiler(>=6.0)
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
#else
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(rpID: rpId)
#endif

        let request = provider.createCredentialAssertionRequest(challenge: challenge)

#if compiler(>=6.0)
        let verification: ASAuthorizationPublicKeyCredentialUserVerificationPreference
        switch userVerification {
        case "required": verification = .required
        case "discouraged": verification = .discouraged
        default: verification = .preferred
        }
        request.userVerificationPreference = verification
#else
        let verification: ASCredentialRequestUserVerification
        switch userVerification {
        case "required": verification = .required
        case "discouraged": verification = .discouraged
        default: verification = .preferred
        }
        request.userVerification = verification
#endif

        if !allowCredentials.isEmpty {
#if compiler(>=6.0)
            request.allowedCredentials = allowCredentials.map { credential in
                guard let idData = WebAuthnCodec.base64urlDecode(credential.id) else {
                    return nil
                }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: idData)
            }.compactMap { $0 }
#else
            request.allowedCredentialDescriptors = allowCredentials.map { credential in
                guard let idData = WebAuthnCodec.base64urlDecode(credential.id) else {
                    return nil
                }
                let transports = (credential.transports ?? []).compactMap {
                    ASCredentialTransport.transport(from: $0)
                }
                return ASPublicKeyCredentialDescriptor(
                    credentialID: idData,
                    transports: transports
                )
            }.compactMap { $0 }
#endif
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        return try await perform(controller)
    }

    /// Creates a new platform passkey (Face ID / Touch ID / iCloud Keychain).
    @MainActor
    public static func requestRegistration(
        request: PasskeyRegistrationRequest
    ) async throws -> PasskeyRegistration {
#if compiler(>=6.0)
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId)
#else
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(rpID: request.rpId)
#endif

        let registrationRequest = provider.createCredentialRegistrationRequest(
            challenge: request.challenge,
            name: request.userName,
            userID: request.userID
        )
        registrationRequest.displayName = request.displayName
#if compiler(>=6.0)
        registrationRequest.attestationPreference = ASAuthorizationPublicKeyCredentialAttestationKind.none

        let verification: ASAuthorizationPublicKeyCredentialUserVerificationPreference
        switch request.userVerification {
        case "required": verification = .required
        case "discouraged": verification = .discouraged
        default: verification = .preferred
        }
        registrationRequest.userVerificationPreference = verification
#else
        registrationRequest.attestationPreference = .none

        let verification: ASCredentialRegistrationUserVerification
        switch request.userVerification {
        case "required": verification = .required
        case "discouraged": verification = .discouraged
        default: verification = .preferred
        }
        registrationRequest.userVerification = verification
#endif

        if !request.excludeCredentialIds.isEmpty {
#if compiler(>=6.0)
            if #available(iOS 17.4, *) {
                registrationRequest.excludedCredentials = request.excludeCredentialIds.map {
                    ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
                }
            }
#else
            registrationRequest.excludedCredentialDescriptors = request.excludeCredentialIds.map {
                ASPublicKeyCredentialDescriptor(credentialID: $0, transports: [])
            }
#endif
        }

        let controller = ASAuthorizationController(authorizationRequests: [registrationRequest])
        return try await perform(controller)
    }

    // MARK: - Async bridge

    @MainActor
    private static func perform(_ controller: ASAuthorizationController) async throws -> PasskeyAssertion {
        let bridge = PasskeyAssertionBridge()
        controller.delegate = bridge
        controller.presentationContextProvider = bridge
        controller.performRequests()
        return try await bridge.result()
    }

    @MainActor
    private static func perform(_ controller: ASAuthorizationController) async throws -> PasskeyRegistration {
        let bridge = PasskeyRegistrationBridge()
        controller.delegate = bridge
        controller.presentationContextProvider = bridge
        controller.performRequests()
        return try await bridge.result()
    }
}

@MainActor
private final class PasskeyAssertionBridge: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<PasskeyAssertion, Error>?

    func result() async throws -> PasskeyAssertion {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let platformAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            continuation?.resume(throwing: WebAuthnError.assertionFailed)
            continuation = nil
            return
        }
        let result = PasskeyAssertion(
            credentialId: WebAuthnCodec.base64urlEncode(platformAssertion.credentialID),
            clientDataJSON: WebAuthnCodec.base64urlEncode(platformAssertion.rawClientDataJSON),
            authenticatorData: WebAuthnCodec.base64urlEncode(platformAssertion.rawAuthenticatorData),
            signature: WebAuthnCodec.base64urlEncode(platformAssertion.signature)
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           ASAuthorizationError.Code(rawValue: nsError.code) == .canceled {
            continuation?.resume(throwing: WebAuthnError.cancelled)
        } else {
            continuation?.resume(throwing: WebAuthnError.controllerError(error.localizedDescription))
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        keyWindow() ?? ASPresentationAnchor()
    }
}

@MainActor
private final class PasskeyRegistrationBridge: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<PasskeyRegistration, Error>?

    func result() async throws -> PasskeyRegistration {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let platformRegistration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
              let rawAttestationObject = platformRegistration.rawAttestationObject else {
            continuation?.resume(throwing: WebAuthnError.registrationFailed)
            continuation = nil
            return
        }
        let result = PasskeyRegistration(
            id: WebAuthnCodec.base64urlEncode(platformRegistration.credentialID),
            clientDataJSON: WebAuthnCodec.base64urlEncode(platformRegistration.rawClientDataJSON),
            attestationObject: WebAuthnCodec.base64urlEncode(rawAttestationObject)
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           ASAuthorizationError.Code(rawValue: nsError.code) == .canceled {
            continuation?.resume(throwing: WebAuthnError.cancelled)
        } else {
            continuation?.resume(throwing: WebAuthnError.controllerError(error.localizedDescription))
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        keyWindow() ?? ASPresentationAnchor()
    }
}

@MainActor
private func keyWindow() -> UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for window in windowScene.windows where window.isKeyWindow {
            return window
        }
    }
    return nil
}

#if compiler(>=6.0)
// The iOS 26.4+ SDK removed ASCredentialTransport and platform credential
// descriptors no longer carry transport lists (platform passkeys are fixed).
#else
private extension ASCredentialTransport {
    static func transport(from value: String) -> ASCredentialTransport? {
        switch value {
        case "internal": return .internal
        case "usb": return .usb
        case "nfc": return .nfc
        case "ble": return .ble
        case "hybrid": return .hybrid
        default: return nil
        }
    }
}
#endif
#endif
