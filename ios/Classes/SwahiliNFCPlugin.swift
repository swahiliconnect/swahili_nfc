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
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.swahilicard.nfc/ios", binaryMessenger: registrar.messenger())
        let instance = SwahiliNFCPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "com.swahilicard.nfc/ios/tags", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            switch call.method {
            case "isAvailable":
                result(NFCNDEFReaderSession.readingAvailable)
                
            case "startSession":
                guard NFCNDEFReaderSession.readingAvailable else {
                    result(FlutterError(code: "nfc_not_available", message: "NFC is not available on this device", details: nil))
                    return
                }
                
                if let args = call.arguments as? [String: Any] {
                    isReading = args["isReading"] as? Bool ?? false
                    isWriting = args["isWriting"] as? Bool ?? false
                    alertMessage = args["alertMessage"] as? String ?? alertMessage
                }
                
                if isReading && isWriting {
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
                    result(FlutterError(code: "busy", message: "Another operation is in progress", details: nil))
                } else {
                    result(FlutterError(code: "no_data", message: "No tag data available", details: nil))
                }
                
            case "writeTag":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? String else {
                    result(FlutterError(code: "invalid_args", message: "Data is required for writing", details: nil))
                    return
                }
                
                writeData = data
                pendingResult = result
                
                // Ensure NFC session is active
                if nfcSession == nil {
                    startNFCSession()
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            // iOS version does not support NFC
            result(FlutterError(code: "unsupported_ios_version", message: "NFC is not supported on this iOS version", details: nil))
        }
    }
    
    private func startNFCSession() {
        if #available(iOS 13.0, *) {
            nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: !isWriting)
            nfcSession?.alertMessage = alertMessage
            nfcSession?.begin()
        }
    }
    
    private func stopNFCSession() {
        if #available(iOS 13.0, *) {
            nfcSession?.invalidate()
            nfcSession = nil
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle session invalidation
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
        handleDetectedMessages(messages)
    }
    
    @available(iOS 13.0, *)
    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        // Connect to first tag
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
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
            pendingResult?(FlutterError(code: "no_message", message: "No NDEF message found", details: nil))
            pendingResult = nil
            return
        }
        
        // Convert NDEF message to data
        let result = processNDEFMessage(message)
        
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
                session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                self.pendingResult?(FlutterError(code: "tag_error", message: error.localizedDescription, details: nil))
                self.pendingResult = nil
                return
            }
            
            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag does not support NDEF")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag does not support NDEF", details: nil))
                self.pendingResult = nil
                
            case .readOnly, .readWrite:
                // Tag supports NDEF, read message
                tag.readNDEF { message, error in
                    if let error = error {
                        session.invalidate(errorMessage: "Failed to read NDEF: \(error.localizedDescription)")
                        self.pendingResult?(FlutterError(code: "read_error", message: error.localizedDescription, details: nil))
                        self.pendingResult = nil
                        return
                    }
                    
                    if let message = message {
                        // Process NDEF message
                        let result = self.processNDEFMessage(message)
                        
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
                        session.invalidate(errorMessage: "No NDEF message found on tag")
                        self.pendingResult?(FlutterError(code: "no_message", message: "No NDEF message found on tag", details: nil))
                        self.pendingResult = nil
                    }
                }
                
            @unknown default:
                session.invalidate(errorMessage: "Unknown tag status")
                self.pendingResult?(FlutterError(code: "unknown_status", message: "Unknown tag status", details: nil))
                self.pendingResult = nil
            }
        }
    }
    
    @available(iOS 13.0, *)
    private func handleWriteToTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let writeData = writeData else {
            session.invalidate(errorMessage: "No data to write")
            pendingResult?(FlutterError(code: "no_data", message: "No data to write", details: nil))
            pendingResult = nil
            return
        }
        
        // Check tag status
        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                self.pendingResult?(FlutterError(code: "tag_error", message: error.localizedDescription, details: nil))
                self.pendingResult = nil
                return
            }
            
            if status == .readOnly {
                session.invalidate(errorMessage: "Tag is read-only")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag is read-only", details: nil))
                self.pendingResult = nil
                return
            }
            
            if status == .notSupported {
                session.invalidate(errorMessage: "Tag does not support NDEF")
                self.pendingResult?(FlutterError(code: "tag_error", message: "Tag does not support NDEF", details: nil))
                self.pendingResult = nil
                return
            }
            
            // Create NDEF message
            let message = self.createNDEFMessage(from: writeData)
            
            // Write to tag
            tag.writeNDEF(message) { error in
                if let error = error {
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    self.pendingResult?(FlutterError(code: "write_error", message: error.localizedDescription, details: nil))
                    self.pendingResult = nil
                    return
                }
                
                // Success
                session.alertMessage = "Write successful"
                session.invalidate()
                self.pendingResult?(true)
                self.pendingResult = nil
            }
        }
    }
    
    private func processNDEFMessage(_ message: NFCNDEFMessage) -> String {
        // Extract data from NDEF message
        var resultString = ""
        
        for record in message.records {
            if let type = String(data: record.type, encoding: .utf8),
               let payload = String(data: record.payload, encoding: .utf8) {
                
                if type == "text/plain" || type.contains("swahilicard") {
                    // Text or our custom type
                    resultString = payload
                    break
                } else {
                    // Other type, append to result
                    resultString += payload
                }
            }
        }
        
        // If no data extracted, return empty JSON object
        if resultString.isEmpty {
            return "{}"
        }
        
        return resultString
    }
    
    @available(iOS 13.0, *)
    private func createNDEFMessage(from data: String) -> NFCNDEFMessage {
        // Create a MIME record with our data
        let mimeType = "application/vnd.swahilicard"
        let payload = data.data(using: .utf8) ?? Data()
        
        let record = NFCNDEFPayload(
            format: .media,
            type: mimeType.data(using: .utf8)!,
            identifier: Data(),
            payload: payload
        )
        
        return NFCNDEFMessage(records: [record])
    }
}

// MARK: - FlutterStreamHandler implementation

@available(iOS 13.0, *)
extension SwahiliNFCPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}