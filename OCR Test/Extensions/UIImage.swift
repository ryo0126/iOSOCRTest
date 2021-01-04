//
//  UIImage.swift
//  Camera Test
//
//  Created by Ryo on 2020/12/29.
//

import Foundation
import UIKit

extension UIImage {

    /// `imageOrientation`が幅と高さが入れ替わるような向きになっているかどうか
    public var isSwappingWidthHeight: Bool {
        switch imageOrientation {
        case .right, .left, .rightMirrored, .leftMirrored:
            return true
        default:
            return false
        }
    }

    /// `imageOrientation`に沿って回転した正しい向きの`UIImage`
    public var correctOrientationImage: UIImage? {
        UIGraphicsBeginImageContext(size)

        draw(at: CGPoint(x: 0, y: 0))
        let corrected = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        return corrected
    }

    /// 比率を守りながら画像を切り取って返す
    /// - Parameter aspectRatio: 切り取る比率
    /// - Returns: `aspectRatio`に従って切り取った`UIImage`. `cgImage`が`nil`, あるいは失敗した場合は`nil`.
    public func cropping(to aspectRatio: CGSize) -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        let originalHeight = cgImage.height
        let originalWidth = cgImage.width
        let originalRatio = CGFloat(originalHeight) / CGFloat(originalWidth)
        let aspectRatioHeight: Int
        let aspectRatioWidth: Int
        if isSwappingWidthHeight {
            // 幅と高さが入れ替わるような向きの場合は、アスペクト比の幅と高さを入れ替える
            aspectRatioHeight = Int(aspectRatio.width)
            aspectRatioWidth = Int(aspectRatio.height)
        } else {
            aspectRatioHeight = Int(aspectRatio.height)
            aspectRatioWidth = Int(aspectRatio.width)
        }
        let aspectRatio = CGFloat(aspectRatioHeight) / CGFloat(aspectRatioWidth)

        let newHeight: Int
        let newWidth: Int
        let newX: Int
        let newY: Int
        if aspectRatio > originalRatio {
            // アスペクト比の縦比率の方が大きい場合は, 画像の両端が切り落とされるように切り取る
            newHeight = originalHeight
            newWidth = Int(CGFloat(originalHeight) / aspectRatio)
            newX = Int(CGFloat(originalWidth - newWidth) * 0.5)
            newY = 0
        } else {
            // アスペクト比が同じあるいは横比率の方が大きい場合は, 画像の上下が切り落とされるように切り取る
            newHeight = Int(CGFloat(originalWidth) * aspectRatio)
            newWidth = originalWidth
            newX = 0
            newY = Int(CGFloat(originalHeight - newHeight) * 0.5)
        }

        let newRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        guard let cropped = cgImage.cropping(to: newRect) else { return nil }

        let croppedUIImage = UIImage(cgImage: cropped, scale: 0, orientation: imageOrientation)
        return croppedUIImage
    }

    /// 正方形の比率で切り取る
    /// - Returns: 正方形の比率で切り取った`UIImage`. `cgImage`が`nil`, あるいは失敗した場合は`nil`.
    public func croppingToSquare() -> UIImage? {
        return cropping(to: CGSize(width: 1, height: 1))
    }
}
