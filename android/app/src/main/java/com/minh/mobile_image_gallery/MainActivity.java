package com.minh.mobile_image_gallery;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String METHOD_CHANNEL = "com.minh.mobile_image_gallery/media_channel";
    private static final String EVENT_CHANNEL = "com.minh.mobile_image_gallery/media_event_channel";
    private GalleryMethodHandler galleryMethodHandler;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        BinaryMessenger binaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();

        galleryMethodHandler = new GalleryMethodHandler(this);
        new MethodChannel(binaryMessenger, METHOD_CHANNEL)
                .setMethodCallHandler(galleryMethodHandler);

        MediaEditStreamHandler mediaEditStreamHandler = new MediaEditStreamHandler(this);
        new EventChannel(binaryMessenger, EVENT_CHANNEL).setStreamHandler(mediaEditStreamHandler);
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (galleryMethodHandler != null) {
            galleryMethodHandler.handleActivityResult(requestCode, resultCode, data);
        }
    }
}
