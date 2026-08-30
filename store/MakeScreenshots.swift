import CoreText
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 生のスクリーンショットに見出しを載せ、App Store が受け付ける寸法にそろえる。
//
//   swiftc -O MakeScreenshots.swift -o /tmp/makeshots
//   /tmp/makeshots <入力フォルダ> <出力フォルダ> [幅 高さ]
//
// 既定は 2688×1242（iPhone 6.5インチの横向き）。
// 寸法は引数で変えられるようにしてある。欄に出ている数字しか受け付けないため。

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("使い方: makeshots <入力フォルダ> <出力フォルダ> [幅 高さ]")
    exit(1)
}
let inputDir = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2])
let outW = args.count >= 5 ? Int(args[3])! : 2688
let outH = args.count >= 5 ? Int(args[4])! : 1242

// ファイル名の順に、載せる見出し
// ファイル名の順に対応させる。並びを間違えると別の画面に別の見出しが乗る
let captions: [String] = [
    "最速で聴牌する一手を選ぶ",          // 01-choose
    "すべての牌に点数がつく",            // 02-scored
    "なぜその牌が速いのかを確かめる",     // 03-detail
    "ノーミスと精度で経験値が伸びる",     // 04-result
    "70段の称号を上がっていく",          // 05-ranks
]

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, 1])!
}
let background = rgb(14, 18, 22)
let gold = rgb(255, 213, 74)

let files = (try? FileManager.default.contentsOfDirectory(at: inputDir,
                                                          includingPropertiesForKeys: nil))?
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []

guard !files.isEmpty else { print("入力フォルダにPNGがありません: \(inputDir.path)"); exit(1) }
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let headerHeight = Double(outH) * 0.14

for (index, file) in files.enumerated() {
    guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
          let raw = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }

    // 撮った画像は画素としては縦向きで、向き情報だけが横になっている。
    // そのまま描くと寝たまま出るので、ここで画素ごと起こす。
    let image: CGImage
    let forceRotate = ProcessInfo.processInfo.environment["SHOT_ROTATE"] == "1"
    if forceRotate || raw.height > raw.width {
        let rotated = CGContext(data: nil, width: raw.height, height: raw.width,
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        rotated.translateBy(x: CGFloat(raw.height), y: 0)
        rotated.rotate(by: .pi / 2)
        rotated.draw(raw, in: CGRect(x: 0, y: 0, width: raw.width, height: raw.height))
        image = rotated.makeImage()!
    } else {
        image = raw
    }

    let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))

    // 画面は下寄せ。上に見出しの帯を残す
    let area = CGRect(x: 0, y: 0, width: Double(outW), height: Double(outH) - headerHeight)
    let scale = min(area.width / Double(image.width), area.height / Double(image.height))
    let drawW = Double(image.width) * scale, drawH = Double(image.height) * scale
    ctx.draw(image, in: CGRect(x: (Double(outW) - drawW) / 2,
                               y: area.height - drawH,
                               width: drawW, height: drawH))

    // 見出し
    if index < captions.count {
        let text = captions[index] as NSString
        let size = Double(outH) * 0.062
        let font = CTFontCreateUIFontForLanguage(.system, size, "ja" as CFString)
            ?? CTFontCreateWithName("HiraginoSans-W7" as CFString, size, nil)
        // CoreText の属性キーを直に使う(AppKit/UIKit を持ち込まないため)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: gold,
        ]
        let attributed = CFAttributedStringCreate(nil, text as CFString,
                                                  attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        ctx.textPosition = CGPoint(x: (Double(outW) - bounds.width) / 2,
                                   y: Double(outH) - headerHeight * 0.62)
        CTLineDraw(line, ctx)
    }

    print("  読み込み \(file.lastPathComponent): 生の画素 \(raw.width)×\(raw.height) → 使用 \(image.width)×\(image.height)")
    let out = outputDir.appendingPathComponent(String(format: "%02d.png", index + 1))
    let dest = CGImageDestinationCreateWithURL(out as CFURL,
                                               UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("書き出し \(out.lastPathComponent)  \(outW)×\(outH)")
}
