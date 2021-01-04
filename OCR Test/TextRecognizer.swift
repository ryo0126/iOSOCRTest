//
//  TextRecognizer.swift
//  OCR Test
//
//  Created by Ryo on 2021/01/04.
//

import UIKit
import Vision

/// 文字列認識クラスのデリゲート
protocol TextRecognizerDelegate: AnyObject {

    /// 文字列を認識したときの処理
    /// - Parameters:
    ///   - recognizer: ソースオブジェクト
    ///   - text: 認識した文字列
    func textRecognizer(_ recognizer: TextRecognizer, didRecognize text: String)

    /// 文字列の認識に失敗したときの処理
    /// - Parameters:
    ///   - recognizer: ソースオブジェクト
    ///   - error: エラー
    func textRecognizer(_ recognizer: TextRecognizer, didFailWith error: Error)
}

extension TextRecognizerDelegate {

    func textRecognizer(_ recognizer: TextRecognizer, didRecognize text: String) {}
    func textRecognizer(_ recognizer: TextRecognizer, didFailWith error: Error) {}
}

/// 文字列認識クラス
class TextRecognizer {

    /// エラー種別
    enum RecognitionError: Error {
        case unexpectedObservationReturned(String), other(Error)
    }

    /// デリゲート
    weak var delegate: TextRecognizerDelegate? = nil
    /// 認識レベル
    var recognitionLevel: VNRequestTextRecognitionLevel = .fast {
        didSet {
            recognizeTextRequests = nil
        }
    }
    /// 現在認識中かどうか
    var isProcessing = false
    /// 文字列認識リクエスト(遅延初期化)
    private var recognizeTextRequests: [VNRecognizeTextRequest]! = nil

    /// 画像内の文字列を認識する
    /// - Parameter image: 対象の画像
    /// - Returns: 認識処理開始に成功したかどうか
    @discardableResult
    func perform(image: UIImage) -> Bool {
        guard !isProcessing,
              let correctOrientationImage = image.correctOrientationImage,
              let cgImage = correctOrientationImage.cgImage else { return false }

        isProcessing = true

        // 遅延初期化
        if recognizeTextRequests == nil {
            setupRequests()
        }

        DispatchQueue.global(qos: .userInitiated)
            .async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try requestHandler.perform(self.recognizeTextRequests)
                } catch let error {
                    self.isProcessing = false
                    // デリゲートにはmainで通知
                    DispatchQueue.main.sync {
                        self.delegate?.textRecognizer(self, didFailWith: RecognitionError.other(error))
                    }
                }
            }

        return true
    }

    /// 文字列認識リクエストをセットアップする
    private func setupRequests() {
        let textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self = self else { return }

            defer {
                // クロージャを抜けるときに処理中フラグをオフにする
                self.isProcessing = false
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                let message = "The observations are of an unexpected type."
                let error = RecognitionError.unexpectedObservationReturned(message)
                // デリゲートにはmainで通知
                DispatchQueue.main.sync {
                    self.delegate?.textRecognizer(self, didFailWith: error)
                }
                return
            }

            var recognizedText = ""
            let maximumCandidates = 1
            for observation in observations {
                guard let candidate = observation.topCandidates(maximumCandidates).first else { continue }
                recognizedText += candidate.string + "\n"
            }
            // デリゲートにはmainで通知
            DispatchQueue.main.sync {
                self.delegate?.textRecognizer(self, didRecognize: recognizedText)
            }
        }
        // 文字認識のレベルを設定
        textRecognitionRequest.recognitionLevel = recognitionLevel

        recognizeTextRequests = [textRecognitionRequest]
    }
}
