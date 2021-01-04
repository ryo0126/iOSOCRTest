//
//  ViewController.swift
//  OCR Test
//
//  Created by Ryo on 2021/01/04.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    /// プレビュー固定状態
    private enum LockViewMode {
        case locking, unlocking

        /// 状態を切り替える
        /// - Returns: 次の状態
        func toggle() -> LockViewMode {
            switch self {
            case .locking:
                return .unlocking
            case .unlocking:
                return .locking
            }
        }
    }

    /// カメラのプレビューを表示するビュー
    @IBOutlet weak var previewView: UIImageView!
    /// 認識した文字列を表示するビューのラッパー
    @IBOutlet weak var recognizedTextWrapper: UIView!
    /// 認識した文字列を表示するビュー
    @IBOutlet weak var recognizedTextView: UITextView!
    /// プレビュー固定ボタンのラベル
    @IBOutlet weak var lockViewButtonLabel: UILabel!
    /// プレビュー固定ボタン
    @IBOutlet weak var lockViewButton: UIButton!
    /// 認識レベル切り替えボタンのラベル
    @IBOutlet weak var recognitionLevelLabel: UILabel!
    /// 認識レベル切り替えボタン
    @IBOutlet weak var toggleRecognitionLevelButton: UIButton!

    /// 文字列認識
    private var textRecognizer: TextRecognizer!
    /// 現在のプレビュー固定状態
    private var lockViewMode = LockViewMode.unlocking
    /// 現在の認識レベル状態
    private var recognitionLevel = VNRequestTextRecognitionLevel.fast

    private var captureSession: AVCaptureSession!
    private var captureOutput: AVCaptureVideoDataOutput!

    override func viewDidLoad() {
        super.viewDidLoad()

        previewView.layer.cornerRadius = 10
        recognizedTextWrapper.layer.cornerRadius = 10
        setupCamera()
        updateView(with: lockViewMode)
        updateView(with: recognitionLevel)
        textRecognizer = TextRecognizer()
        textRecognizer.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        captureSession.startRunning()
    }

    /// プレビュー固定ボタンが押されたときの処理
    /// - Parameter sender: 押されたボタン
    @IBAction func lockViewButtonWasTapped(_ sender: UIButton) {
        lockViewMode = lockViewMode.toggle()
        updateView(with: lockViewMode)
    }

    /// 認識レベル切り替えボタンが押されたときの処理
    /// - Parameter sender: 押されたボタン
    @IBAction func toggleRecognitionLevelButtonWasTapped(_ sender: UIButton) {
        guard lockViewMode == .unlocking || lockViewMode == .locking && !textRecognizer.isProcessing else { return }

        recognitionLevel = recognitionLevel.toggle()
        updateView(with: recognitionLevel)

        textRecognizer.recognitionLevel = recognitionLevel
        if let currentImage = previewView.image {
            textRecognizer.perform(image: currentImage)
        }
    }

    /// カメラをセットアップする
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureOutput = AVCaptureVideoDataOutput()
        captureOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA]
        captureOutput.setSampleBufferDelegate(self, queue: .main)

        // 解像度の設定
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video) else {
            fatalError("Could not get AVCaptureDevice instance.")
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            guard captureSession.canAddInput(input) && captureSession.canAddOutput(captureOutput) else {
                fatalError("Could not add either input or output to the session.")
            }

            captureSession.addInput(input)
            captureSession.addOutput(captureOutput)
        } catch {
            fatalError("An error occurred while instantiating AVCaptureDeviceInput: \(error)")
        }
    }

    /// ビューを更新する
    /// - Parameter lockViewMode: プレビュー固定状態
    private func updateView(with lockViewMode: LockViewMode) {
        switch lockViewMode {
        case .locking:
            lockViewButton.setImage(UIImage(systemName: "lock.fill"), for: .normal)
            lockViewButtonLabel.text = "LOCKING"
        case .unlocking:
            lockViewButton.setImage(UIImage(systemName: "lock.slash.fill"), for: .normal)
            lockViewButtonLabel.text = "UNLOCKING"
        }
        // ボタンの画像をアスペクト比を維持しながらボタンサイズまで拡大させるための設定
        lockViewButton.imageView?.contentMode = .scaleAspectFit
        lockViewButton.contentHorizontalAlignment = .fill
        lockViewButton.contentVerticalAlignment = .fill
    }

    /// ビューを更新する
    /// - Parameter recognitionLevel: 認識レベル状態
    private func updateView(with recognitionLevel: VNRequestTextRecognitionLevel) {
        switch recognitionLevel {
        case .fast:
            toggleRecognitionLevelButton.setImage(UIImage(systemName: "hare.fill"), for: .normal)
            recognitionLevelLabel.text = "FAST"
        case .accurate:
            toggleRecognitionLevelButton.setImage(UIImage(systemName: "hare"), for: .normal)
            recognitionLevelLabel.text = "ACCURATE"
        @unknown default:
            fatalError("Not supported type: \(recognitionLevel)")
        }
        // ボタンの画像をアスペクト比を維持しながらボタンサイズまで拡大させるための設定
        toggleRecognitionLevelButton.imageView?.contentMode = .scaleAspectFit
        toggleRecognitionLevelButton.contentHorizontalAlignment = .fill
        toggleRecognitionLevelButton.contentVerticalAlignment = .fill
    }

    /// バッファーから画像を取得する
    /// - Parameter sampleBuffer: 対象の`CMSampleBuffer`
    /// - Returns: 取得した画像, 失敗した場合は`nil`.
    private func getImage(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else { return nil }

        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return image
    }

    deinit {
        captureSession.stopRunning()
    }
}

extension VNRequestTextRecognitionLevel {

    /// 状態を切り替える
    /// - Returns: 次の状態
    func toggle() -> VNRequestTextRecognitionLevel {
        switch self {
        case .fast:
            return .accurate
        case .accurate:
            return .fast
        @unknown default:
            fatalError("Not supported type: \(self)")
        }
    }
}

// MARK: - for AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard lockViewMode == .unlocking else { return }

        guard let raw = getImage(from: sampleBuffer),
              let cropped = raw.cropping(to: previewView.frame.size) else { return }
        previewView.image = cropped
        textRecognizer.perform(image: cropped)
    }
}

// MARK: - for TextRecognizerDelegate
extension ViewController : TextRecognizerDelegate {

    func textRecognizer(_ recognizer: TextRecognizer, didRecognize text: String) {
        recognizedTextView.text = text
    }
}
