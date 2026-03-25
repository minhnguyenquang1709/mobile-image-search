package com.example.mobile_image_search;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import kotlin.NotImplementedError;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;

import java.util.ArrayList;
import java.util.List;

class RequestCode {
    public static final int DELETE_REQUEST_CODE = 100;
}


public class MainActivity extends FlutterActivity {
    private static final String _CHANNEL = "platform_image";

    MethodChannel.Result pendingResult = null;

    private Uri mediaCollection;


    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            mediaCollection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL);
        } else {
            mediaCollection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
        }

        System.out.println("MainActivity onCreate");
        System.out.println("Build: " + Build.VERSION.SDK_INT);
        System.out.println("mediaCollection URI: " + mediaCollection.toString());
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), _CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getBatteryLevel")) {
                                int batteryLevel = getBatteryLevel();
                                if (batteryLevel != -1) {
                                    result.success(batteryLevel);
                                } else {
                                    result.error("UNAVAILABLE", "Battery level not available.", null);
                                }
                            } else if (call.method.equals("deleteImages")) {
                                ArrayList<String> ids = call.argument("ids");
                                System.out.println("ids: " + ids.toString());

                                if (ids == null || ids.isEmpty()) {
                                    result.error("BAD_ARGS", "Image id list is empty.", null);
                                    return;
                                }

                                this.pendingResult = result;
                                exampleRequestPermanentlyDeleteImage(ids);

                            } else if (call.method.equals("createAlbum")) {
                                String albumName = call.argument("albumName");
                                ArrayList<String> assetIds = call.argument("assetIds");

                                this.pendingResult = result;
                                boolean success = createAlbum(albumName, assetIds);


                            } else if (call.method.equals("moveImagesToAlbum")) {
                            } else if (call.method.equals("moveImagesToTrash")) {
                            } else if (call.method.equals("deleteAlbum")) {
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }


    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == RequestCode.DELETE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingResult.success(true);
            } else {
                pendingResult.error("FAILED", "Delete images failed.", null);
            }
            pendingResult = null;
        }
    }

    private void exampleRequestPermanentlyDeleteImage(ArrayList<String> ids) {
        long[] idLongs = new long[ids.size()];
        for (int i = 0; i < ids.size(); i++) {
            idLongs[i] = Long.parseLong(ids.get(i));
        }

        Context appContext = getApplicationContext();
        ContentResolver resolver = appContext.getContentResolver();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            List<Uri> imageUris = new ArrayList<>();

            for (int i = 0; i < ids.size(); i++) {
                Uri imageUri = MediaStore.Images.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY,
                        idLongs[i]
                );
                imageUris.add(imageUri);

//        // SQL 'WHERE' clause with placeholder variables '?'
//        String selection = null;
//
//        // Selection arguments: values of placeholder variables
//        String[] selectionArgs = null;
//
//        // Sort order
//        String sortOrder = null;
            }

            // start intent
            PendingIntent pendingIntent = MediaStore.createDeleteRequest(resolver, imageUris);
            try {
                startIntentSenderForResult(pendingIntent.getIntentSender(), RequestCode.DELETE_REQUEST_CODE, null, 0, 0, 0);
            } catch (Exception e) {
                this.pendingResult.error("FAILED", "Delete images failed.", null);
            }
        } else {
            // handle other android versions
        }
    }

    private int getBatteryLevel() {
        int batteryLevel = -1;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            BatteryManager batteryManager = (BatteryManager) getSystemService(BATTERY_SERVICE);
            batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        } else {
            Intent intent = new ContextWrapper(getApplicationContext()).
                    registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            batteryLevel = (intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100) /
                    intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        }

        return batteryLevel;
    }

    private boolean createAlbum(String albumName, ArrayList<String> assetIds) {
        throw new NotImplementedError("createAlbum");
    }

    private boolean moveImagesToAlbum(String albumName, String albumId, ArrayList<String> assetIds) {
        throw new NotImplementedError("moveImagesToAlbum");
    }

    private boolean moveImagesToTrash(ArrayList<String> assetIds) {
        throw new NotImplementedError("moveImagesToTrash");
    }

    private boolean deleteAlbum(String albumName, String albumId, boolean deleteImages) {
        throw new NotImplementedError("deleteAlbum");
    }
}
