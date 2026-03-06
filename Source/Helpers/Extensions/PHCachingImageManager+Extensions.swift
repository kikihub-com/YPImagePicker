//
//  PHCachingImageManager+Helpers.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 26/01/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Photos

extension PHCachingImageManager {

    private func photoImageRequestOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        // isSynchronous removed: it blocks iCloud downloads.
        // The caller is already on a background thread, async is fine.
        return options
    }

    func fetchImage(for asset: PHAsset,
					cropRect: CGRect,
					targetSize: CGSize,
					callback: @escaping (UIImage, [String: Any]) -> Void) {
        let options = photoImageRequestOptions()

        // Fetch Highiest quality image possible.
        requestImageData(for: asset, options: options) { data, _, _, info in
            if let data = data, let image = UIImage(data: data)?.resetOrientation() {

                // Crop the high quality image manually.
                let xCrop: CGFloat = cropRect.origin.x * CGFloat(asset.pixelWidth)
                let yCrop: CGFloat = cropRect.origin.y * CGFloat(asset.pixelHeight)
                let scaledCropRect = CGRect(x: xCrop,
                                            y: yCrop,
                                            width: targetSize.width,
                                            height: targetSize.height)
                if let imageRef = image.cgImage?.cropping(to: scaledCropRect) {
                    let croppedImage = UIImage(cgImage: imageRef)
                    let exifs = self.metadataForImageData(data: data)
                    callback(croppedImage, exifs)
                }
            } else {
                // iCloud download failed or returned no data — notify caller
                let error = info?[PHImageErrorKey] as? Error
                ypLog("fetchImage failed: \(error?.localizedDescription ?? "unknown error")")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .ypImagePickerICloudDownloadFailed, object: nil)
                }
            }
        }
    }

    private func metadataForImageData(data: Data) -> [String: Any] {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),
        let metaData = imageProperties as? [String: Any] {
            return metaData
        }
        return [:]
    }

    func fetchPreviewFor(video asset: PHAsset, callback: @escaping (UIImage) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        let screenWidth = YPImagePickerConfiguration.screenWidth
        let ts = CGSize(width: screenWidth, height: screenWidth)
        requestImage(for: asset, targetSize: ts, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    callback(image)
                }
            }
        }
    }

    func fetchPlayerItem(for video: PHAsset, callback: @escaping (AVPlayerItem) -> Void) {
        let videosOptions = PHVideoRequestOptions()
        videosOptions.deliveryMode = PHVideoRequestOptionsDeliveryMode.automatic
        videosOptions.isNetworkAccessAllowed = true
        requestPlayerItem(forVideo: video, options: videosOptions, resultHandler: { playerItem, _ in
            DispatchQueue.main.async {
                if let playerItem = playerItem {
                    callback(playerItem)
                }
            }
        })
    }

    /// This method return two images in the callback. First is with low resolution, second with high.
    /// So the callback fires twice.
    func fetch(photo asset: PHAsset, callback: @escaping (UIImage, Bool) -> Void) {
        let options = PHImageRequestOptions()
		// Enables gettings iCloud photos over the network, this means PHImageResultIsInCloudKey will never be true.
        options.isNetworkAccessAllowed = true
		// Get 2 results, one low res quickly and the high res one later.
        options.deliveryMode = .opportunistic
        options.progressHandler = { progress, error, stop, info in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .ypImagePickerICloudDownloadProgress,
                    object: nil,
                    userInfo: ["progress": Float(progress)]
                )
            }
        }
        requestImage(for: asset, targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
					 contentMode: .aspectFill, options: options) { result, info in
            guard let image = result else {
                ypLog("No Result 🛑")
                // iCloud download failed — hide loader and notify
                DispatchQueue.main.async {
                    callback(UIImage(), false)
                    NotificationCenter.default.post(name: .ypImagePickerICloudDownloadFailed, object: nil)
                }
                return
            }
            DispatchQueue.main.async {
                let isLowRes = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                callback(image, isLowRes)
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let ypImagePickerICloudDownloadFailed = Notification.Name("ypImagePickerICloudDownloadFailed")
    static let ypImagePickerICloudDownloadProgress = Notification.Name("ypImagePickerICloudDownloadProgress")
}
