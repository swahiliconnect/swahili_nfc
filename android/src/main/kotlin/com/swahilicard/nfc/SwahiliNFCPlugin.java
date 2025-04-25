package com.swahilicard.nfc;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * SwahiliNFCPlugin
 * Main entry point for the plugin's Java API
 */
public class SwahiliNFCPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private MethodChannel channel;
    private SwahiliNFCPluginKt kotlinImplementation;

    /**
     * Plugin registration for pre-Flutter embedding v1
     */
    public static void registerWith(Registrar registrar) {
        final SwahiliNFCPlugin instance = new SwahiliNFCPlugin();
        instance.initializePlugin(registrar.messenger(), registrar.activity());
        registrar.addOnNewIntentListener(instance.kotlinImplementation);
    }

    private void initializePlugin(io.flutter.plugin.common.BinaryMessenger messenger, 
                                android.app.Activity activity) {
        kotlinImplementation = new SwahiliNFCPluginKt();
        kotlinImplementation.setupChannels(messenger, activity);
        
        channel = new MethodChannel(messenger, "com.swahilicard.nfc/android");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        kotlinImplementation = new SwahiliNFCPluginKt();
        kotlinImplementation.onAttachedToEngine(flutterPluginBinding);
        
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
        kotlinImplementation.onDetachedFromEngine(binding);
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