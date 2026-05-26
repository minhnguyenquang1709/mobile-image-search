package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.Intent;
import android.content.IntentSender;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import com.minh.mobile_image_gallery.constants.MethodNames;
import com.minh.mobile_image_gallery.constants.RequestCodes;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.logging.Level;
import java.util.logging.Logger;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class GalleryMethodHandler implements MethodChannel.MethodCallHandler {
    private final Activity activity;
    private final ContentResolver contentResolver;
    private final Logger logger = Logger.getLogger("GalleryMethodHandler");
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private MethodChannel.Result pendingResult;

    public GalleryMethodHandler(Activity activity) {
        this.activity = activity;
        this.contentResolver = activity.getContentResolver();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        logger.log(Level.INFO, "Called: " + call.method + " with args: " + call.arguments);

        switch (call.method) {
            case MethodNames.createAlbum:
                createAlbum(call, result);
                break;
            case "checkAlbumExistence":
                checkAlbumExistence(call, result);
                break;
            case MethodNames.permanentlyDelete:
                permanentlyDelete(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void createAlbum(MethodCall call, MethodChannel.Result result) {
        String albumTitle = call.argument("albumTitle");

        executor.execute(() -> {
            try {
                File dcimDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM);
                File newAlbumDir = new File(dcimDir, albumTitle);

                if (!newAlbumDir.exists()) {
                    boolean created = newAlbumDir.mkdirs();
                    if (!created) {
                        mainHandler.post(() -> result.error("CREATE_FAILED", "Failed to create directory", null));
                        return;
                    }
                }

                String bucketId = String.valueOf(newAlbumDir.getAbsolutePath().toLowerCase().hashCode());
                mainHandler.post(() -> result.success(bucketId));
            } catch (Exception e) {
                mainHandler.post(() -> result.error("CREATE_ERROR", e.getMessage(), null));
            }
        });
    }

    private void checkAlbumExistence(MethodCall call, MethodChannel.Result result) {
        String appAlbumDir = call.argument("appAlbumDir");
        String albumName = call.argument("albumName");

        executor.execute(() -> {
            try {
                File albumDir = new File(appAlbumDir, albumName);
                boolean exists = albumDir.exists() && albumDir.isDirectory();
                mainHandler.post(() -> result.success(exists));
            } catch (Exception e) {
                mainHandler.post(() -> result.error("CHECK_ERROR", e.getMessage(), null));
            }
        });
    }

    private void permanentlyDelete(MethodCall call, MethodChannel.Result result) {
        List<String> assetIdList = call.argument("assetIds");
        if (assetIdList == null || assetIdList.isEmpty()) {
            result.error("INVALID_ARGS", "assetIds list is empty or null", null);
            return;
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("UNSUPPORTED_VERSION", "Requires Android 11+", null);
            return;
        }

        this.pendingResult = result;

        try {
            List<Uri> uris = new ArrayList<>();
            for (String assetId : assetIdList) {
                uris.add(getUriFromAssetId(assetId));
            }

            PendingIntent pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris);
            activity.startIntentSenderForResult(pendingIntent.getIntentSender(),
                    RequestCodes.DELETE_REQUEST_CODE, null, 0, 0, 0);
        } catch (IntentSender.SendIntentException | RuntimeException e) {
            result.error("DELETE_FAILED", e.getMessage(), null);
            this.pendingResult = null;
        }
    }

    /**
     * Helper method to get uri from asset id
     * <br>
     * <br>
     * MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
     * content://media/external_primary/images/media
     * <br>
     * <br>
     * MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
     * content://media/external_primary/video/media
     * <br>
     * <br>
     * MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_INTERNAL)
     * content://media/internal/images/media
     * <br>
     * <br>
     * MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_INTERNAL)
     * content://media/internal/video/media
     * <br>
     * <br>
     * MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
     * content://media/external/video/media
     * <br>
     * <br>
     * MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
     * content://media/external/images/media
     */
    private Uri getUriFromAssetId(String assetId) {
        long assetIdLong = Long.parseLong(assetId);
        try {
            Uri imageBaseUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
            return ContentUris.withAppendedId(imageBaseUri, assetIdLong);
        } catch (RuntimeException e) {
            Uri videoBaseUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
            return ContentUris.withAppendedId(videoBaseUri, assetIdLong);
        }
    }

    public void handleActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RequestCodes.DELETE_REQUEST_CODE) {
            if (pendingResult != null) {
                if (resultCode == Activity.RESULT_OK) {
                    pendingResult.success(true);
                } else {
                    pendingResult.error("PERMISSION_DENIED", "User denied delete access", null);
                }
                pendingResult = null;
            }
        }
    }
}
