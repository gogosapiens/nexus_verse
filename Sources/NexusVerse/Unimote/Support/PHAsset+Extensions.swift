import Photos

extension PHAsset {
    
    func getURL(completionHandler : @escaping (URL?) -> Void) {
        switch mediaType {
        case .image:
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = { _ in true }
            options.isNetworkAccessAllowed = false
            self.requestContentEditingInput(with: options) { input, info in
                completionHandler(input?.fullSizeImageURL as? URL)
            }
        case .video:
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestAVAsset(forVideo: self, options: options) { asset, audioMix, info in
                completionHandler((asset as? AVURLAsset)?.url)
            }
        default:
            completionHandler(nil)
        }
    }
}
