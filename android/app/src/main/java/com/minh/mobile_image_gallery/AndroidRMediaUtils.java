//package com.minh.mobile_image_gallery;
//
//import android.app.Activity;
//import android.content.ContentResolver;
//import android.content.ContentUris;
//import android.content.ContentValues;
//import android.net.Uri;
//import android.provider.MediaStore;
//
//import java.util.List;
//
//public class AndroidRMediaUtils implements IMediaUtils {
//    private Activity activity;
//
//    private ContentResolver contentResolver;
//
//    private final Uri baseImageExternalUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
//    private final Uri baseVideoExternalUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
//
/// /        Uri imagePrimaryContentUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); // content://media/external_primary/images/media
/// /        Uri videoPrimaryContentUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); // content://media/external_primary/video/media
/// /        Uri imageInternalContentUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_INTERNAL); // content://media/internal/images/media
/// /        Uri videoInternalContentUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_INTERNAL); // content://media/internal/video/media
//
//
//    public AndroidRMediaUtils(Activity activity) {
//        this.activity = activity;
//        this.contentResolver = activity.getContentResolver();
//    }
//
//    @Override
//    public void handleMoveToAlbum(String albumName, List<MediaAsset> mediaAssetList) {
//        try {
//            for (MediaAsset mediaAsset : mediaAssetList) {
//                Uri uri = this.getUri(mediaAsset);
//                ContentValues values = new ContentValues();
//                values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/" + albumName);
//                contentResolver.update(uri, values, null, null);
//            }
//        } catch (Exception e) {
//        }
//    }
//
//    @Override
//    public void handleMoveToTrash(List<MediaAsset> mediaAssetList) {
//    }
//
//    @Override
//    public void moveMediaToAlbum(String albumName, List<MediaAsset> mediaAssets) {
//
//    }
//
//    @Override
//    public void deleteAlbum(String albumName) {
//    }
//
//    @Override
//    public void handleDeleteAlbum(String albumName, boolean deleteMedia) {
//
//    }
//
//    @Override
//    public Uri getUri(MediaAsset mediaAsset) {
//        return ContentUris.withAppendedId(mediaAsset.type == 0 ? baseImageExternalUri : baseVideoExternalUri, mediaAsset.id);
//    }
//
//    @Override
//    public void createAlbum(String albumName, List<MediaAsset> mediaAssets) {
//
//    }
//
//    @Override
//    public void handleCreateAlbum(String albumName, List<MediaAsset> mediaAssets) {
//
//    }
//
//    @Override
//    public void moveMediaToTrash(List<MediaAsset> mediaAssets) {
//
//    }
//}
