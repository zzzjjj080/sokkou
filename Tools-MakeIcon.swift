import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// アプリアイコン。ホーム画面では60px程度まで縮むので、
// 細い線や模様は消える。シルエットで見せる。
// 「速く聴牌へ向かう」を、右へ抜ける矢羽根と1枚の牌で表す。

let size = 1024.0
let inset = size * 0.07          // 角丸マスクで端が欠けるぶんの余白

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                    bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, 1])!
}
let deepGreen = rgb(23, 74, 56)
let cream = rgb(250, 246, 232)
let ink = rgb(38, 52, 77)
let accent = rgb(255, 196, 61)

// 地色
ctx.setFillColor(deepGreen)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// 速さを表す矢羽根。3本、右上へ抜ける
ctx.setStrokeColor(accent)
ctx.setLineWidth(size * 0.055)
ctx.setLineCap(.round)
for i in 0..<3 {
    let offset = Double(i) * size * 0.135
    let baseX = inset + size * 0.10 + offset
    let midX = baseX + size * 0.115
    ctx.move(to: CGPoint(x: baseX, y: size * 0.30))
    ctx.addLine(to: CGPoint(x: midX, y: size * 0.50))
    ctx.addLine(to: CGPoint(x: baseX, y: size * 0.70))
    ctx.strokePath()
}

// 牌1枚。角丸の白い札
let tileW = size * 0.30, tileH = tileW * 4 / 3
let tileRect = CGRect(x: size - inset - tileW - size * 0.06,
                      y: (size - tileH) / 2, width: tileW, height: tileH)
let tilePath = CGPath(roundedRect: tileRect,
                      cornerWidth: tileW * 0.16, cornerHeight: tileW * 0.16, transform: nil)
ctx.setFillColor(cream)
ctx.addPath(tilePath)
ctx.fillPath()

// 牌の中は太い横線2本。細かい絵柄は縮小で消えるので描かない
ctx.setStrokeColor(ink)
ctx.setLineWidth(tileW * 0.16)
ctx.setLineCap(.round)
for row in 0..<2 {
    let y = tileRect.midY + (row == 0 ? tileH * 0.17 : -tileH * 0.17)
    ctx.move(to: CGPoint(x: tileRect.minX + tileW * 0.22, y: y))
    ctx.addLine(to: CGPoint(x: tileRect.maxX - tileW * 0.22, y: y))
    ctx.strokePath()
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let url = URL(fileURLWithPath: out)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
