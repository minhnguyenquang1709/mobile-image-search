package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Intent;
import android.content.IntentSender;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import com.minh.mobile_image_gallery.constants.MethodNames;
import com.minh.mobile_image_gallery.constants.RequestCodes;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.logging.Level;
import java.util.logging.Logger;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class GalleryMethodHandler implements MethodChannel.MethodCallHandler {
    public GalleryMethodHandler(Activity activity) {
        this.activity = activity;
        this.contentResolver = activity.getContentResolver();
//        this.bulkOpManager = new BulkOperationManager(activity);
        logger = Logger.getLogger("MethodChannelHandler");
    }

    private final Activity activity;
    private final ContentResolver contentResolver;

    private final Logger logger;
//    private final BulkOperationManager bulkOpManager;

    private MethodChannel.Result pendingResult = null;
    private String pendingAlbumName = null;
    private List<Uri> pendingUris = null;

    private final ExecutorService executorService = Executors.newFixedThreadPool(4);
    private final Handler threadMessageHandler = new Handler(Looper.getMainLooper());

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        // debug
        this.logger.log(Level.INFO, call.arguments.toString());

        if (call.method.equals(MethodNames.createAlbum)) {
            String albumName = call.argument("albumName");
            this.logger.log(Level.INFO, String.format("Create album named '%s'", albumName));
            List<Map<String, Object>> mediaList = call.argument("mediaList");
            createAlbum(albumName, mediaList, result);
        }
        // else if (call.method.equals(MethodNames.moveMediaToTrash)) {
        // List<Map<String, Object>> mediaList = call.argument("mediaList");
        // moveMediaToTrash(mediaList, result);
        // }
        else if (call.method.equals(MethodNames.permanentlyDelete)) {
            List<String> assetIdList = call.argument("assetIds");
            this.permanentlyDelete(assetIdList, result);
        } else {
            result.notImplemented();
        }
    }

    /**
     *
     *
     */
    private Uri getUriFromAssetId(String assetId) {

        // Uri imagePrimaryContentUri =
        // MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); //
        // content://media/external_primary/images/media
        // Uri videoPrimaryContentUri =
        // MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); //
        // content://media/external_primary/video/media
        // Uri imageInternalContentUri =
        // MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_INTERNAL); //
        // content://media/internal/images/media
        // Uri videoInternalContentUri =
        // MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_INTERNAL); //
        // content://media/internal/video/media

        long assetIdLong;
        try {
            assetIdLong = Long.parseLong(assetId);
        } catch (RuntimeException e) {
            throw new RuntimeException(e);
        }

        Uri assetUri;

        try {
            Uri imageBaseUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL); // content://media/external/images/media
            assetUri = ContentUris.withAppendedId(imageBaseUri, assetIdLong);
        } catch (RuntimeException e) {
            Uri videoBaseUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL); // content://media/external/video/media
            assetUri = ContentUris.withAppendedId(videoBaseUri, assetIdLong);
        }

        return assetUri;
    }

    private void permanentlyDelete(List<String> assetIdList, MethodChannel.Result result) {
        this.logger.log(Level.INFO, String.format("Start permanently deleting media: %s", assetIdList.toString()));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                this.pendingResult = result;
                List<Uri> uris = new ArrayList<Uri>();
                for (String assetId : assetIdList) {
                    Uri assetUri = getUriFromAssetId(assetId);
                    uris.add(assetUri);
                }
                PendingIntent pendingIntent = MediaStore.createDeleteRequest(this.contentResolver, uris);
                this.activity.startIntentSenderForResult(pendingIntent.getIntentSender(), RequestCodes.DELETE_REQUEST_CODE, null, 0, 0, 0);

            } catch (RuntimeException e) {
                result.error("DELETE_FAILED", e.getMessage(), null);
                resetPendingState();
            } catch (IntentSender.SendIntentException e) {
                result.error("INTENT_ERROR", e.getMessage(), null);
                resetPendingState();
            }
        } else {
            result.error("UNSUPPORTED_VERSION", "Requires Android 11+", null);
        }
    }


    /**
     * Start creating an album and move media to it
     *
     * @overview Get uris from asset ids, send intent to ask OS to create album and
     * move media to it
     */
    private void createAlbum(String albumName, List<Map<String, Object>> mediaList, MethodChannel.Result result) {
        executorService.execute(() -> {
            try {
                List<Uri> uris = new ArrayList<Uri>();
                for (Map<String, Object> media : mediaList) {
                    try {
                        final MediaAsset mediaAsset = new MediaAsset((long) media.get("assetId"),
                                (int) media.get("mediaType"));
                        Uri mediaUri = getUriFromMediaAsset(mediaAsset);
                        uris.add(mediaUri);
                    } catch (Exception e) {
                        if (e instanceof ClassCastException) {
                            continue;
                        }
                    }
                }

                if (uris.isEmpty()) {
                    threadMessageHandler.post(() -> result.error("EMPTY_LIST", "No media items provided", null));
                    return;
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    this.pendingResult = result;
                    this.pendingAlbumName = albumName;
                    this.pendingUris = uris;

                    PendingIntent pendingIntent = MediaStore.createWriteRequest(contentResolver, uris);
                    threadMessageHandler.post(() -> {
                        try {
                            activity.startIntentSenderForResult(pendingIntent.getIntentSender(),
                                    RequestCodes.CREATE_ALBUM_REQUEST_CODE, null, 0, 0, 0);
                        } catch (Exception e) {
                            pendingResult.error("INTENT_ERROR", e.getMessage(), null);
                            resetPendingState();
                        }
                    });
                } else {
                    threadMessageHandler.post(() -> result.error("NOT_SUPPORTED",
                            "Android version not supported for this operation yet", null));
                }
            } catch (Exception e) {
                threadMessageHandler.post(() -> result.error("CREATE_ALBUM_FAILED", e.getMessage(), null));
            }
        });
    }

    /**
     * Start moving media to album
     */
    private void moveMediaToAlbum(String albumName, List<Map<String, Object>> mediaList, MethodChannel.Result result) {
        executorService.execute(() -> {

        });
    }

    /**
     * Start moving media to trash
     */
    // private void moveMediaToTrash(List<Map<String, Object>> mediaList,
    // MethodChannel.Result result) {
    // executorService.execute(() -> {
    // try {
    // if (this.pendingResult != null) {
    // handler.post(() -> result.error("ALREADY_IN_PROGRESS", "Another operation
    // already in progress", null));
    // return;
    // }
    //
    // List<Uri> uris = new ArrayList<Uri>();
    // for (Map<String, Object> media : mediaList) {
    //
    //
    // }
    //
    // if (uris.isEmpty()) {
    // handler.post(() -> result.error("EMPTY_LIST", "No media items provided",
    // null));
    // return;
    // }
    //
    // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
    // this.pendingResult = result;
    // this.pendingUris = uris;
    //
    // PendingIntent pendingIntent = MediaStore.createTrashRequest(contentResolver,
    // uris, true);
    // handler.post(() -> {
    // try {
    // activity.startIntentSenderForResult(pendingIntent.getIntentSender(),
    // RequestCodes.MOVE_MEDIA_TO_TRASH, null, 0, 0, 0);
    // } catch (Exception e) {
    // pendingResult.error("INTENT_ERROR", e.getMessage(), null);
    // resetPendingState();
    // }
    // });
    // }
    // } catch (Exception e) {
    // handler.post(() -> result.error("MOVE_TO_TRASH_FAILED", e.getMessage(),
    // null));
    // }
    // });
    // }

    /**
     * Helper method to get uri from asset id
     */
    private Uri getUriFromMediaAsset(MediaAsset mediaAsset) {

        // Uri imagePrimaryContentUri =
        // MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); //
        // content://media/external_primary/images/media
        // Uri videoPrimaryContentUri =
        // MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); //
        // content://media/external_primary/video/media
        // Uri imageInternalContentUri =
        // MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_INTERNAL); //
        // content://media/internal/images/media
        // Uri videoInternalContentUri =
        // MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_INTERNAL); //
        // content://media/internal/video/media

        Uri baseUri = mediaAsset.type == 1
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL) // content://media/external/video/media
                : MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL); // content://media/external/images/media

        return ContentUris.withAppendedId(baseUri, mediaAsset.id);
    }

    public void handleActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RequestCodes.CREATE_ALBUM_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                handleMoveMediaToAlbum();
            } else {
                if (pendingResult != null) {
                    pendingResult.error("PERMISSION_DENIED", "User denied write access", null);
                    resetPendingState();
                }
            }
        } else if (requestCode == RequestCodes.DELETE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                if (pendingResult != null) {
                    pendingResult.success(true);
                    resetPendingState();
                }
            } else {
                if (pendingResult != null) {
                    pendingResult.error("PERMISSION_DENIED", "User denied delete access", null);
                    resetPendingState();
                }
            }
        }

        // if (requestCode == RequestCodes.MOVE_MEDIA_TO_TRASH) {
        // if (resultCode == Activity.RESULT_OK) {
        // handleMoveMediaToTrash();
        // } else {
        // if (pendingResult != null) {
        // pendingResult.error("PERMISSION_DENIED", "User denied the operation", null);
        // resetPendingState();
        // }
        // }
        // }
    }

    private void handleMoveMediaToAlbum() {
        executorService.execute(() -> {
            for (Uri uri : pendingUris) {
                try {
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.MediaColumns.RELATIVE_PATH, "DCIM/" + pendingAlbumName);
                    contentResolver.update(uri, values, null, null);
                } catch (Exception e) {
                    threadMessageHandler.post(() -> {
                        if (pendingResult != null) {
                            pendingResult.error("UPDATE_FAILED", e.getMessage(), null);
                            resetPendingState();
                        }
                    });
                }
            }
            threadMessageHandler.post(() -> {
                if (pendingResult != null) {
                    pendingResult.success(true);
                    resetPendingState();
                }
            });

        });
    }

    // private void handleMoveMediaToTrash() {
    // executorService.execute(() -> {
    // try {
    //
    // } catch (Exception e) {
    //
    // }
    // });
    // }

    private void resetPendingState() {
        pendingResult = null;
        pendingAlbumName = null;
        pendingUris = null;
    }
}
