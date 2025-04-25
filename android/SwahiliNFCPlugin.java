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
 * This Java class is a bridge to the Kotlin implementation
 * It ensures the plugin can be properly registered by the Java compiler
 */
public class SwahiliNFCPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    // The Kotlin implementation that will do the actual work
    private final SwahiliNFCPluginKt kotlinPlugin = new SwahiliNFCPluginKt();

    /**
     * Plugin registration for older embedding API (v1)
     */
    public static void registerWith(Registrar registrar) {
        SwahiliNFCPluginKt.registerWith(registrar);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        kotlinPlugin.onAttachedToEngine(flutterPluginBinding);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        kotlinPlugin.onMethodCall(call, result);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        kotlinPlugin.onDetachedFromEngine(binding);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        kotlinPlugin.onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        kotlinPlugin.onDetachedFromActivityForConfigChanges();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        kotlinPlugin.onReattachedToActivityForConfigChanges(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        kotlinPlugin.onDetachedFromActivity();
    }
}