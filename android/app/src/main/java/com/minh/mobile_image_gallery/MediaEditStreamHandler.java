package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;

public class MediaEditStreamHandler implements EventChannel.StreamHandler {
    private EventChannel.EventSink eventSink;
    private Handler mainThreadHandler;

    private Activity activity;

    private final ExecutorService executorService = Executors.newSingleThreadExecutor();


    public MediaEditStreamHandler(Activity activity) {
        this.activity = activity;
    }


    @Override
    public void onListen(Object arguments, EventChannel.EventSink eventSink) {
        // run on main thread
        this.eventSink = eventSink;
        this.mainThreadHandler = new Handler(Looper.getMainLooper());

        if (arguments instanceof Map) {
            Map<String, Object> args = (Map<String, Object>) arguments;
            String operation = args.get("operation").toString();

            if (operation.equals("moveMediaToAlbum")) {
                String albumName = args.get("albumName").toString();

                List<Map<String, Object>> mediaList = (List<Map<String, Object>>) args.get("mediaList");
                move(albumName, mediaList);
            }
        }
    }

    @Override
    public void onCancel(Object arguments) {
    }

    /**
     * Query original filename and mimetype via ContentResolver
     */
    private String[] getMediaInfo(ContentResolver resolver, Uri uri) {
        String[] projection = {MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.MIME_TYPE};
        try (android.database.Cursor cursor = resolver.query(uri, projection, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                return new String[]{
                        cursor.getString(0), // DISPLAY_NAME
                        cursor.getString(1)  // MIME_TYPE
                };
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    private Uri getUriFromAssetId(long assetId, int mediaType) {

        // Uri imagePrimaryContentUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); // content://media/external_primary/images/media
        // Uri videoPrimaryContentUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY); // content://media/external_primary/video/media
        // Uri imageInternalContentUri = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_INTERNAL); // content://media/internal/images/media
        // Uri videoInternalContentUri = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_INTERNAL); // content://media/internal/video/media


        Uri baseUri = mediaType == 1
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL) // content://media/external/video/media
                : MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL); // content://media/external/images/media

        return ContentUris.withAppendedId(baseUri, assetId);
    }


    /**
     * Copy media to new directory, then delete old media
     */
    private void move(String albumName, List<Map<String, Object>> mediaList) {
        executorService.execute(() -> {
            try {
                // OS version check
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                    throw new UnsupportedOperationException();
                }

                ContentResolver contentResolver = this.activity.getContentResolver();
                List<Uri> uris = new ArrayList<>();

                for (Map<String, Object> media : mediaList) {
                    Uri mediaUri = getUriFromAssetId((long) media.get("assetId"), (int) media.get("mediaType"));
                    uris.add(mediaUri);
                }
            } catch (Exception e) {
            }
        });
    }
}
