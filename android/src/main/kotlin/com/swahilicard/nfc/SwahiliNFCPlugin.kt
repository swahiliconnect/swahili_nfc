package com.swahilicard.nfc

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
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
    
    // Debug flag
    private val isDebug = true

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
        
        debugLog("SwahiliNFC Plugin initialized")
    }

    fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // This method is called by the Java wrapper
    }

    fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> {
                val isAvailable = nfcAdapter != null && nfcAdapter!!.isEnabled
                debugLog("NFC Available: $isAvailable")
                result.success(isAvailable)
            }
            "startSession" -> {
                isReading = call.argument<Boolean>("isReading") ?: false
                isWriting = call.argument<Boolean>("isWriting") ?: false
                
                debugLog("Start session - isReading: $isReading, isWriting: $isWriting")
                
                if (isWriting && isReading) {
                    debugLog("Error: Cannot read and write in the same session")
                    result.error(
                        "invalid_args",
                        "Cannot read and write in the same session",
                        null
                    )
                    return
                }
                
                if (nfcAdapter == null || !nfcAdapter!!.isEnabled) {
                    debugLog("Error: NFC not available or disabled")
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
                    debugLog("Read session started - waiting for tag")
                } else {
                    // For write sessions, return success immediately
                    debugLog("Write session started")
                    result.success(null)
                }
            }
            "stopSession" -> {
                disableForegroundDispatch()
                isReading = false
                isWriting = false
                writeData = null
                pendingResult = null
                debugLog("Session stopped")
                result.success(null)
            }
            "readTag" -> {
                // This is handled in onNewIntent for Android
                debugLog("Error: No tag detected. Call startSession first.")
                result.error(
                    "invalid_state",
                    "No tag detected. Call startSession first.",
                    null
                )
            }
            "writeTag" -> {
                val data = call.argument<Any>("data")
                if (data == null) {
                    debugLog("Error: Data is required for writing")
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
                            debugLog("Converting Map to JSON for writing")
                            org.json.JSONObject(data).toString()
                        } catch (e: Exception) {
                            debugLog("Error converting data to JSON: ${e.message}")
                            result.error(
                                "conversion_error",
                                "Failed to convert data to JSON: ${e.message}",
                                null
                            )
                            return
                        }
                    }
                    is String -> {
                        debugLog("Using string data for writing: ${data.take(50)}...")
                        data // Already a string
                    }
                    else -> {
                        debugLog("Error: Data must be a Map or String")
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
                debugLog("Write data prepared, waiting for tag")
            }
            else -> {
                debugLog("Method not implemented: ${call.method}")
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
        debugLog("Plugin attached to activity")
    }

    fun onDetachedFromActivityForConfigChanges() {
        disableForegroundDispatch()
        debugLog("Plugin detached from activity for config changes")
    }

    fun onReattachedToActivityForConfigChanges(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        debugLog("Plugin reattached to activity")
    }

    fun onDetachedFromActivity() {
        disableForegroundDispatch()
        activity = null
        debugLog("Plugin detached from activity")
    }

    override fun onNewIntent(intent: Intent): Boolean {
        // Handle new NFC intent
        if (NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TAG_DISCOVERED == intent.action) {
            
            debugLog("NFC tag detected: ${intent.action}")
            
            val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }
            
            if (tag != null) {
                if (isReading) {
                    debugLog("Processing tag for reading")
                    handleReadTag(tag)
                } else if (isWriting) {
                    debugLog("Processing tag for writing")
                    handleWriteTag(tag)
                }
                return true
            } else {
                debugLog("Tag is null")
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
                    debugLog("Connected to NDEF tag")
                    
                    val ndefMessage = ndef.cachedNdefMessage
                    if (ndefMessage != null) {
                        debugLog("NDEF message found with ${ndefMessage.records.size} records")
                        
                        // First look for our specific mime type
                        val mimeRecord = ndefMessage.records.find { record ->
                            record.tnf == NdefRecord.TNF_MIME_MEDIA &&
                            String(record.type).contains("swahilicard")
                        }
                        
                        val result = if (mimeRecord != null) {
                            // Found our specific record
                            debugLog("Found SwahiliCard MIME record")
                            String(mimeRecord.payload)
                        } else {
                            // Fallback: check for well-known text record
                            val textRecord = ndefMessage.records.find { record ->
                                record.tnf == NdefRecord.TNF_WELL_KNOWN &&
                                record.type.contentEquals(NdefRecord.RTD_TEXT)
                            }
                            
                            if (textRecord != null) {
                                // Process text record - need to skip language code
                                debugLog("Found TEXT record")
                                val payload = textRecord.payload
                                val languageCodeLength = payload[0].toInt() and 0x3F
                                String(payload, languageCodeLength + 1, payload.size - languageCodeLength - 1)
                            } else {
                                // Last resort - just use first record
                                debugLog("No special record found, using first record")
                                val firstRecord = ndefMessage.records.firstOrNull()
                                if (firstRecord != null) {
                                    try {
                                        String(firstRecord.payload)
                                    } catch (e: Exception) {
                                        debugLog("Error converting payload to string: ${e.message}")
                                        "{}" // Empty JSON as fallback
                                    }
                                } else {
                                    debugLog("No records in NDEF message")
                                    "{}"
                                }
                            }
                        }
                        
                        debugLog("Read result (first 50 chars): ${result.take(50)}...")
                        
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
                        // No NDEF message on tag
                        debugLog("No NDEF message on tag")
                        val emptyResult = "{}"
                        
                        ndef.close()
                        
                        mainHandler.post {
                            pendingResult?.success(emptyResult)
                            pendingResult = null
                        }
                    }
                } else {
                    // Tag doesn't support NDEF
                    val error = "Tag doesn't support NDEF"
                    debugLog(error)
                    
                    mainHandler.post {
                        pendingResult?.error("tag_error", error, null)
                        pendingResult = null
                    }
                }
            } catch (e: IOException) {
                val error = "Error reading from tag: ${e.message}"
                debugLog(error)
                
                mainHandler.post {
                    pendingResult?.error("io_error", error, null)
                    pendingResult = null
                }
            } catch (e: Exception) {
                val error = "Error: ${e.message}"
                debugLog(error)
                
                mainHandler.post {
                    pendingResult?.error("unknown_error", error, null)
                    pendingResult = null
                }
            }
        }
    }

    private fun handleWriteTag(tag: Tag) {
    if (writeData == null) {
        debugLog("Error: No data to write")
        mainHandler.post {
            pendingResult?.error("invalid_state", "No data to write", null)
            pendingResult = null
        }
        return
    }
    
    debugLog("Writing data to tag (first 50 chars): ${writeData!!.take(50)}...")
    
    executor.execute {
        try {
            val ndef = Ndef.get(tag)
            
            if (ndef != null) {
                // Tag supports NDEF, write directly
                try {
                    ndef.connect()
                    debugLog("Connected to NDEF tag")
                    
                    // Check if tag is writable
                    if (!ndef.isWritable) {
                        debugLog("Error: Tag is not writable")
                        mainHandler.post {
                            pendingResult?.error("tag_error", "Tag is not writable", null)
                            pendingResult = null
                        }
                        return@execute
                    }
                    
                    // Check tag capacity - this is crucial
                    val tagSize = ndef.maxSize
                    debugLog("Tag capacity: $tagSize bytes")
                    
                    // Create NDEF message
                    val ndefMessage = createNDEFMessage(writeData!!)
                    val messageSize = ndefMessage.byteArrayLength
                    debugLog("Message size: $messageSize bytes")
                    
                    if (messageSize > tagSize) {
                        val errorMsg = "Message too large ($messageSize bytes) for tag capacity ($tagSize bytes)"
                        debugLog("Error: $errorMsg")
                        mainHandler.post {
                            pendingResult?.error(
                                "size_error",
                                errorMsg,
                                null
                            )
                            pendingResult = null
                        }
                        return@execute
                    }
                    
                    // Try writing with explicit error handling
                    debugLog("Writing NDEF message to tag")
                    try {
                        ndef.writeNdefMessage(ndefMessage)
                        debugLog("Write successful")
                        
                        // Wait briefly to ensure write is complete
                        Thread.sleep(50)
                        
                        mainHandler.post {
                            pendingResult?.success(true)
                            pendingResult = null
                        }
                    } catch (e: Exception) {
                        val errorMsg = if (e.message != null) e.message else "Tag write failed - possibly moved too quickly"
                        debugLog("Write error: $errorMsg")
                        debugLog("Exception type: ${e.javaClass.simpleName}")
                        e.printStackTrace()
                        
                        mainHandler.post {
                            pendingResult?.error(
                                "write_error",
                                errorMsg,
                                null
                            )
                            pendingResult = null
                        }
                    } finally {
                        try {
                            ndef.close()
                        } catch (e: Exception) {
                            debugLog("Error closing NDEF connection: ${e.message}")
                        }
                    }
                } catch (e: Exception) {
                    val errorMsg = e.message ?: "Unknown error connecting to tag"
                    debugLog("Connection error: $errorMsg")
                    debugLog("Exception type: ${e.javaClass.simpleName}")
                    e.printStackTrace()
                    
                    mainHandler.post {
                        pendingResult?.error("connection_error", errorMsg, null)
                        pendingResult = null
                    }
                    
                    try {
                        ndef.close()
                    } catch (closeEx: Exception) {
                        // Ignore close errors
                    }
                }
            } else {
                // Try to format tag
                debugLog("Tag doesn't support NDEF, trying to format")
                val ndefFormatable = NdefFormatable.get(tag)
                
                if (ndefFormatable != null) {
                    try {
                        ndefFormatable.connect()
                        debugLog("Connected to formattable tag")
                        
                        // Create NDEF message
                        val ndefMessage = createNDEFMessage(writeData!!)
                        
                        debugLog("Formatting tag and writing NDEF message")
                        ndefFormatable.format(ndefMessage)
                        debugLog("Format and write successful")
                        
                        // Wait briefly to ensure write is complete
                        Thread.sleep(50)
                        
                        mainHandler.post {
                            pendingResult?.success(true)
                            pendingResult = null
                        }
                    } catch (e: Exception) {
                        val errorMsg = e.message ?: "Unknown formatting error"
                        debugLog("Format error: $errorMsg")
                        debugLog("Exception type: ${e.javaClass.simpleName}")
                        e.printStackTrace()
                        
                        mainHandler.post {
                            pendingResult?.error(
                                "format_error",
                                errorMsg,
                                null
                            )
                            pendingResult = null
                        }
                    } finally {
                        try {
                            ndefFormatable.close()
                        } catch (e: Exception) {
                            // Ignore close errors
                        }
                    }
                } else {
                    val errorMsg = "Tag doesn't support NDEF and cannot be formatted"
                    debugLog("Error: $errorMsg")
                    mainHandler.post {
                        pendingResult?.error(
                            "tag_error",
                            errorMsg,
                            null
                        )
                        pendingResult = null
                    }
                }
            }
        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error in tag processing"
            debugLog("Processing error: $errorMsg")
            debugLog("Exception type: ${e.javaClass.simpleName}")
            e.printStackTrace()
            
            mainHandler.post {
                pendingResult?.error("processing_error", errorMsg, null)
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
                debugLog("Foreground dispatch enabled")
            }
        } catch (e: Exception) {
            debugLog("Error enabling foreground dispatch: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun disableForegroundDispatch() {
        try {
            val currentActivity = activity ?: return
            if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
                nfcAdapter!!.disableForegroundDispatch(currentActivity)
                debugLog("Foreground dispatch disabled")
            }
        } catch (e: Exception) {
            debugLog("Error disabling foreground dispatch: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun createNDEFMessage(data: String): NdefMessage {
        // For SwahiliCard, use our custom MIME type
        val mimeType = "application/vnd.swahilicard"
        val mimeRecord = NdefRecord.createMime(
            mimeType,
            data.toByteArray()
        )
        
        // Also create a text record as fallback for apps that don't understand our MIME type
        val languageCode = "en"
        val textBytes = data.toByteArray()
        val textPayload = ByteArray(1 + languageCode.length + textBytes.size)
        textPayload[0] = languageCode.length.toByte()
        System.arraycopy(languageCode.toByteArray(), 0, textPayload, 1, languageCode.length)
        System.arraycopy(textBytes, 0, textPayload, 1 + languageCode.length, textBytes.size)
        val textRecord = NdefRecord(
            NdefRecord.TNF_WELL_KNOWN,
            NdefRecord.RTD_TEXT,
            ByteArray(0),
            textPayload
        )
        
        // Create a URI record with a web link as additional fallback
        val uriRecord = NdefRecord.createUri("https://swahilicard.com/")
        
        // Return message with all records
        return NdefMessage(arrayOf(mimeRecord, textRecord, uriRecord))
    }
    
    // Debug logging helper
    private fun debugLog(message: String) {
        if (isDebug) {
            Log.d("SwahiliNFC", message)
        }
    }
}