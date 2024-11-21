//
//  ImageModel.swift
//  Test
//
//  Created by дилара  on 21.11.2024.
//

import Foundation
import UIKit

class ImageModel {
    var images: [UIImage] = []
    var processedImages: [UIImage] = []

    func loadImages() {
        for i in 1...10 {
            if let image = UIImage(named: "Image\(i)") {
                images.append(image)
            }
        }
    }

    func applyRandomFilter(to image: UIImage) throws -> UIImage {
        let ciImage = CIImage(image: image)
        guard let filter = CIFilter(name: "CIColorInvert") else {
            throw NSError(domain: "FilterError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать фильтр"])
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            throw NSError(domain: "FilterError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось применить фильтр"])
        }
        return UIImage(cgImage: cgImage)
    }
}
