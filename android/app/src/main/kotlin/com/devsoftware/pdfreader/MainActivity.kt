package com.devsoftware.pdfreader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.content.ContentResolver
import java.io.InputStream
import java.io.FileOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val INTENT_CHANNEL = "app.channel.shared/data"
    private val PDF_VIEWER_CHANNEL = "pdf_viewer_channel"
    
    private var intentMethodChannel: MethodChannel? = null
    private var pdfViewerMethodChannel: MethodChannel? = null
    private var pendingIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Intent Channel
        intentMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> handleIntent(intent, result)
                "clearPendingIntent" -> {
                    pendingIntent = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // PDF Viewer Channel
        pdfViewerMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_VIEWER_CHANNEL)
        pdfViewerMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "readContentUri" -> {
                    val uriString = call.argument<String>("uri")
                    try {
                        val uri = Uri.parse(uriString)
                        val contentResolver: ContentResolver = applicationContext.contentResolver
                        val inputStream: InputStream? = contentResolver.openInputStream(uri)
                        if (inputStream != null) {
                            val bytes = inputStream.readBytes()
                            result.success(bytes)
                        } else {
                            result.error("IO_ERROR", "Cannot open input stream for URI: $uriString", null)
                        }
                    } catch (e: Exception) {
                        result.error("IO_ERROR", e.toString(), null)
                    }
                }
                "convertContentUri" -> {
                    val uriString = call.argument<String>("uri")
                    try {
                        val filePath = convertContentUri(uriString!!)
                        result.success(filePath)
                    } catch (e: Exception) {
                        result.error("CONVERSION_ERROR", e.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Uygulama açıldığında pending intent'i kontrol et
        if (pendingIntent != null) {
            handleNewIntent(pendingIntent!!)
            pendingIntent = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Gelen intent'i kaydet
        pendingIntent = intent
        
        println("📱 MainActivity onCreate - Intent: ${intent?.action}, Data: ${intent?.dataString}")
    }

    private fun convertContentUri(uriString: String): String {
        try {
            println("🔄 Converting content URI: $uriString")
            val uri = Uri.parse(uriString)
            val contentResolver: ContentResolver = applicationContext.contentResolver
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            
            if (inputStream != null) {
                // Geçici dosya oluştur
                val tempDir = File(applicationContext.cacheDir, "pdf_temp")
                if (!tempDir.exists()) {
                    tempDir.mkdirs()
                }
                
                val tempFile = File(tempDir, "external_${System.currentTimeMillis()}.pdf")
                val outputStream = FileOutputStream(tempFile)
                
                // Content URI'yi geçici dosyaya kopyala
                inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()
                
                println("✅ Content URI converted to: ${tempFile.absolutePath}")
                println("✅ File size: ${tempFile.length()} bytes")
                println("✅ File exists: ${tempFile.exists()}")
                
                return tempFile.absolutePath
            } else {
                throw Exception("Cannot open input stream for URI: $uriString")
            }
        } catch (e: Exception) {
            println("❌ Content URI conversion error: $e")
            throw e
        }
    }

    private fun handleIntent(intent: Intent, result: MethodChannel.Result) {
        val action = intent.action
        val type = intent.type
        val data = intent.dataString
        val uri = intent.data?.toString()

        println("📱 Intent received - Action: $action, Type: $type, Data: $data, URI: $uri")

        if (Intent.ACTION_VIEW == action || Intent.ACTION_SEND == action) {
            val intentData = mapOf(
                "action" to action,
                "type" to type,
                "data" to data,
                "uri" to uri
            )
            result.success(intentData)
            println("✅ Intent data sent to Flutter: $intentData")
        } else {
            result.success(null)
            println("ℹ️ No relevant intent action found")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        println("🔄 onNewIntent received - Action: ${intent.action}, Data: ${intent.dataString}")
        
        pendingIntent = intent
        handleNewIntent(intent)
    }

    private fun handleNewIntent(intent: Intent) {
        val action = intent.action
        val data = intent.dataString
        val uri = intent.data?.toString()
        
        println("🔄 Handling new intent - Action: $action, Data: $data, URI: $uri")
        
        if ((Intent.ACTION_VIEW == action || Intent.ACTION_SEND == action) && uri != null) {
            val intentData = mapOf(
                "action" to action,
                "type" to intent.type,
                "data" to data,
                "uri" to uri
            )
            
            println("📤 Sending new intent to Flutter: $intentData")
            intentMethodChannel?.invokeMethod("onNewIntent", intentData)
        } else {
            println("❌ No valid intent data to send")
        }
    }

    override fun onResume() {
        super.onResume()
        println("🔄 MainActivity onResume - Checking pending intent")
        
        // Uygulama ön plana geldiğinde pending intent'i kontrol et
        if (pendingIntent != null) {
            handleNewIntent(pendingIntent!!)
            pendingIntent = null
        }
    }
}
