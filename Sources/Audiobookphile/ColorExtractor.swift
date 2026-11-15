//
//  ColorExtractor.swift
//  Audiobookphile
//
//  Extract dominant color from book cover images.
//  Critical for Liquid Glass dynamic theming.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) || SKIP
import UIKit
import CoreImage

/// Extracts dominant colors from images for dynamic theming
@MainActor
public class ColorExtractor {
    public static let shared = ColorExtractor()

    private let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
    private var colorCache = NSCache<NSString, UIColor>()

    /// Extract average color from a UIImage
    public func extractColor(from image: UIImage) -> UIColor? {
        guard let inputImage = CIImage(image: image) else { return nil }

        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: extentVector
            ]
        ) else { return nil }

        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1.0
        )
    }

    /// Extract color with caching
    public func extractColor(from url: URL) async -> UIColor {
        let cacheKey = url.absoluteString as NSString

        if let cached = colorCache.object(forKey: cacheKey) {
            return cached
        }

        // Reuse an already-decoded bitmap when the player has one; otherwise
        // fetch a tiny downsample — a 1px average needs nowhere near the
        // provider's full resolution.
        #if os(iOS)
        var uiImage = await MainActor.run {
            ImageMemoryCache.shared.cachedImage(for: url)
        }
        if uiImage == nil, let (data, _) = try? await URLSession.shared.data(from: url) {
            uiImage = await Task.detached(priority: .utility) {
                downsampledImage(data: data, maxPixelSize: 64) ?? UIImage(data: data)
            }.value
        }
        if let uiImage, let color = extractColor(from: uiImage) {
            colorCache.setObject(color, forKey: cacheKey)
            return color
        }
        #else
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data),
           let color = extractColor(from: image) {
            colorCache.setObject(color, forKey: cacheKey)
            return color
        }
        #endif

        return UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0) // Default dark gray
    }

    /// Check if a color is considered "light" (for text color contrast)
    public func isLight(_ color: UIColor) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Using perceived brightness formula
        let brightness = (red * 299 + green * 587 + blue * 114) / 1000
        return brightness > 0.5
    }

    /// Get contrasting text color for a background
    public func contrastingTextColor(for backgroundColor: UIColor) -> Color {
        return isLight(backgroundColor) ? DesignTokens.Color.foreground : DesignTokens.Color.background
    }

    /// Generate gradient colors from a base color
    public func generateGradient(from baseColor: UIColor) -> [Color] {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Create a gradient that darkens toward the bottom
        let topColor = UIColor(
            hue: hue,
            saturation: saturation * 0.8,
            brightness: min(1.0, brightness * 1.1),
            // Reduce alpha a bit for smooth mixing
            alpha: 1.0
        )
        let bottomColor = UIColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness * 0.3,
            alpha: 1.0
        )

        return [Color(topColor), Color(bottomColor)]
    }
}

// MARK: - SwiftUI Integration

/// Observable wrapper for async color extraction
@Observable
@MainActor
public class DynamicColorLoader {
    public var backgroundColor: Color = Color(red: 0.22, green: 0.22, blue: 0.22)
    public var textColor: Color = DesignTokens.Color.foreground
    public var gradientColors: [Color] = [DesignTokens.Color.accent, DesignTokens.Color.accentSecondary]
    public var isLoaded = false
    public var isLight = false

    private let extractor = ColorExtractor.shared

    public init() {}

    public func loadColor(from url: URL?) async {
        guard let url = url else { return }

        let uiColor = await extractor.extractColor(from: url)

        backgroundColor = Color(uiColor)
        textColor = extractor.contrastingTextColor(for: uiColor)
        gradientColors = extractor.generateGradient(from: uiColor)
        isLight = extractor.isLight(uiColor)
        isLoaded = true
    }

    public func loadColor(from image: UIImage) {
        guard let uiColor = extractor.extractColor(from: image) else { return }

        backgroundColor = Color(uiColor)
        textColor = extractor.contrastingTextColor(for: uiColor)
        gradientColors = extractor.generateGradient(from: uiColor)
        isLight = extractor.isLight(uiColor)
        isLoaded = true
    }

    /// Map AI-detected mood strings to atmospheric dynamic ambient lighting palettes
    public func loadColor(fromMood mood: String) {
        let lower = mood.lowercased()
        let primary: Color
        let secondary: Color

        if lower.contains("mysterious") || lower.contains("dark") || lower.contains("suspense") || lower.contains("thriller") {
            primary = DesignTokens.Color.accent
            secondary = DesignTokens.Color.accentSecondary
        } else if lower.contains("inspir") || lower.contains("growth") || lower.contains("warm") || lower.contains("hope") {
            primary = Color(red: 0.35, green: 0.22, blue: 0.05) // Golden Amber
            secondary = Color(red: 0.18, green: 0.10, blue: 0.02)
        } else if lower.contains("sci-fi") || lower.contains("space") || lower.contains("future") || lower.contains("tech") {
            primary = Color(red: 0.04, green: 0.25, blue: 0.32) // Deep Cyan
            secondary = Color(red: 0.02, green: 0.12, blue: 0.16)
        } else if lower.contains("energetic") || lower.contains("action") || lower.contains("dramatic") {
            primary = Color(red: 0.32, green: 0.06, blue: 0.08) // Deep Crimson
            secondary = Color(red: 0.16, green: 0.03, blue: 0.04)
        } else if lower.contains("melancholic") || lower.contains("reflect") || lower.contains("philosoph") {
            primary = Color(red: 0.12, green: 0.18, blue: 0.26) // Slate Midnight
            secondary = Color(red: 0.06, green: 0.09, blue: 0.14)
        } else {
            primary = Color(red: 0.18, green: 0.18, blue: 0.22)
            secondary = Color(red: 0.09, green: 0.09, blue: 0.12)
        }

        backgroundColor = primary
        gradientColors = [primary, secondary]
        textColor = extractor.contrastingTextColor(for: UIColor(primary))
        isLight = false
        isLoaded = true
    }
}
#else
// Mock stub for non-iOS/non-Skip platforms (like macOS compiler tests under SPM)
import Observation

@MainActor
public class ColorExtractor {
    public static let shared = ColorExtractor()
    public init() {}
    public func contrastingTextColor(for backgroundColor: Color) -> Color { DesignTokens.Color.foreground }
    public func generateGradient(from baseColor: Color) -> [Color] { [DesignTokens.Color.accent, DesignTokens.Color.accentSecondary] }
}

@Observable
@MainActor
public class DynamicColorLoader {
    public var backgroundColor: Color = Color(red: 0.22, green: 0.22, blue: 0.22)
    public var textColor: Color = DesignTokens.Color.foreground
    public var gradientColors: [Color] = [DesignTokens.Color.accent, DesignTokens.Color.accentSecondary]
    public var isLoaded = false
    public var isLight = false

    public init() {}

    public func loadColor(from url: URL?) async {
        isLoaded = true
    }

    // Stub to avoid compilation issues in macOS
    #if canImport(AppKit)
    public func loadColor(from image: NSImage) {
        isLoaded = true
    }
    #endif

    public func loadColor(fromMood mood: String) {
        let lower = mood.lowercased()
        if lower.contains("mysterious") || lower.contains("dark") || lower.contains("suspense") || lower.contains("thriller") {
            backgroundColor = Color(red: 0.22, green: 0.08, blue: 0.35)
        } else if lower.contains("sci-fi") || lower.contains("space") {
            backgroundColor = Color(red: 0.04, green: 0.25, blue: 0.32)
        } else {
            backgroundColor = Color(red: 0.18, green: 0.18, blue: 0.22)
        }
        isLoaded = true
    }
}
#endif
