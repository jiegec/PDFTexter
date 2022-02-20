//
//  main.swift
//  PDFTexter
//
//  Created by macbookair on 2022/2/20.
//

import ArgumentParser
import Foundation
import PDFKit
import Vision

struct PDFTexter: ParsableCommand {
  @Argument var inputDirectory: String
  @Argument var pageCount: Int
  @Argument var outputFile: String

  mutating func run() throws {
    // read pdf
    var ctx: CGContext? = nil
    for i in 0..<pageCount {
      print("Processing page \(i+1)")
      let imgDataProvider = CGDataProvider.init(
        url: NSURL.fileURL(withPathComponents: [inputDirectory, "\(i+1).jpg"])! as CFURL)!
      let cgImage = CGImage.init(
        jpegDataProviderSource: imgDataProvider, decode: nil, shouldInterpolate: false,
        intent: CGColorRenderingIntent.defaultIntent)!

      if i == 0 {
        var mediaBox = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        ctx = CGContext(
          NSURL.init(fileURLWithPath: outputFile), mediaBox: &mediaBox,
          nil)!
      }

      // Create a new request to recognize text in image
      let request = VNRecognizeTextRequest()
      request.recognitionLanguages = ["zh-Hans", "en-US"]
      let requestHandler = VNImageRequestHandler(cgImage: cgImage)

      // Create pdf page
      ctx!.beginPDFPage(nil)
      // Debugging
      //ctx!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
      do {
        // Perform the text-recognition request
        try requestHandler.perform([request])

        // Loop over text observations
        for observation in request.results! {
          if let candidate = observation.topCandidates(1).first {
            // Compute bounding box
            let text = candidate.string
            let stringRange = text.startIndex..<text.endIndex
            let boxObservation = try? candidate.boundingBox(for: stringRange)
            let boundingBox = boxObservation?.boundingBox ?? .zero

            // Compute image rect
            let rect = VNImageRectForNormalizedRect(
              boundingBox,
              Int(cgImage.width),
              Int(cgImage.height))

            // From https://stackoverflow.com/a/68810267/2148614
            func getAttributedString(text: String, size: CGFloat) -> NSAttributedString {
              // Create a paragraph style to be used with the attributed string
              let paragraphStyle = NSMutableParagraphStyle()
              paragraphStyle.alignment = .left
              // Set up the sttributes to be applied to the attributed text
              let stringAttributes = [
                NSAttributedString.Key.font: NSFont(name: "Menlo", size: size),
                NSAttributedString.Key.foregroundColor: NSColor.purple,
                NSAttributedString.Key.backgroundColor: NSColor.clear,
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
              ]
              // Create the attributed string
              let attributedString = NSAttributedString(
                string: text, attributes: stringAttributes as [NSAttributedString.Key: Any])
              return attributedString
            }

            let attributedString = getAttributedString(text: text, size: 16.0)
            let boundingRect = attributedString.boundingRect(
              with: rect.size, options: NSString.DrawingOptions.init())
            if boundingRect.width == 0 {
              // Found empty string, continue
              continue
            }

            // Save the Graphics state of the context
            ctx!.saveGState()

            // Justify if applicable
            let line = CTLineCreateWithAttributedString(attributedString)
            let justified = CTLineCreateJustifiedLine(line, 1.0, rect.width) ?? line

            // Translate position & scale in Y axis
            // Minus boundingRect.minY because it may be negative
            ctx!.textMatrix = CGAffineTransform.init(
              translationX: rect.minX, y: rect.minY - boundingRect.minY
            ).scaledBy(x: 1.0, y: rect.height / boundingRect.height)

            // Draw the text
            CTLineDraw(justified, ctx!)

            // Debugging
            //ctx!.setStrokeColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0);
            //ctx!.setLineWidth(5.0)
            //ctx!.stroke(rect);
            // Restore the previous Graphics state
            ctx!.restoreGState()
          }
        }
        print("Found \(request.results!.count) text in page \(i+1)")
      } catch {
        print("Unable to perform the requests: \(error).")
      }

      ctx!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
      ctx!.endPDFPage()
    }

    ctx!.closePDF()
    print("Written to \(outputFile)")
  }
}

PDFTexter.main()
