//import android.app.Activity;
//import android.app.PendingIntent;
//import android.content.ContentResolver;
//import android.net.Uri;
//import android.os.Build;
//import android.os.Handler;
//import android.os.Looper;
//
//import com.minh.mobile_image_gallery.MediaAsset;
//
//import java.util.ArrayList;
//import java.util.HashMap;
//import java.util.List;
//import java.util.concurrent.ExecutorService;
//import java.util.concurrent.Executors;
//
//import io.flutter.plugin.common.EventChannel;
//
//public class BulkoperationManager {
//    private final Activity activity;
//    private final ContentResolver contentResolver;
//    private final ExecutorService executorService = Executors.newFixedThreadPool(2);
//    private final Handler mainHandler = new Handler(Looper.getMainLooper());
//
//    private EventChannel.EventSink eventSink;
//
//    // store ongoing operations with a unique ID
//    private final Map<String, BulkOpContext> ops = new HashMap<>();
//
//    private BulkOpContext pendingPermissionOp = null;
//
//    public BulkoperationManager(Activity activity) {
//        this.activity = activity;
//        this.contentResolver = activity.getContentResolver();
//    }
//
//    public void setEventSink(EventChannel.EventSink eventSink) {
//        this.eventSink = eventSink;
//    }
//
//    // group: move to trash
//
//    /**
//     * Starts the move to trash operation for the given assets
//     *
//     * @param opId
//     * @param assets
//     */
//    public void startMoveToTrash(String opId, List<MediaAsset> assets) {
//        // android 11+
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
//            emitFailed(opId, assets.size(), "NOT_SUPPORTED");
//        }
//
//        List<Uri> uris = new ArrayList<>();
//        for (MediaAsset a : assets) {
//            uris.add(getUriFromAssetId(a));
//        }
//
//        BulkOpContext ctx = new BulkOpContext(opId, assets.size(), uris);
//        ops.put(opId, ctx);
//
//        PendingIntent pendingIntent = MediaStore.createTrashRequest(contentResolver, uris, true);
//        pendingPermissionOp = ctx;
//
//        try {
//            activity.startIntentSenderForResult(
//                    pendingIntent.getIntentSender(),
//                    RequestCodes.MOVE_MEDIA_TO_TRASH,
//                    null, 0, 0, 0);
//        } catch (Exception e) {
//            emitFailed(opId, assets.size(), e.getMessage());
//        }
//    }
//
//    public void handleActivityResult(int requestCode, int resultCode) {
//        if (requestCode == RequestCodes.MOVE_MEDIA_TO_TRASH) {
//            if (pendingPermissionOp == null)
//                return;
//
//            if (resultCode == Activity.RESULT_OK) {
//                processMoveToTrash(pendingPermissionOp);
//            } else {
//                emitCanceled(pendingPermissionOp);
//            }
//            pendingPermissionOp = null;
//        }
//    }
//
//    private void processMoveToTrash(BulkOpContext ctx) {
//        executor.execute(() -> {
//            int processed = 0;
//            for (Uri uri : ctx.uris) {
//                if (ctx.cancelled.get()) {
//                    emitCanceled(ctx);
//                    return;
//                }
//                try {
//                    ContentValues values = new ContentValues();
//                    values.put(MediaStore.MediaColumns.IS_TRASHED, 1);
//                    contentResolver.update(uri, values, null, null);
//                    processed++;
//                    emitProgress(ctx.opId, processed, ctx.total, "running", null);
//                } catch (Exception e) {
//                    emitFailed(ctx.opId, ctx.total, e.getMessage());
//                    return;
//                }
//            }
//            emitCompleted(ctx.opId, processed, ctx.total);
//        });
//    }
//
//    private void emitProgress(String opId, int processed, int total, String status, String error) {
//        if (eventSink == null)
//            return;
//        Map<String, Object> payload = new HashMap<>();
//        payload.put("opId", opId);
//        payload.put("processedCount", processed);
//        payload.put("totalCount", total);
//        payload.put("status", status);
//        payload.put("errorMessage", error);
//        mainHandler.post(() -> eventSink.success(payload));
//    }
//
//    private void emitCompleted(String opId, int processed, int total) {
//        emitProgress(opId, processed, total, "completed", null);
//    }
//
//    private void emitFailed(String opId, int total, String error) {
//        emitProgress(opId, 0, total, "failed", error);
//    }
//
//    private void emitCanceled(BulkOpContext ctx) {
//        emitProgress(ctx.opId, ctx.processed.get(), ctx.total, "canceled", null);
//    }
//
//    // group: store from trash
//}
