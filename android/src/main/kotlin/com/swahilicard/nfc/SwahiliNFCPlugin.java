package com.swahilicard.nfc;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * SwahiliNFCPlugin
 * Main entry point for the plugin's Java API - Using only v2 embedding
 */
public class SwahiliNFCPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private MethodChannel channel;
    private SwahiliNFCPluginKt kotlinImplementation;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        kotlinImplementation = new SwahiliNFCPluginKt();
        kotlinImplementation.setupChannels(flutterPluginBinding.getBinaryMessenger(), null);
        
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), 
                                   "com.swahilicard.nfc/android");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        kotlinImplementation.onMethodCall(call, result);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        kotlinImplementation.onAttachedToActivity(binding);
        binding.addOnNewIntentListener(kotlinImplementation);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        kotlinImplementation.onDetachedFromActivityForConfigChanges();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        kotlinImplementation.onReattachedToActivityForConfigChanges(binding);
        binding.addOnNewIntentListener(kotlinImplementation);
    }

    @Override
    public void onDetachedFromActivity() {
        kotlinImplementation.onDetachedFromActivity();
    }
}