package dev.labourapp.labour_app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val SAVE_REQUEST = 4101
private const val PICK_IMAGE_REQUEST = 4102

/** Sends, opens or saves an exported register. The user picks the recipient and sends it themselves (DOC-06). */
class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<File, MethodChannel.Result>? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "labour_app/files").setMethodCallHandler { call, result ->
            if (call.method == "pickImage") {
                pickImage(result)
                return@setMethodCallHandler
            }
            val file = File(call.argument<String>("path")!!)
            val mime = call.argument<String>("mime")!!
            when (call.method) {
                "send" -> result.success(send(file, mime, call.argument<Boolean>("whatsapp") == true))
                "open" -> result.success(open(file, mime))
                "save" -> save(file, mime, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun uriOf(file: File) = FileProvider.getUriForFile(this, "$packageName.files", file)

    /** True if WhatsApp opened, or the share sheet when it wasn't asked for. False if it had to fall back to the sheet. */
    private fun send(file: File, mime: String, whatsapp: Boolean): Boolean {
        val intent = Intent(Intent.ACTION_SEND)
            .setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uriOf(file))
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (whatsapp) {
            for (app in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                try {
                    startActivity(Intent(intent).setPackage(app))
                    return true
                } catch (_: ActivityNotFoundException) {
                    // Not installed. Try the next one, then the share sheet.
                }
            }
        }
        startActivity(Intent.createChooser(intent, file.name))
        return !whatsapp
    }

    private fun open(file: File, mime: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uriOf(file), mime)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    /** Android's own "save as" screen, so the app needs no storage permission. */
    private fun save(file: File, mime: String, result: MethodChannel.Result) {
        pendingSave = file to result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mime)
            .putExtra(Intent.EXTRA_TITLE, file.name)
        startActivityForResult(intent, SAVE_REQUEST)
    }

    /** Android's own picker, so the app needs no storage permission. Dart checks what comes back (DOC-04). */
    private fun pickImage(result: MethodChannel.Result) {
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/png", "image/jpeg"))
        startActivityForResult(intent, PICK_IMAGE_REQUEST)
    }

    private fun finishPick(resultCode: Int, data: Intent?) {
        val result = pendingPick ?: return
        pendingPick = null
        val source = data?.data
        if (resultCode != Activity.RESULT_OK || source == null) {
            result.success(null)
            return
        }
        try {
            result.success(contentResolver.openInputStream(source)!!.use { it.readBytes() })
        } catch (e: Exception) {
            result.error("pick_failed", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            finishPick(resultCode, data)
            return
        }
        if (requestCode != SAVE_REQUEST) return
        val (file, result) = pendingSave ?: return
        pendingSave = null
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(target)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
            result.success(true)
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }
}
