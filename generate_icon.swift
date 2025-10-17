#!/usr/bin/env swift

import Cocoa
import CoreGraphics

// Generate a colorful mosaic icon with dark background
// Represents the Tessera terminal tiling layout

func generateMosaicIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Dark background
    context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Colorful mosaic tiles representing terminal layout
    // Left column: 4 smaller tiles (30% width)
    // Right panel: 1 large tile (70% width)

    let padding = size * 0.08  // 8% padding around edges
    let gap = size * 0.02      // 2% gap between tiles
    let leftWidth = size * 0.28  // 28% for left tiles (30% minus gaps)
    let rightWidth = size * 0.62 // 62% for right tile (70% minus gaps)
    let totalHeight = size - (2 * padding)

    // Vibrant colors for tiles
    let colors: [CGColor] = [
        CGColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.9),   // Cyan
        CGColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.9),   // Pink
        CGColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.9),   // Green
        CGColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.9),   // Orange
        CGColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 0.9),   // Purple
    ]

    // Draw left column tiles (4 tiles)
    let leftTileHeight = (totalHeight - (3 * gap)) / 4.0
    for i in 0..<4 {
        let rect = CGRect(
            x: padding,
            y: padding + CGFloat(i) * (leftTileHeight + gap),
            width: leftWidth,
            height: leftTileHeight
        )

        // Draw tile with gradient and border
        context.saveGState()

        // Gradient fill
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [colors[i % colors.count], colors[i % colors.count].copy(alpha: 0.7)!] as CFArray,
            locations: [0.0, 1.0]
        )!

        let path = CGPath(roundedRect: rect, cornerWidth: size * 0.04, cornerHeight: size * 0.04, transform: nil)
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )

        context.restoreGState()

        // Border
        context.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.24, alpha: 1.0))
        context.setLineWidth(size * 0.01)
        context.addPath(path)
        context.strokePath()
    }

    // Draw right panel (1 large tile)
    let rightRect = CGRect(
        x: padding + leftWidth + gap,
        y: padding,
        width: rightWidth,
        height: totalHeight
    )

    context.saveGState()

    // Gradient fill for right panel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let rightGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [colors[4], colors[4].copy(alpha: 0.7)!] as CFArray,
        locations: [0.0, 1.0]
    )!

    let rightPath = CGPath(roundedRect: rightRect, cornerWidth: size * 0.04, cornerHeight: size * 0.04, transform: nil)
    context.addPath(rightPath)
    context.clip()
    context.drawLinearGradient(
        rightGradient,
        start: CGPoint(x: rightRect.minX, y: rightRect.maxY),
        end: CGPoint(x: rightRect.maxX, y: rightRect.minY),
        options: []
    )

    context.restoreGState()

    // Border for right panel
    context.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.24, alpha: 1.0))
    context.setLineWidth(size * 0.01)
    context.addPath(rightPath)
    context.strokePath()

    image.unlockFocus()
    return image
}

func saveAsIconSet(outputPath: String) {
    let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetPath = outputPath.replacingOccurrences(of: ".icns", with: ".iconset")

    // Create iconset directory
    try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    for size in sizes {
        let image = generateMosaicIcon(size: size)

        // Save standard resolution
        let filename = "icon_\(Int(size))x\(Int(size)).png"
        let filepath = "\(iconsetPath)/\(filename)"

        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: filepath))
            print("✓ Generated \(filename)")
        }

        // Save @2x resolution (except for 1024)
        if size < 1024 {
            let image2x = generateMosaicIcon(size: size * 2)
            let filename2x = "icon_\(Int(size))x\(Int(size))@2x.png"
            let filepath2x = "\(iconsetPath)/\(filename2x)"

            if let tiffData = image2x.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: filepath2x))
                print("✓ Generated \(filename2x)")
            }
        }
    }

    // Convert iconset to icns using iconutil
    print("\n🔨 Converting to .icns...")
    let task = Process()
    task.launchPath = "/usr/bin/iconutil"
    task.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
    task.launch()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        print("✅ Created \(outputPath)")

        // Clean up iconset directory
        try? FileManager.default.removeItem(atPath: iconsetPath)
    } else {
        print("❌ Failed to create .icns file")
    }
}

// Main execution
let outputPath = "sources/resources/AppIcon.icns"

// Create resources directory
try? FileManager.default.createDirectory(
    atPath: "sources/resources",
    withIntermediateDirectories: true
)

print("🎨 Generating Tessera icon...")
saveAsIconSet(outputPath: outputPath)
print("\n🎉 Icon generation complete!")
