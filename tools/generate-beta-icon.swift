#!/usr/bin/env swift
// Liest Production-Icons aus AppIcon.appiconset und erzeugt eine Beta-Variante
// (Orange-Tint + kleines Greek-Beta-Badge unten rechts) in AppIconBeta.appiconset.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Visuelle Tuning-Parameter. Anpassen, wenn das Beta-Icon klarer/dezenter werden soll.
let tintRGBA: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) =
    (1.0, 0.55, 0.0, 0.55)
let badgeDiameterRatio: CGFloat = 0.42
let badgeInsetRatio: CGFloat = 0.04
let badgeFillAlpha: CGFloat = 0.85
let badgeFontSizeRatio: CGFloat = 0.72

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assets = repoRoot
    .appendingPathComponent("Sources/WhisperDictation/Assets.xcassets")
let sourceSet = assets.appendingPathComponent("AppIcon.appiconset")
let targetSet = assets.appendingPathComponent("AppIconBeta.appiconset")

if fileManager.fileExists(atPath: targetSet.path) {
    try fileManager.removeItem(at: targetSet)
}
try fileManager.createDirectory(at: targetSet, withIntermediateDirectories: true)

struct IconEntry { let size: Int; let scale: Int; let filename: String }

let entries: [IconEntry] = [
    .init(size: 16,  scale: 1, filename: "icon_16x16.png"),
    .init(size: 16,  scale: 2, filename: "icon_16x16@2x.png"),
    .init(size: 32,  scale: 1, filename: "icon_32x32.png"),
    .init(size: 32,  scale: 2, filename: "icon_32x32@2x.png"),
    .init(size: 128, scale: 1, filename: "icon_128x128.png"),
    .init(size: 128, scale: 2, filename: "icon_128x128@2x.png"),
    .init(size: 256, scale: 1, filename: "icon_256x256.png"),
    .init(size: 256, scale: 2, filename: "icon_256x256@2x.png"),
    .init(size: 512, scale: 1, filename: "icon_512x512.png"),
    .init(size: 512, scale: 2, filename: "icon_512x512@2x.png"),
]

func loadPNG(_ url: URL) -> CGImage {
    guard let dataProvider = CGDataProvider(url: url as CFURL),
          let image = CGImage(pngDataProviderSource: dataProvider,
                              decode: nil,
                              shouldInterpolate: true,
                              intent: .defaultIntent) else {
        FileHandle.standardError.write(Data("fehler: kann \(url.path) nicht lesen\n".utf8))
        exit(1)
    }
    return image
}

func tintAndBadge(image: CGImage, pixelSize: CGFloat) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = Int(pixelSize) * 4
    guard let ctx = CGContext(data: nil,
                              width: Int(pixelSize),
                              height: Int(pixelSize),
                              bitsPerComponent: 8,
                              bytesPerRow: bytesPerRow,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        FileHandle.standardError.write(Data("fehler: CGContext init failed\n".utf8))
        exit(1)
    }
    let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    ctx.draw(image, in: rect)

    // Orange Multiply-Tint: erhält Form, färbt Highlights orange.
    ctx.setBlendMode(.multiply)
    ctx.setFillColor(red: tintRGBA.red, green: tintRGBA.green, blue: tintRGBA.blue, alpha: tintRGBA.alpha)
    ctx.fill(rect)

    // β-Badge unten rechts. Skalierung relativ zur Pixelgröße.
    ctx.setBlendMode(.normal)
    let badgeDiameter = pixelSize * badgeDiameterRatio
    let badgeInset = pixelSize * badgeInsetRatio
    let badgeRect = CGRect(x: pixelSize - badgeDiameter - badgeInset,
                           y: badgeInset,
                           width: badgeDiameter,
                           height: badgeDiameter)
    ctx.setFillColor(red: 0.0, green: 0.0, blue: 0.0, alpha: badgeFillAlpha)
    ctx.fillEllipse(in: badgeRect)

    let fontSize = badgeDiameter * badgeFontSizeRatio
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let text = NSAttributedString(string: "β", attributes: attrs)
    let textSize = text.size()
    let textRect = CGRect(
        x: badgeRect.midX - textSize.width / 2,
        y: badgeRect.midY - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
    )
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    text.draw(in: textRect)
    NSGraphicsContext.restoreGraphicsState()

    guard let result = ctx.makeImage() else {
        FileHandle.standardError.write(Data("fehler: makeImage failed\n".utf8))
        exit(1)
    }
    return result
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     "public.png" as CFString,
                                                     1, nil) else {
        FileHandle.standardError.write(Data("fehler: kann \(url.path) nicht schreiben\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for entry in entries {
    let pixelSize = CGFloat(entry.size * entry.scale)
    let source = sourceSet.appendingPathComponent(entry.filename)
    let target = targetSet.appendingPathComponent(entry.filename)
    let img = loadPNG(source)
    let processed = tintAndBadge(image: img, pixelSize: pixelSize)
    writePNG(processed, to: target)
    print("schrieb \(target.lastPathComponent)")
}

let contents: [String: Any] = [
    "images": entries.map { entry in
        [
            "size": "\(entry.size)x\(entry.size)",
            "idiom": "mac",
            "filename": entry.filename,
            "scale": "\(entry.scale)x",
        ]
    },
    "info": ["version": 1, "author": "xcode"],
]
let json = try JSONSerialization.data(withJSONObject: contents,
                                      options: [.prettyPrinted, .sortedKeys])
try json.write(to: targetSet.appendingPathComponent("Contents.json"))
print("schrieb Contents.json")
