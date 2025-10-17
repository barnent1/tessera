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

    // Dark background with border
    context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Laser-cut mosaic with violet lines
    // Left column: 4 smaller tiles (30% width)
    // Right panel: 1 large tile (70% width)

    let borderPadding = size * 0.10     // 10% border around entire icon
    let violetLineWidth = size * 0.015  // Violet lines between tiles (1.5% of size)
    let leftWidth = size * 0.24         // 24% for left tiles
    let rightWidth = size * 0.56        // 56% for right tile
    let totalHeight = size - (2 * borderPadding)

    // Violet color for laser-cut lines
    let violetColor = CGColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)

    context.setStrokeColor(violetColor)
    context.setLineWidth(violetLineWidth)

    // Calculate positions for the mosaic grid
    let leftTileHeight = totalHeight / 4.0

    // Draw outer border rectangle
    let outerRect = CGRect(
        x: borderPadding,
        y: borderPadding,
        width: leftWidth + violetLineWidth + rightWidth,
        height: totalHeight
    )
    context.stroke(outerRect)

    // Draw horizontal lines dividing left column into 4 tiles
    for i in 1..<4 {
        let y = borderPadding + CGFloat(i) * leftTileHeight
        context.move(to: CGPoint(x: borderPadding, y: y))
        context.addLine(to: CGPoint(x: borderPadding + leftWidth, y: y))
    }

    // Draw vertical line separating left and right panels
    let dividerX = borderPadding + leftWidth
    context.move(to: CGPoint(x: dividerX, y: borderPadding))
    context.addLine(to: CGPoint(x: dividerX, y: borderPadding + totalHeight))

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
