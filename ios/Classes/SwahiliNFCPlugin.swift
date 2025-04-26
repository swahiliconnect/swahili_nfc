import Flutter
import UIKit
import CoreNFC

@available(iOS 13.0, *)
public class SwahiliNFCPlugin: NSObject, FlutterPlugin, NFCNDEFReaderSessionDelegate {
    private var nfcSession: NFCNDEFReaderSession?
    private var pendingResult: FlutterResult?
    private var isReading = false
    private var isWriting = false
    private var writeData: String?
    private var eventSink: FlutterEventSink?
    private var alertMessage: String = "Hold your iPhone near an NFC business card"
    private var isDebug = true
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.swahilicard.nfc/ios", binaryMessenger: registrar.messenger())
        let instance = SwahiliNFCPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "com.swahilicard.nfc/ios/tags", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        
        instance.debugLog("SwahiliNFC Plugin registered")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            switch call.method {
            case "isAvailable":
                let isAvailable = NFCNDEFReaderSession.readingAvailable
                debugLog("NFC Available: \(isAvailable)")
                result(isAvailable)
                
            case "startSession":
                guard NFCNDEFReaderSession.readingAvailable else {
                    debugLog("Error: NFC is not available on this device")
                    result(FlutterError(code: "nfc_not_available", message: "NFC is not available on this device", details: nil))
                    return
                }
                
                if let args = call.arguments as? [String: Any] {
                    isReading = args["isReading"] as? Bool ?? false
                    isWriting = args["isWriting"] as? Bool ?? false
                    alertMessage = args["alertMessage"] as? String ?? alertMessage
                }
                
                debugLog("Start session - isReading: \(isReading), isWriting: \(isWriting)")
                
                if isReading && isWriting {
                    debugLog("Error: Cannot read and write in the same session")
                    result(FlutterError(code: "invalid_args", message: "Cannot read and write in the same session", details: nil))
                    return
                }
                
                // Start NFC session
                startNFCSession()
                pendingResult = result
                
            case "stopSession":
                stopNFCSession()
                result(nil)
                
            case "getTagData":
                if pendingResult != nil {
                    debugLog("Error: Another operation is in progress")
                    result(FlutterError(code: "busy", message: "Another operation is in progress", details: nil))
                } else {
                    debugLog("Error: No tag data available")
                    result(FlutterError(code: "no_data", message: "No tag data available", details: nil))
                }
                
            case "writeTag":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? String else {
                    debugLog("Error: Data is required for writing")
                    result(FlutterError(code: "invalid_args", message: "Data is required for writing", details: nil))
                    return
                }
                
                debugLog("Write data prepared: \(data.prefix(50))...")
                writeData = data
                pendingResult = result
                
                // Ensure NFC session is active
                if nfcSession == nil {
                    startNFCSession()
                }
                
            default:
                debugLog("Method not implemented: \(call.method)")
                result(FlutterMethodNotImplemented)
            }
        } else {
            // iOS version does not support NFC
            debugLog("Error: NFC is not supported on this iOS version")
            result(FlutterError(code: "unsupported_ios_version", message: "NFC is not supported on this iOS version", details: nil))
        }
    }
    
    private func startNFCSession() {
        if #available(iOS 13.0, *) {
            debugLog("Starting NFC session")
            nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: !isWriting)
            nfcSession?.alertMessage = alertMessage
            nfcSession?.begin()
        }
    }
    
    private func stopNFCSession() {
        if #available(iOS 13.0, *) {
            debugLog("Stopping NFC session")
            nfcSession?.invalidate()
            nfcSession = nil
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle session invalidation
        debugLog("Session invalidated with error: \(error.localizedDescription)")
        
        if let pendingResult = pendingResult {
            if error.localizedDescription != "Session is invalidated" {
                pendingResult(FlutterError(code: "nfc_error", message: error.localizedDescription, details: nil))
            }
            self.pendingResult = nil
        }
        
        nfcSession = nil
    }
    
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Handle detected NDEF messages
        debugLog("Detected NDEF messages: \(messages.count)")
        handleDetectedMessages(messages)
    }
    
    @available(iOS 13.0, *)
    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        // Connect to first tag
        guard let tag = tags.first else {
            debugLog("Error: No tag detected")
            session.invalidate(errorMessage: "No tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                self.debugLog("Connection failed: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            self.debugLog("Connected to tag")
            
            if self.isWriting && self.writeData != nil {
                // Write mode
                self.handleWriteToTag(tag, session: session)
            } else {
                // Read mode
                self.handleReadFromTag(tag, session: session)
            }
        }
    }
    
    private func handleDetectedMessages(_ messages: [NFCNDEFMessage]) {
        // Process detected messages
        guard let message = messages.first else {
            debugLog("Error: No NDEF message found")
            pendingResult?(FlutterError(code: "no_message", message: "No NDEF message found", details: nil))
            pendingResult = nil
            return
        }
        
        // Convert NDEF message to data
        let result = processNDEFMessage(message)
        debugLog("Processed NDEF message: \(result.prefix(50))...")
        
        // If this is a continuous reading session, send to event sink
        if let eventSink = eventSink {
            eventSink(result)
        }
        
        // For one-time reading, send to pending result
        if isReading {
            pendingResult?(result)
            pendingResult = nil
        }
    }
    
    @available(iOS 13.0, *)
    private func handleReadFromTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        // Query tag for its NDEF message
        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                self.debugLog("Failed to query tag: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                self.pendingResult?(FlutterError(code: "tag_error", message: error.localizedDescription, details: nil))
                self.pendingResult = nil
                return
            }
            
            switch status {
            case .notSupported:
                self.debugLog("Error: Tag does not support NDEF")
                session.invalidate(errorMessage: "Tag does not support NDEF")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag does not support NDEF", details: nil))
                self.pendingResult = nil
                
            case .readOnly, .readWrite:
                // Tag supports NDEF, read message
                tag.readNDEF { message, error in
                    if let error = error {
                        self.debugLog("Failed to read NDEF: \(error.localizedDescription)")
                        session.invalidate(errorMessage: "Failed to read NDEF: \(error.localizedDescription)")
                        self.pendingResult?(FlutterError(code: "read_error", message: error.localizedDescription, details: nil))
                        self.pendingResult = nil
                        return
                    }
                    
                    if let message = message {
                        // Process NDEF message
                        let result = self.processNDEFMessage(message)
                        self.debugLog("Read successful: \(result.prefix(50))...")
                        
                        // If this is a continuous reading session, send to event sink
                        if let eventSink = self.eventSink {
                            eventSink(result)
                        }
                        
                        // For one-time reading, send to pending result
                        if self.isReading {
                            session.alertMessage = "Business card detected"
                            session.invalidate()
                            self.pendingResult?(result)
                            self.pendingResult = nil
                        }
                    } else {
                        // No message found
                        self.debugLog("Error: No NDEF message found on tag")
                        session.invalidate(errorMessage: "No NDEF message found on tag")
                        self.pendingResult?(FlutterError(code: "no_message", message: "No NDEF message found on tag", details: nil))
                        self.pendingResult = nil
                    }
                }
                
            @unknown default:
                self.debugLog("Error: Unknown tag status")
                session.invalidate(errorMessage: "Unknown tag status")
                self.pendingResult?(FlutterError(code: "unknown_status", message: "Unknown tag status", details: nil))
                self.pendingResult = nil
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func handleWriteToTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let writeData = writeData else {
            debugLog("Error: No data to write")
            session.invalidate(errorMessage: "No data to write")
            pendingResult?(FlutterError(code: "no_data", message: "No data to write", details: nil))
            pendingResult = nil
            return
        }
        
        // Check tag status
        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                self.debugLog("Failed to query tag: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                self.pendingResult?(FlutterError(code: "tag_error", message: error.localizedDescription, details: nil))
                self.pendingResult = nil
                return
            }
            
            if status == .readOnly {
                self.debugLog("Error: Tag is read-only")
                session.invalidate(errorMessage: "Tag is read-only")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag is read-only", details: nil))
                self.pendingResult = nil
                return
            }
            
            if status == .notSupported {
                self.debugLog("Error: Tag does not support NDEF")
                session.invalidate(errorMessage: "Tag does not support NDEF")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag does not support NDEF", details: nil))
                self.pendingResult = nil
                return
            }
            
            // Create NDEF message
            let message = self.createNDEFMessage(from: writeData)
            self.debugLog("Writing NDEF message to tag")
            
            // Write to tag
            tag.writeNDEF(message) { error in
                if let error = error {
                    self.debugLog("Write failed: \(error.localizedDescription)")
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    self.pendingResult?(FlutterError(code: "write_error", message: error.localizedDescription, details: nil))
                    self.pendingResult = nil
                    return
                }
                
                // Success
                self.debugLog("Write successful")
                session.alertMessage = "Write successful"
                session.invalidate()
                self.pendingResult?(true)
                self.pendingResult = nil
            }
        }
    }
    
    private func processNDEFMessage(_ message: NFCNDEFMessage) -> String {
        // Extract data from NDEF message with improved handling
        // First look for our custom MIME type
        for record in message.records {
            if let typeString = String(data: record.type, encoding: .utf8),
               typeString.contains("swahilicard") {
                
                debugLog("Found SwahiliCard MIME record")
                
                // Try various encodings for the payload
                if let payload = String(data: record.payload, encoding: .utf8) {
                    return payload
                } else if let payload = String(data: record.payload, encoding: .utf16) {
                    return payload
                } else if let payload = String(data: record.payload, encoding: .ascii) {
                    return payload
                }
            }
        }
        
        // Next, look for text records
        for record in message.records {
            if record.typeNameFormat == .nfcWellKnown {
                if let typeString = String(data: record.type, encoding: .utf8), typeString == "T" {
                    debugLog("Found TEXT record")
                    
                    // Handle text record - remove language code
                    var payload = record.payload
                    if payload.count > 0 {
                        let languageCodeLength = Int(payload[0] & 0x3F)
                        if payload.count > languageCodeLength + 1 {
                            payload = payload.advanced(by: languageCodeLength + 1)
                            
                            if let textPayload = String(data: payload, encoding: .utf8) {
                                return textPayload
                            }
                        }
                    }
                }
            }
        }
        
        // If no specific record types are found, try to get anything from the first record
        if let record = message.records.first {
            if let payload = String(data: record.payload, encoding: .utf8) {
                debugLog("Using first record with UTF-8 encoding")
                return payload
            } else if let payload = String(data: record.payload, encoding: .utf16) {
                debugLog("Using first record with UTF-16 encoding")
                return payload
            } else if let payload = String(data: record.payload, encoding: .ascii) {
                debugLog("Using first record with ASCII encoding")
                return payload
            }
        }
        
        // If all else fails, return empty JSON object
        debugLog("No readable payload found, returning empty JSON")
        return "{}"
    }
    
    @available(iOS 13.0, *)
    private func createNDEFMessage(from data: String) -> NFCNDEFMessage {
        // Create a diverse set of records for better compatibility
        var records: [NFCNDEFPayload] = []
        
        // 1. Create a MIME record with our SwahiliCard type
        let mimeType = "application/vnd.swahilicard"
        let payload = data.data(using: .utf8) ?? Data()
        
        let mimeRecord = NFCNDEFPayload(
            format: .media,
            type: mimeType.data(using: .utf8)!,
            identifier: Data(),
            payload: payload
        )
        records.append(mimeRecord)
        
        // 2. Create a text record as fallback
        if let textData = data.data(using: .utf8) {
            // Add language code (en)
            let languageCode = "en"
            let languageCodeData = languageCode.data(using: .ascii)!
            
            // Combine status byte + language code + text data
            var textPayload = Data()
            textPayload.append(UInt8(languageCodeData.count))
            textPayload.append(languageCodeData)
            textPayload.append(textData)
            
            let textRecord = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: "T".data(using: .ascii)!,
                identifier: Data(),
                payload: textPayload
            )
            records.append(textRecord)
        }
        
        // 3. Add URI record with SwahiliCard website
        if let uriData = "https://swahilicard.com/".data(using: .utf8) {
            // URI record needs a prefix byte (0x00 for "http://", 0x01 for "https://", etc.)
            var uriPayload = Data([0x01]) // 0x01 for https://
            // Remove https:// from the data since it's encoded in the prefix byte
            let trimmedUri = String(uriData.dropFirst(8))
            uriPayload.append(trimmedUri)
            
            let uriRecord = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: "U".data(using: .ascii)!,
                identifier: Data(),
                payload: uriPayload
            )
            records.append(uriRecord)
        }
        
        return NFCNDEFMessage(records: records)
    }
    
    // Debug logging helper
    private func debugLog(_ message: String) {
        if isDebug {
            NSLog("SwahiliNFC: \(message)")
        }
    }
}

// MARK: - FlutterStreamHandler implementation

@available(iOS 13.0, *)
extension SwahiliNFCPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        debugLog("Event sink registered for continuous reading")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        debugLog("Event sink cancelled")
        return nil
    }
}