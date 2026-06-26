package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;

public class MediaEditStreamHandler implements EventChannel.StreamHandler {
    private EventChannel.EventSink eventSink;
    private Handler mainThreadHandler;

    private Activity activity;

    // set when the Dart side cancels the subscription; checked in the copy loop
    private volatile boolean cancelled = false;

    private final ExecutorService executorService = Executors.newSingleThreadExecutor();


    public MediaEditStreamHandler(Activity activity) {
        this.activity = activity;
    }


    @Override
    public void onListen(Object arguments, EventChannel.EventSink eventSink) {
        // run on main thread
        this.eventSink = eventSink;
        this.mainThreadHandler = new Handler(Looper.getMainLooper());
        this.cancelled = false;

        if (arguments instanceof Map) {
            Map<String, Object> args = (Map<String, Object>) arguments;
            String operation = args.get("operation").toString();

            if (operation.equals("moveMediaToAlbum")) {
                String relativePath = args.get("relativePath").toString();

                List<Map<String, Object>> mediaList = (List<Map<String, Object>>) args.get("mediaList");
                move(relativePath, mediaList);
            }
        }
    }

    @Override
    public void onCancel(Object arguments) {
        this.cancelled = true;
        this.eventSink = null;
    }

    /**
     * Query original DISPLAY_NAME, MIME_TYPE and DATE_TAKEN via ContentResolver.
     * Returns {displayName, mimeType, dateTaken} (dateTaken may be null).
     */
    private String[] getMediaInfo(ContentResolver resolver, Uri uri) {
        String[] projection = {
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.DATE_TAKEN
        };
        try (android.database.Cursor cursor = resolver.query(uri, projection, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                long dateTaken = cursor.getLong(2);
                return new String[]{
                        cursor.getString(0), // DISPLAY_NAME
                        cursor.getString(1), // MIME_TYPE
                        dateTaken > 0 ? String.valueOf(dateTaken) : null // DATE_TAKEN (ms)
                };
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    private Uri getUriFromAssetId(long assetId, int mediaType) {
        Uri baseUri = mediaType == 1
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL) // content://media/external/video/media
                : MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL); // content://media/external/images/media

        return ContentUris.withAppendedId(baseUri, assetId);
    }

    /** The collection a new copy is inserted into, per media type. */
    private Uri getDestCollectionUri(int mediaType) {
        return mediaType == 1
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                : MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
    }

    private void emitEvent(Map<String, Object> event) {
        if (mainThreadHandler == null) return;
        mainThreadHandler.post(() -> {
            if (eventSink != null) {
                eventSink.success(event);
            }
        });
    }

    /**
     * Copy each file into the album folder (one progress event per file). The
     * originals are NOT deleted here — after all copies are done the Dart side
     * runs a single batch delete with user consent (see GalleryMethodHandler).
     */
    private void move(String relativePath, List<Map<String, Object>> mediaList) {
        executorService.execute(() -> {
            final int total = mediaList.size();

            // OS version check — RELATIVE_PATH / IS_PENDING require Android 11 (R)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                Map<String, Object> error = new HashMap<>();
                error.put("state", "error");
                error.put("index", 0);
                error.put("total", total);
                error.put("message", "Moving media to album requires Android 11+");
                emitEvent(error);
                return;
            }

            ContentResolver resolver = this.activity.getContentResolver();
            // destination folder is resolved Dart-side to the album's existing
            // bucket (e.g. "Pictures/A/") so we don't create a duplicate folder
            final String destRelativePath = relativePath;

            // copies created so far, so we can roll back this run on a mid-copy error
            List<Uri> createdCopies = new ArrayList<>();

            for (int i = 0; i < total; i++) {
                if (cancelled) return;

                Map<String, Object> media = mediaList.get(i);
                long assetId = ((Number) media.get("assetId")).longValue();
                int mediaType = ((Number) media.get("mediaType")).intValue();
                Uri srcUri = getUriFromAssetId(assetId, mediaType);

                try {
                    String[] info = getMediaInfo(resolver, srcUri);
                    if (info == null) {
                        throw new Exception("Source metadata not found");
                    }
                    String displayName = info[0];
                    String mimeType = info[1];
                    String dateTaken = info[2];

                    // insert the destination item as pending while we stream bytes
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
                    if (mimeType != null) {
                        values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType);
                    }
                    values.put(MediaStore.MediaColumns.RELATIVE_PATH, destRelativePath);
                    // DATE_TAKEN is what PhotoManager groups by — copy it or the moved
                    // item jumps to "today". DATE_ADDED resets on insert (expected).
                    if (dateTaken != null) {
                        values.put(MediaStore.MediaColumns.DATE_TAKEN, Long.parseLong(dateTaken));
                    }
                    values.put(MediaStore.MediaColumns.IS_PENDING, 1);

                    Uri destUri = resolver.insert(getDestCollectionUri(mediaType), values);
                    if (destUri == null) {
                        throw new Exception("Failed to create destination item");
                    }
                    createdCopies.add(destUri);

                    // stream the bytes (buffered, never read the whole file into memory)
                    try (InputStream in = resolver.openInputStream(srcUri);
                         OutputStream out = resolver.openOutputStream(destUri)) {
                        if (in == null || out == null) {
                            throw new Exception("Failed to open streams");
                        }
                        byte[] buffer = new byte[8192];
                        int len;
                        while ((len = in.read(buffer)) != -1) {
                            if (cancelled) return;
                            out.write(buffer, 0, len);
                        }
                    }

                    // publish the copy
                    ContentValues done = new ContentValues();
                    done.put(MediaStore.MediaColumns.IS_PENDING, 0);
                    resolver.update(destUri, done, null, null);

                    long newAssetId = ContentUris.parseId(destUri);

                    Map<String, Object> event = new HashMap<>();
                    event.put("state", "copying");
                    event.put("index", i);
                    event.put("total", total);
                    event.put("assetId", assetId);
                    event.put("newAssetId", newAssetId);
                    emitEvent(event);
                } catch (Exception e) {
                    e.printStackTrace();
                    // roll back the copies made in this run so we don't leave duplicates
                    for (Uri copy : createdCopies) {
                        try {
                            resolver.delete(copy, null, null);
                        } catch (Exception ignored) {
                        }
                    }

                    Map<String, Object> error = new HashMap<>();
                    error.put("state", "error");
                    error.put("index", i);
                    error.put("total", total);
                    error.put("assetId", assetId);
                    error.put("message", e.getMessage());
                    emitEvent(error);
                    return;
                }
            }

            if (cancelled) return;

            // all copies done — Dart now runs the batch delete with consent
            Map<String, Object> copied = new HashMap<>();
            copied.put("state", "copied");
            copied.put("total", total);
            emitEvent(copied);
        });
    }
}
