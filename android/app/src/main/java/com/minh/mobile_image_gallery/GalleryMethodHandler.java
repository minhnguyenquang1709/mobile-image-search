package com.minh.mobile_image_gallery;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.Intent;
import android.content.IntentSender;
import android.content.UriPermission;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
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

    // delete-consent flow for a move: the result to reply to, plus the copies
    // created so they can be rolled back if the user denies the delete. SAF copies
    // carry a doc Uri (rolled back via DocumentsContract); MediaStore copies a null
    private MethodChannel.Result pendingMoveResult;
    private List<Uri> pendingMoveCopies;
    private List<String> pendingMoveDocUris;

    // SAF folder-grant flow: the result to reply to + the asked folder
    private MethodChannel.Result pendingFolderResult;
    private String pendingFolderRelativePath;

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
            case MethodNames.permanentlyDelete:
                permanentlyDeleteMedia(call, result);
                break;
            case MethodNames.deleteAlbum:
                deleteAlbum(call, result);
                break;
            case MethodNames.confirmDeleteOriginals:
                confirmDeleteOriginals(call, result);
                break;
            case MethodNames.ensureFolderAccess:
                ensureFolderAccess(call, result);
                break;
            case MethodNames.deleteAlbumDirectory:
                deleteAlbumDirectory(call, result);
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
                // No mkdirs() - MediaStore creates the DCIM/<title> bucket lazily on the
                // first move. We just compute the BUCKET_ID it will assign for the DB record.
                File dcimDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM);
                File newAlbumDir = new File(dcimDir, albumTitle);

                String bucketId = String.valueOf(newAlbumDir.getAbsolutePath().toLowerCase().hashCode());
                mainHandler.post(() -> result.success(bucketId));
            } catch (Exception e) {
                mainHandler.post(() -> result.error("CREATE_ERROR", e.getMessage(), null));
            }
        });
    }

    /**
     * Permanently delete media assets given their asset IDs, remove them from
     * device storage.
     * 
     * @param call
     * @param result
     */
    private void permanentlyDeleteMedia(MethodCall call, MethodChannel.Result result) {
        List<String> assetIdList = call.argument("assetIds");
        // optional [{assetId, mediaType}]
        // Uris (assetIds alone assume images, which fails for videos)
        List<java.util.Map<String, Object>> mediaList = call.argument("mediaList");

        boolean hasAssetIds = assetIdList != null && !assetIdList.isEmpty();
        boolean hasMediaList = mediaList != null && !mediaList.isEmpty();
        if (!hasAssetIds && !hasMediaList) {
            result.error("INVALID_ARGS", "no assetIds / mediaList provided", null);
            return;
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("UNSUPPORTED_VERSION", "Requires Android 11+", null);
            return;
        }

        this.pendingResult = result;

        try {
            List<Uri> uris = new ArrayList<>();
            if (hasMediaList) {
                for (java.util.Map<String, Object> media : mediaList) {
                    long id = ((Number) media.get("assetId")).longValue();
                    int mediaType = ((Number) media.get("mediaType")).intValue();
                    uris.add(getUriFromAssetId(id, mediaType));
                }
            } else {
                for (String assetId : assetIdList) {
                    uris.add(getUriFromAssetId(assetId));
                }
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
     * Batch-delete the ORIGINAL media after a move, with user consent.
     *
     * Args:
     * - assetIds: original ids to delete (List<String>)
     * - newMediaList: the copies just created [{assetId, mediaType}] (for rollback)
     */
    private void confirmDeleteOriginals(MethodCall call, MethodChannel.Result result) {
        List<String> assetIdList = call.argument("assetIds");
        List<java.util.Map<String, Object>> newMediaList = call.argument("newMediaList");

        if (assetIdList == null || assetIdList.isEmpty()) {
            result.error("INVALID_ARGS", "assetIds list is empty or null", null);
            return;
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("UNSUPPORTED_VERSION", "Requires Android 11+", null);
            return;
        }

        this.pendingMoveResult = result;

        // remember the created copies so can roll them back on denial. SAF copies
        // also carry a doc Uri (deleted via DocumentsContract instead of MediaStore).
        this.pendingMoveCopies = new ArrayList<>();
        this.pendingMoveDocUris = new ArrayList<>();
        if (newMediaList != null) {
            for (java.util.Map<String, Object> media : newMediaList) {
                long newId = ((Number) media.get("assetId")).longValue();
                int mediaType = ((Number) media.get("mediaType")).intValue();
                this.pendingMoveCopies.add(getUriFromAssetId(newId, mediaType));
                Object docUri = media.get("docUri");
                this.pendingMoveDocUris.add(docUri != null ? docUri.toString() : null);
            }
        }

        try {
            List<Uri> uris = new ArrayList<>();
            for (int i = 0; i < assetIdList.size(); i++) {
                long originalId = Long.parseLong(assetIdList.get(i));
                int mediaType = 0;
                if (newMediaList != null && i < newMediaList.size()) {
                    mediaType = ((Number) newMediaList.get(i).get("mediaType")).intValue();
                }
                uris.add(getUriFromAssetId(originalId, mediaType));
            }

            PendingIntent pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris);
            activity.startIntentSenderForResult(pendingIntent.getIntentSender(),
                    RequestCodes.MOVE_DELETE_REQUEST_CODE, null, 0, 0, 0);
        } catch (IntentSender.SendIntentException | RuntimeException e) {
            result.error("DELETE_FAILED", e.getMessage(), null);
            this.pendingMoveResult = null;
            this.pendingMoveCopies = null;
            this.pendingMoveDocUris = null;
        }
    }

    /**
     * Ensure a persisted SAF write grant for the folder at relativePath. Returns
     * the
     * granted tree Uri string, or replies null if the user cancels / picks another
     * folder.
     */
    private void ensureFolderAccess(MethodCall call, MethodChannel.Result result) {
        String relativePath = call.argument("relativePath");
        if (relativePath == null || relativePath.isEmpty()) {
            result.error("INVALID_ARGS", "relativePath is empty or null", null);
            return;
        }

        // normalize: drop leading/trailing slashes (RELATIVE_PATH is e.g. "folder/")
        String normalized = relativePath;
        while (normalized.startsWith("/")) {
            normalized = normalized.substring(1);
        }
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        String documentId = "primary:" + normalized;
        Uri targetTreeUri = DocumentsContract.buildTreeDocumentUri(
                "com.android.externalstorage.documents", documentId);

        // already granted: reuse the persisted permission, no prompt
        for (UriPermission perm : contentResolver.getPersistedUriPermissions()) {
            if (perm.isWritePermission() && perm.getUri().equals(targetTreeUri)) {
                result.success(targetTreeUri.toString());
                return;
            }
        }

        // not granted: launch the folder picker, reply in handleActivityResult
        this.pendingFolderResult = result;
        this.pendingFolderRelativePath = normalized;

        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // pre-point the picker at the target folder. DocumentsUI navigates a
            // *document* Uri (not a bare tree Uri), so build it from the tree.
            Uri initialUri = DocumentsContract.buildDocumentUriUsingTree(targetTreeUri, documentId);
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri);
        }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try {
            activity.startActivityForResult(intent, RequestCodes.SAF_TREE_REQUEST_CODE);
        } catch (RuntimeException e) {
            result.error("SAF_FAILED", e.getMessage(), null);
            this.pendingFolderResult = null;
            this.pendingFolderRelativePath = null;
        }
    }

    /**
     * Delete the target directory (album) given its BUCKET_ID.
     *
     * @param call
     * @param result
     */
    private void deleteAlbum(MethodCall call, MethodChannel.Result result) {
        String albumId = call.argument("albumId");
        Boolean deleteAssets = call.argument("deleteAssets");

        executor.execute(() -> {
            try {

            } catch (Exception e) {
                mainHandler.post(() -> result.error("DELETE_ALBUM_FAILED", e.getMessage(), null));
            }
        });
    }

    /**
     * Try to delete the album directory granted as [treeUri] (SAF). Only deletes
     * it when empty, any leftover child (a non-media file/folder) -> leave the
     * folder.
     * The caller deletes the media via MediaStore first, so an empty directory
     * here means it held only media. Replies true if deleted, false if left.
     */
    private void deleteAlbumDirectory(MethodCall call, MethodChannel.Result result) {
        String treeUriStr = call.argument("treeUri");
        if (treeUriStr == null || treeUriStr.isEmpty()) {
            result.error("INVALID_ARGS", "treeUri is empty or null", null);
            return;
        }

        executor.execute(() -> {
            try {
                Uri treeUri = Uri.parse(treeUriStr);
                String docId = DocumentsContract.getTreeDocumentId(treeUri);
                Uri dirDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId);
                Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId);

                boolean hasChild = false;
                try (Cursor cursor = contentResolver.query(childrenUri,
                        new String[] { DocumentsContract.Document.COLUMN_DOCUMENT_ID },
                        null, null, null)) {
                    if (cursor != null && cursor.moveToFirst()) {
                        hasChild = true; // leftover non-media file -> leave the directory
                    }
                }

                boolean deleted = false;
                if (!hasChild) {
                    deleted = DocumentsContract.deleteDocument(contentResolver, dirDocUri);
                }
                final boolean res = deleted;
                mainHandler.post(() -> result.success(res));
            } catch (Exception e) {
                mainHandler.post(() -> result.error("DELETE_DIR_FAILED", e.getMessage(), null));
            }
        });
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

    /** Build a content Uri for a known media type (1 = video, else image). */
    private Uri getUriFromAssetId(long assetId, int mediaType) {
        Uri baseUri = mediaType == 1
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                : MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
        return ContentUris.withAppendedId(baseUri, assetId);
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
        } else if (requestCode == RequestCodes.MOVE_DELETE_REQUEST_CODE) {
            if (pendingMoveResult != null) {
                if (resultCode == Activity.RESULT_OK) {
                    // originals deleted by the system - move complete
                    pendingMoveResult.success(true);
                } else {
                    // user denied: roll back the copies.
                    // SAF copies go through DocumentsContract; the
                    // rest are app-owned MediaStore items (no consent needed).
                    if (pendingMoveCopies != null) {
                        for (int i = 0; i < pendingMoveCopies.size(); i++) {
                            String docUri = (pendingMoveDocUris != null && i < pendingMoveDocUris.size())
                                    ? pendingMoveDocUris.get(i)
                                    : null;
                            try {
                                if (docUri != null) {
                                    DocumentsContract.deleteDocument(contentResolver, Uri.parse(docUri));
                                } else {
                                    contentResolver.delete(pendingMoveCopies.get(i), null, null);
                                }
                            } catch (Exception ignored) {
                            }
                        }
                    }
                    pendingMoveResult.error("PERMISSION_DENIED", "User denied delete access", null);
                }
                pendingMoveResult = null;
                pendingMoveCopies = null;
                pendingMoveDocUris = null;
            }
        } else if (requestCode == RequestCodes.SAF_TREE_REQUEST_CODE) {
            if (pendingFolderResult != null) {
                if (resultCode == Activity.RESULT_OK && data != null && data.getData() != null) {
                    Uri treeUri = data.getData();
                    try {
                        contentResolver.takePersistableUriPermission(treeUri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                                        | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                    } catch (Exception ignored) {
                    }

                    // verify the user granted the target folder (last segment)
                    String treeDocId = DocumentsContract.getTreeDocumentId(treeUri);
                    String grantedName = lastSegment(treeDocId);
                    String requestedName = lastSegment(pendingFolderRelativePath);
                    if (grantedName.equals(requestedName)) {
                        pendingFolderResult.success(treeUri.toString());
                    } else {
                        // user picked a different folder - Dart treats null as denied
                        // TODO: show a clearer message to the user
                        pendingFolderResult.success(null);
                    }
                } else {
                    pendingFolderResult.success(null);
                }
                pendingFolderResult = null;
                pendingFolderRelativePath = null;
            }
        }
    }

    /**
     * Last path segment of a document id / relative path.
     */
    private String lastSegment(String value) {
        if (value == null) {
            return "";
        }
        int slash = value.lastIndexOf('/');
        if (slash >= 0) {
            return value.substring(slash + 1);
        }
        int colon = value.lastIndexOf(':');
        return colon >= 0 ? value.substring(colon + 1) : value;
    }
}
