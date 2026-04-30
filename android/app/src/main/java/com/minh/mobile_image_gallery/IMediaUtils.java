package com.minh.mobile_image_gallery;

import android.net.Uri;

import java.util.List;

public interface IMediaUtils {
    Uri getUri(MediaAsset mediaAsset);

    void createAlbum(String albumName, List<MediaAsset> mediaAssets);

    void handleCreateAlbum(String albumName, List<MediaAsset> mediaAssets);

    void moveMediaToTrash(List<MediaAsset> mediaAssets);

    void handleMoveToTrash(List<MediaAsset> mediaAssets);

    void moveMediaToAlbum(String albumName, List<MediaAsset> mediaAssets);

    void handleMoveToAlbum(String albumName, List<MediaAsset> mediaAssets);

    void deleteAlbum(String albumName);

    void handleDeleteAlbum(String albumName, boolean deleteMedia);
}

