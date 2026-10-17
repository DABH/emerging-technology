// facecrop: crop a portrait around the largest detected face so every headshot shares the same framing.
// usage: facecrop <in> <out.png> <aspectW> <aspectH> <outWidth> <faceHeightFraction> <faceCenterY> [faceIndexOrMinusOne]
//   faceHeightFraction: detected face-box height as a fraction of the output height
//   faceCenterY: where the face-box center sits, as a fraction of the output height from the top
import Foundation
import Vision
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count >= 8,
      let aw = Double(a[3]), let ah = Double(a[4]), let outW = Int(a[5]),
      let faceFrac = Double(a[6]), let faceCY = Double(a[7]) else {
    FileHandle.standardError.write("usage: facecrop in out.png aw ah outW faceFrac faceCY [faceIndex]\n".data(using: .utf8)!)
    exit(2)
}
let faceIndex = a.count >= 9 ? Int(a[8]) ?? -1 : -1
let outH = Int((Double(outW) * ah / aw).rounded())

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil) else { print("ERR cannot open"); exit(1) }
let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
let w0 = props?[kCGImagePropertyPixelWidth] as? Int ?? 4096
let h0 = props?[kCGImagePropertyPixelHeight] as? Int ?? 4096
let thumbOpts: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,   // apply EXIF orientation
    kCGImageSourceThumbnailMaxPixelSize: max(w0, h0),
]
guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else { print("ERR cannot decode"); exit(1) }
let W = Double(img.width), H = Double(img.height)

let req = VNDetectFaceRectanglesRequest()
do { try VNImageRequestHandler(cgImage: img, options: [:]).perform([req]) } catch { print("ERR vision \(error)"); exit(1) }
let faces = (req.results ?? []).sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
guard !faces.isEmpty else { print("NOFACE src=\(Int(W))x\(Int(H))"); exit(3) }
let face = faces[(faceIndex >= 0 && faceIndex < faces.count) ? faceIndex : 0]
let bb = face.boundingBox  // normalized, origin bottom-left
let fx = bb.midX * W, fy = (1 - bb.midY) * H, fw = bb.width * W, fh = bb.height * H

var cropH = fh / faceFrac
var cropW = cropH * aw / ah
if cropH > H { cropH = H; cropW = cropH * aw / ah }
if cropW > W { cropW = W; cropH = cropW * ah / aw }
let left = min(max(fx - cropW / 2, 0), W - cropW)
let top = min(max(fy - faceCY * cropH, 0), H - cropH)
let rect = CGRect(x: left, y: top, width: cropW, height: cropH).integral
guard let cropped = img.cropping(to: rect) else { print("ERR crop"); exit(1) }

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { print("ERR ctx"); exit(1) }
ctx.setFillColor(CGColor(srgbRed: 0.92, green: 0.91, blue: 0.89, alpha: 1))  // backs transparent PNGs
ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
ctx.interpolationQuality = .high
ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: outW, height: outH))
guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil) else { print("ERR out"); exit(1) }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { print("ERR write"); exit(1) }

// Framing achieved after any clamping: how tall the face is and where its center landed.
let gotFrac = fh / rect.height, gotCY = (fy - rect.minY) / rect.height, gotCX = (fx - rect.minX) / rect.width
print(String(format: "OK src=%dx%d faces=%d face=%.0fx%.0f crop=%.0fx%.0f upscale=%.2f faceFrac=%.2f faceCY=%.2f faceCX=%.2f",
             Int(W), Int(H), faces.count, fw, fh, rect.width, rect.height, Double(outW) / rect.width, gotFrac, gotCY, gotCX))
