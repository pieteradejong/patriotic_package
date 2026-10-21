// Cuts the subject out of a photo with Vision's foreground mask (macOS 14+).
// Usage: swift lift.swift <in.jpg> <out.png>
import CoreImage
import Vision

let args = CommandLine.arguments
let input = CIImage(contentsOf: URL(fileURLWithPath: args[1]))!
let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(ciImage: input)
try handler.perform([request])
let result = request.results!.first!
let masked = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
try CIContext().writePNGRepresentation(
	of: CIImage(cvPixelBuffer: masked), to: URL(fileURLWithPath: args[2]),
	format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
