//
//  CameraRollModel.swift
//  VideoSolution
//
//  Created by Galean Pallerman on 06.08.2019.
//  Copyright © 2019 GPco. All rights reserved.
//

import Foundation
import Photos

protocol CameraRollModelProtocol: NSObject {
    var delegate: CameraRollModelDelegate? { get set }
    func fetchCameraRoll()
}

protocol CameraRollModelDelegate: NSObject {
    func fetchedCameraRoll(galleryLastImage imageData: GalleryPreviewData)
}

extension CameraRollModel: CameraRollModelProtocol {
    func fetchCameraRoll() {
        DispatchQueue.global().async {
            self.internalFetchCameraRoll()
        }
    }
}

class CameraRollModel: NSObject {
    public weak var delegate: CameraRollModelDelegate?
    
    func internalFetchCameraRoll() {
        // Sort the images by descending creation date and fetch the first 3
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d || mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        // Fetch the image assets
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        // If the fetch result isn't empty,
        // proceed with the image request
        if fetchResult.count > 0 {
            // Note that if the request is not set to synchronous
            // the requestImageForAsset will return both the image
            // and thumbnail; by setting synchronous to true it
            // will return just the thumbnail
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.isNetworkAccessAllowed = true
            
            // Perform the image request
            PHImageManager.default().requestImage(for: fetchResult.object(at: 0) as PHAsset, targetSize: CGSize(width: 100, height: 100), contentMode: PHImageContentMode.aspectFill, options: requestOptions, resultHandler: { (image, _) in
                if let image = image {
                    let previewData = GalleryPreviewData(image: image)
                    self.delegate?.fetchedCameraRoll(galleryLastImage: previewData)
                }
            })
        }
    }
}
