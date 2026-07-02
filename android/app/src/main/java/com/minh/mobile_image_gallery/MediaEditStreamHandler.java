package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.provider.MediaStore;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

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
            } else if (operation.equals("moveMediaToAlbumSaf")) {
                String treeUri = args.get("treeUri").toString();

                List<Map<String, Object>> mediaList = (List<Map<String, Object>>) args.get("mediaList");
                moveSaf(Uri.parse(treeUri), mediaList);
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
     * Returns displayName, mimeType, dateTaken
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
                return new String[] {
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
        if (mainThreadHandler == null)
            return;
        mainThreadHandler.post(() -> {
            if (eventSink != null) {
                eventSink.success(event);
            }
        });
    }

    /**
     * Copy each file into the album folder (one progress event per file). The
     * originals are NOT deleted here - after all copies are done the Dart side
     * runs a single batch delete with user consent (see GalleryMethodHandler).
     */
    private void move(String relativePath, List<Map<String, Object>> mediaList) {
        executorService.execute(() -> {
            final int total = mediaList.size();

            // OS version check - RELATIVE_PATH / IS_PENDING require Android 11 (R)
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
            // destination folder is resolved in Dart to the album's existing
            // bucket (e.g. "Pictures/A/") -> avoid duplicate folder
            final String destRelativePath = relativePath;

            // copies created so far,allow rollback
            List<Uri> createdCopies = new ArrayList<>();

            for (int i = 0; i < total; i++) {
                if (cancelled)
                    return;

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

                    // insert the destination item as pending while streaming bytes
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
                    if (mimeType != null) {
                        values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType);
                    }
                    values.put(MediaStore.MediaColumns.RELATIVE_PATH, destRelativePath);
                    // DATE_TAKEN is what PhotoManager groups by - copy it or the moved
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
                            if (cancelled)
                                return;
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
                    // roll back the copies
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

            if (cancelled)
                return;

            // all copies done - Dart now runs the batch delete with consent
            Map<String, Object> copied = new HashMap<>();
            copied.put("state", "copied");
            copied.put("total", total);
            emitEvent(copied);
        });
    }

    /**
     * SAF variant of move: write each copy into the user-granted [treeUri]
     * via DocumentsContract instead of using MediaStore. Re-scan media so
     * PhotoManager sees it and
     * get its new MediaStore id.
     */
    private void moveSaf(Uri treeUri, List<Map<String, Object>> mediaList) {
        executorService.execute(() -> {
            final int total = mediaList.size();

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

            // parent document under the granted tree, where copies are created
            String treeDocId = DocumentsContract.getTreeDocumentId(treeUri);
            Uri parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocId);
            // absolute folder path, for the media scan (e.g.
            // /storage/emulated/0/mid_math_problem)
            String relativeDir = treeDocId.startsWith("primary:")
                    ? treeDocId.substring("primary:".length())
                    : treeDocId;
            String absoluteDir = "/storage/emulated/0/" + relativeDir;

            // docs created so far, allow roll back this run on a mid-copy error
            List<Uri> createdDocs = new ArrayList<>();

            for (int i = 0; i < total; i++) {
                if (cancelled)
                    return;

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
                    if (mimeType == null) {
                        mimeType = mediaType == 1 ? "video/*" : "image/*";
                    }

                    Uri destDoc = DocumentsContract.createDocument(resolver, parentDocUri, mimeType, displayName);
                    if (destDoc == null) {
                        throw new Exception("Failed to create destination file");
                    }
                    createdDocs.add(destDoc);

                    // stream the bytes (buffered, never read the whole file into memory).
                    // a verbatim copy preserves EXIF/metadata so DATE_TAKEN survives the scan.
                    try (InputStream in = resolver.openInputStream(srcUri);
                            OutputStream out = resolver.openOutputStream(destDoc)) {
                        if (in == null || out == null) {
                            throw new Exception("Failed to open streams");
                        }
                        byte[] buffer = new byte[8192];
                        int len;
                        while ((len = in.read(buffer)) != -1) {
                            if (cancelled)
                                return;
                            out.write(buffer, 0, len);
                        }
                    }

                    // register with MediaStore so PhotoManager sees it + to get the new id
                    long newAssetId = scanAndGetId(absoluteDir + "/" + displayName);

                    Map<String, Object> event = new HashMap<>();
                    event.put("state", "copying");
                    event.put("index", i);
                    event.put("total", total);
                    event.put("assetId", assetId);
                    event.put("newAssetId", newAssetId);
                    event.put("docUri", destDoc.toString());
                    emitEvent(event);
                } catch (Exception e) {
                    e.printStackTrace();
                    // roll back the copies made in this run so don't leave duplicates
                    for (Uri doc : createdDocs) {
                        try {
                            DocumentsContract.deleteDocument(resolver, doc);
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

            if (cancelled)
                return;

            Map<String, Object> copied = new HashMap<>();
            copied.put("state", "copied");
            copied.put("total", total);
            emitEvent(copied);
        });
    }

    /**
     * Media-scan [path] and return the new MediaStore id (blocks until the scan
     * finishes). Returns -1 if the scan reports no Uri.
     */
    private long scanAndGetId(String path) {
        final long[] holder = { -1L };
        final CountDownLatch latch = new CountDownLatch(1);
        MediaScannerConnection.scanFile(activity, new String[] { path }, null, (scannedPath, uri) -> {
            if (uri != null) {
                try {
                    holder[0] = ContentUris.parseId(uri);
                } catch (Exception ignored) {
                }
            }
            latch.countDown();
        });
        try {
            latch.await(10, TimeUnit.SECONDS);
        } catch (InterruptedException ignored) {
        }
        return holder[0];
    }
}
