// ocr.swift — OCR a directory of images via macOS Vision framework (offline, zh-Hans + en-US)
// Usage: swift ocr.swift <image_dir> [output_file]
// Prints "=== <filename> ===" blocks with recognized text lines joined by " | ".
import Foundation
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: swift ocr.swift <image_dir> [out.txt]")
    exit(1)
}
let dir = args[1]
let fm = FileManager.default
let files = (try? fm.contentsOfDirectory(atPath: dir))?
    .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".png") }
    .sorted() ?? []

var out: [String] = []
for f in files {
    let url = URL(fileURLWithPath: dir + "/" + f)
    guard let img = NSImage(contentsOf: url),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["zh-Hans", "en-US"]
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([req])
    let texts = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    out.append("=== \(f) ===")
    out.append(texts.joined(separator: " | "))
}

let joined = out.joined(separator: "\n")
if args.count >= 3, let data = (joined + "\n").data(using: .utf8) {
    try? data.write(to: URL(fileURLWithPath: args[2]))
}
print(joined)
