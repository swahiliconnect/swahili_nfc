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
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** SwahiliNFCPlugin */
class SwahiliNFCPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
  /// The MethodChannel that will handle communication between Flutter and native Android
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var activity: Activity
  private var nfcAdapter: NfcAdapter? = null
  private var pendingResult: Result? = null
  private var isReading = false
  private var isWriting = false
  private var writeData: String? = null
  private var tagEventSink: EventChannel.EventSink? = null
  private val executor: Executor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.swahilicard.nfc/android")
    channel.setMethodCallHandler(this)
    
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.swahilicard.nfc/android/tags")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        tagEventSink = events
      }

      override fun onCancel(arguments: Any?) {
        tagEventSink = null
      }
    })
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
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
        val data = call.argument<String>("data")
        if (data == null) {
          result.error(
            "invalid_args",
            "Data is required for writing",
            null
          )
          return
        }
        
        writeData = data
        pendingResult = result
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
    nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    disableForegroundDispatch()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
    nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
  }

  override fun onDetachedFromActivity() {
    disableForegroundDispatch()
  }

  override fun onNewIntent(intent: Intent): Boolean {
    // Handle new NFC intent
    if (NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action ||
        NfcAdapter.ACTION_TECH_DISCOVERED == intent.action ||
        NfcAdapter.ACTION_TAG_DISCOVERED == intent.action) {
      
      val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
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
      if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
        val intent = Intent(activity, activity.javaClass).apply {
          addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          android.app.PendingIntent.getActivity(
            activity,
            0,
            intent,
            android.app.PendingIntent.FLAG_MUTABLE
          )
        } else {
          android.app.PendingIntent.getActivity(
            activity,
            0,
            intent,
            0
          )
        }
        
        nfcAdapter!!.enableForegroundDispatch(activity, pendingIntent, null, null)
      }
    } catch (e: Exception) {
      // Log error
      e.printStackTrace()
    }
  }

  private fun disableForegroundDispatch() {
    try {
      if (nfcAdapter != null && nfcAdapter!!.isEnabled) {
        nfcAdapter!!.disableForegroundDispatch(activity)
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