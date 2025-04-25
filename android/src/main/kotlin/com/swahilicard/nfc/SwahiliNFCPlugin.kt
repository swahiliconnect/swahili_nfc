package com.swahilicard.nfc

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** SwahiliNFCPluginKt - Kotlin implementation called by the Java wrapper */
class SwahiliNFCPluginKt: PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var pendingResult: Result? = null
    private var isReading = false
    private var isWriting = false
    private var writeData: String? = null
    private var tagEventSink: EventChannel.EventSink? = null
    private val executor: Executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Setup channels for both registration methods
    fun setupChannels(messenger: BinaryMessenger, activity: Activity?) {
        this.activity = activity
        nfcAdapter = activity?.let { NfcAdapter.getDefaultAdapter(it) }

        channel = MethodChannel(messenger, "com.swahilicard.nfc/android")
        channel.setMethodCallHandler { call, result -> onMethodCall(call, result) }
        
        eventChannel = EventChannel(messenger, "com.swahilicard.nfc/android/tags")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                tagEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                tagEventSink = null
            }
        })
    }

    fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // This method is called by the Java wrapper
    }

    fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(nfcAdapter != null && nfcAdapter!!.isEnabled)
            }
            "startSession" -> {
                isReading = call.argument<Boolean>("isReading") ?: false
                isWriting = call.argument<Boolean>("isWriting") ?: false
                
                if (isWriting && isReading) {
                    result.error(
                        "invalid_args",
                        "Cannot read and write in the same session",
                        null
                    )
                    return
                }
                
                if (nfcAdapter == null || !nfcAdapter!!.isEnabled) {
                    result.error(
                        "nfc_not_available",
                        "NFC is not available or disabled",
                        null
                    )
                    return
                }
                
                // Enable foreground dispatch
                enableForegroundDispatch()
                
                // For read sessions, we'll wait for a tag
                if (isReading) {
                    pendingResult = result
                } else {
                    // For write sessions, return success immediately
                    result.success(null)
                }
            }
            "stopSession" -> {
                disableForegroundDispatch()
                isReading = false
                isWriting = false
                writeData = null
                pendingResult = null
                result.success(null)
            }
            "readTag" -> {
                // This is handled in onNewIntent for Android
                result.error(
                    "invalid_state",
                    "No tag detected. Call startSession first.",
                    null
                )
            }
            "writeTag" -> {
    val data = call.argument<Any>("data")
    if (data == null) {
        result.error(
            "invalid_args",
            "Data is required for writing",
            null
        )
        return
    }
    
    // Convert the data to a JSON string regardless of whether it's a Map or String
    val jsonData = when (data) {
        is Map<*, *> -> {
            try {
                // Convert map to JSON string
                org.json.JSONObject(data).toString()
            } catch (e: Exception) {
                result.error(
                    "conversion_error",
                    "Failed to convert data to JSON: ${e.message}",
                    null
                )
                return
            }
        }
        is String -> data // Already a string
        else -> {
            result.error(
                "invalid_args",
                "Data must be a Map or String",
                null
            )
            return
        }
    }
    
    writeData = jsonData
    pendingResult = result
}
            else -> {
                result.notImplemented()
            }
        }
    }

    fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // This method is called by the Java wrapper
    }

    fun onAttachedToActivity(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
    }

    fun onDetachedFromActivityForConfigChanges() {
        disableForegroundDispatch()
    }

    fun onReattachedToActivityForConfigChanges(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
    }

    fun onDetachedFromActivity() {
        disableForegroundDispatch()
        activity = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        // Handle new NFC intent
        if (NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TAG_DISCOVERED == intent.action) {
            
            val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }
            
            if (tag != null) {
                if (isReading) {
                    handleReadTag(tag)
                } else if (isWriting) {
                    handleWriteTag(tag)
                }
                return true
            }
        }
        return false
    }

    private fun handleReadTag(tag: Tag) {
        executor.execute {
            try {
                val ndef = Ndef.get(tag)
                if (ndef != null) {
                    ndef.connect()
                    
                    val ndefMessage = ndef.cachedNdefMessage
                    val result = if (ndefMessage != null) {
                        val records = ndefMessage.records
                        val stringBuilder = StringBuilder()
                        
                        for (record in records) {
                            val payload = String(record.payload)
                            stringBuilder.append(payload)
                        }
                        
                        stringBuilder.toString()
                    } else {
                        // No NDEF message on tag
                        "{}"
                    }
                    
                    ndef.close()
                    
                    // Notify event channel for continuous reading
                    if (tagEventSink != null) {
                        mainHandler.post {
                            tagEventSink?.success(result)
                        }
                    }
                    
                    // Return result for one-time reading
                    mainHandler.post {
                        pendingResult?.success(result)
                        pendingResult = null
                    }
                } else {
                    // Tag doesn't support NDEF
                    val error = "Tag doesn't support NDEF"
                    
                    mainHandler.post {
                        pendingResult?.error("tag_error", error, null)
                        pendingResult = null
                    }
                }
            } catch (e: IOException) {
                val error = "Error reading from tag: ${e.message}"
                
                mainHandler.post {
                    pendingResult?.error("io_error", error, null)
                    pendingResult = null
                }
            } catch (e: Exception) {
                val error = "Error: ${e.message}"
                
                mainHandler.post {
                    pendingResult?.error("unknown_error", error, null)
                    pendingResult = null
                }
            }
        }
    }

    private fun handleWriteTag(tag: Tag) {
        if (writeData == null) {
            mainHandler.post {
                pendingResult?.error("invalid_state", "No data to write", null)
                pendingResult = null
            }
            return
        }
        
        executor.execute {
            try {
                val ndef = Ndef.get(tag)
                
                if (ndef != null) {
                    // Tag supports NDEF, write directly
                    ndef.connect()
                    
                    if (!ndef.isWritable) {
                        mainHandler.post {
                            pendingResult?.error("tag_error", "Tag is not writable", null)
                            pendingResult = null
                        }
                        return@execute
                    }
                    
                    // Create NDEF message
                    val ndefMessage = createNDEFMessage(writeData!!)
                    
                    if (ndefMessage.byteArrayLength > ndef.maxSize) {
                        mainHandler.post {
                            pendingResult?.error(
                                "size_error",
                                "Message too large (${ndefMessage.byteArrayLength} bytes) for tag capacity (${ndef.maxSize} bytes)",
                                null
                            )
                            pendingResult = null
                        }
                        return@execute
                    }
                    
                    ndef.writeNdefMessage(ndefMessage)
                    ndef.close()
                    
                    mainHandler.post {
                        pendingResult?.success(true)
                        pendingResult = null
                    }
                } else {
                    // Try to format tag
                    val ndefFormatable = NdefFormatable.get(tag)
                    
                    if (ndefFormatable != null) {
                        try {
                            ndefFormatable.connect()
                            
                            // Create NDEF message
                            val ndefMessage = createNDEFMessage(writeData!!)
                            
                            ndefFormatable.format(ndefMessage)
                            ndefFormatable.close()
                            
                            mainHandler.post {
                                pendingResult?.success(true)
                                pendingResult = null
                            }
                        } catch (e: IOException) {
                            mainHandler.post {
                                pendingResult?.error(
                                    "format_error",
                                    "Could not format tag: ${e.message}",
                                    null
                                )
                                pendingResult = null
                            }
                        }
                    } else {
                        mainHandler.post {
                            pendingResult?.error(
                                "tag_error",
                                "Tag doesn't support NDEF and cannot be formatted",
                                null
                            )
                            pendingResult = null
                        }
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    pendingResult?.error("unknown_error", "Error: ${e.message}", null)
                    pendingResult = null
                }
            }
        }
    }

    private fun enableForegroundDispatch() {
        try {
            val currentActivity = activity ?: return
            if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
                val intent = Intent(currentActivity, currentActivity.javaClass).apply {
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    android.app.PendingIntent.getActivity(
                        currentActivity,
                        0,
                        intent,
                        android.app.PendingIntent.FLAG_MUTABLE
                    )
                } else {
                    @Suppress("DEPRECATION")
                    android.app.PendingIntent.getActivity(
                        currentActivity,
                        0,
                        intent,
                        0
                    )
                }
                
                nfcAdapter!!.enableForegroundDispatch(currentActivity, pendingIntent, null, null)
            }
        } catch (e: Exception) {
            // Log error
            e.printStackTrace()
        }
    }

    private fun disableForegroundDispatch() {
        try {
            val currentActivity = activity ?: return
            if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
                nfcAdapter!!.disableForegroundDispatch(currentActivity)
            }
        } catch (e: Exception) {
            // Log error
            e.printStackTrace()
        }
    }

    private fun createNDEFMessage(data: String): android.nfc.NdefMessage {
        // For this example, we'll create a MIME record with our data
        val mimeType = "application/vnd.swahilicard"
        val mimeRecord = android.nfc.NdefRecord.createMime(
            mimeType,
            data.toByteArray()
        )
        
        return android.nfc.NdefMessage(arrayOf(mimeRecord))
    }
}