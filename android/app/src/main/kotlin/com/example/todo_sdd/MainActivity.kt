package com.example.todo_sdd

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.provider.DocumentsContract
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.text.Normalizer
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var pendingTestFolderResult: MethodChannel.Result? = null
    private var expectedTestFolderDocumentId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "todo_sdd/folder_access",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "normalizeNfc" -> {
                    val values = call.arguments as? List<*>
                    val tags = values?.filterIsInstance<String>()
                    if (values == null || tags == null || tags.size != values.size) {
                        result.error("invalid_tags", "タグ一覧が不正です", null)
                    } else {
                        result.success(
                            tags.map { Normalizer.normalize(it, Normalizer.Form.NFC) },
                        )
                    }
                }
                "getFolder" -> result.success(
                    getSharedPreferences("todo_sdd_settings", MODE_PRIVATE)
                        .getString("folder_uri", null),
                )
                "hasAccess" -> {
                    val value = call.arguments as? String
                    if (value == null) {
                        result.error("invalid_uri", "フォルダーURIがありません", null)
                    } else {
                        val uri = Uri.parse(value)
                        if (!DocumentsContract.isTreeUri(uri)) {
                            result.error("invalid_uri", "無効なフォルダーURIです", null)
                        } else {
                            try {
                                result.success(
                                    contentResolver.persistedUriPermissions.any {
                                        it.uri == uri && it.isReadPermission
                                    },
                                )
                            } catch (error: SecurityException) {
                                result.error("permission_denied", error.message, null)
                            }
                        }
                    }
                }
                "persistFolder" -> {
                    val value = call.arguments as? String
                    if (value == null || !DocumentsContract.isTreeUri(Uri.parse(value))) {
                        result.error("invalid_uri", "無効なフォルダーURIです", null)
                    } else {
                        try {
                            contentResolver.takePersistableUriPermission(
                                Uri.parse(value),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                            val stored = getSharedPreferences("todo_sdd_settings", MODE_PRIVATE)
                                .edit()
                                .putString("folder_uri", value)
                                .commit()
                            if (stored) {
                                result.success(null)
                            } else {
                                result.error("storage_error", "フォルダー設定を保存できません", null)
                            }
                        } catch (error: SecurityException) {
                            result.error("permission_denied", error.message, null)
                        }
                    }
                }
                "pickTestFolder" -> {
                    if (!isDebugBuild()) {
                        result.notImplemented()
                    } else {
                        val documentId = call.arguments as? String
                        if (documentId == null || !isTestFolderDocumentId(documentId)) {
                            result.error(
                                "invalid_test_folder",
                                "テスト用フォルダーの識別子が不正です",
                                null,
                            )
                        } else if (pendingTestFolderResult != null) {
                            result.error(
                                "selection_in_progress",
                                "フォルダー選択がすでに実行中です",
                                null,
                            )
                        } else {
                            expectedTestFolderDocumentId = documentId
                            pendingTestFolderResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
                                )
                            }
                            try {
                                startActivityForResult(intent, TEST_FOLDER_PICKER_REQUEST_CODE)
                            } catch (error: ActivityNotFoundException) {
                                pendingTestFolderResult = null
                                expectedTestFolderDocumentId = null
                                result.error(
                                    "picker_unavailable",
                                    "フォルダー選択画面を開けません",
                                    null,
                                )
                            } catch (error: SecurityException) {
                                pendingTestFolderResult = null
                                expectedTestFolderDocumentId = null
                                result.error("permission_denied", error.message, null)
                            }
                        }
                    }
                }
                "releaseTestFolder" -> {
                    if (!isDebugBuild()) {
                        result.notImplemented()
                    } else {
                        val value = call.arguments as? String
                        val uri = value?.let(Uri::parse)
                        if (uri == null || !isTestFolderUri(uri)) {
                            result.error(
                                "invalid_test_folder",
                                "テスト用フォルダーのURIが不正です",
                                null,
                            )
                        } else {
                            try {
                                val hasAccess = contentResolver.persistedUriPermissions.any {
                                    it.uri == uri && it.isReadPermission
                                }
                                if (hasAccess) {
                                    contentResolver.releasePersistableUriPermission(
                                        uri,
                                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                                    )
                                }
                                result.success(null)
                            } catch (error: SecurityException) {
                                result.error("permission_denied", error.message, null)
                            }
                        }
                    }
                }
                "readFolder" -> {
                    val value = call.arguments as? String
                    if (value == null || !DocumentsContract.isTreeUri(Uri.parse(value))) {
                        result.error("read_failed", "無効なフォルダーURIです", null)
                    } else {
                        val uri = Uri.parse(value)
                        val hasAccess = contentResolver.persistedUriPermissions.any {
                            it.uri == uri && it.isReadPermission
                        }
                        if (!hasAccess) {
                            result.error("permission_denied", "フォルダーの読取権限がありません", null)
                        } else if (uri.authority != "com.android.externalstorage.documents") {
                            result.error(
                                "read_failed",
                                "安全性を確認できないフォルダー提供元は読み込めません",
                                null,
                            )
                        } else {
                            try {
                                result.success(readFolder(uri))
                            } catch (error: SecurityException) {
                                result.error("permission_denied", error.message, null)
                            } catch (error: IOException) {
                                result.error("read_failed", error.message, null)
                            } catch (error: IllegalArgumentException) {
                                result.error("read_failed", error.message, null)
                            } catch (error: UnsupportedOperationException) {
                                result.error("read_failed", error.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == TEST_FOLDER_PICKER_REQUEST_CODE) {
            completeTestFolderSelection(
                if (resultCode == RESULT_OK) data?.data else null,
            )
        }
    }

    private fun completeTestFolderSelection(uri: Uri?) {
        val callback = pendingTestFolderResult ?: return
        val expectedDocumentId = expectedTestFolderDocumentId
        pendingTestFolderResult = null
        expectedTestFolderDocumentId = null

        if (uri == null) {
            callback.error("selection_cancelled", "フォルダー選択がキャンセルされました", null)
            return
        }
        if (
            expectedDocumentId == null ||
            !isTestFolderDocumentId(expectedDocumentId) ||
            !isTestFolderUri(uri) ||
            DocumentsContract.getTreeDocumentId(uri) != expectedDocumentId
        ) {
            callback.error(
                "invalid_test_folder",
                "選択したフォルダーはテスト用フォルダーではありません",
                null,
            )
            return
        }

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            val hasAccess = contentResolver.persistedUriPermissions.any {
                it.uri == uri && it.isReadPermission
            }
            if (!hasAccess) {
                callback.error(
                    "permission_denied",
                    "フォルダーの永続読取権限を取得できませんでした",
                    null,
                )
            } else {
                callback.success(uri.toString())
            }
        } catch (error: SecurityException) {
            callback.error("permission_denied", error.message, null)
        }
    }

    private fun isDebugBuild(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun isTestFolderDocumentId(documentId: String): Boolean =
        documentId.startsWith(TEST_FOLDER_DOCUMENT_ID_PREFIX)

    private fun isTestFolderUri(uri: Uri): Boolean =
        DocumentsContract.isTreeUri(uri) &&
            uri.authority == EXTERNAL_STORAGE_AUTHORITY &&
            isTestFolderDocumentId(DocumentsContract.getTreeDocumentId(uri))

    private fun readFolder(treeUri: Uri): Map<String, Any> {
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val visitedDocumentIds = mutableSetOf(rootDocumentId)
        val notes = mutableListOf<Map<String, String>>()
        val failures = mutableListOf<Map<String, String>>()
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )

        fun addFailure(path: String, message: String) {
            failures.add(mapOf("path" to path, "message" to message))
        }

        fun readChildren(parentDocumentId: String, parentPath: String) {
            val parentDocumentUri =
                DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocumentId)
            val childrenUri =
                DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocumentId)
            val cursor = contentResolver.query(childrenUri, projection, null, null, null)
                ?: throw FileNotFoundException("フォルダーの内容を取得できません")

            cursor.use {
                val idColumn = it.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                )
                val nameColumn = it.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                )
                val mimeColumn = it.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                )
                val flagsColumn = it.getColumnIndexOrThrow(
                    DocumentsContract.Document.COLUMN_FLAGS,
                )

                while (it.moveToNext()) {
                    val documentId = it.getString(idColumn)
                    val name = it.getString(nameColumn)
                    val mimeType = it.getString(mimeColumn)
                    val flags = it.getLong(flagsColumn).toInt()
                    if (documentId == null || name == null || mimeType == null) {
                        addFailure(parentPath, "フォルダー提供元の項目情報が不正です")
                        continue
                    }

                    val relativePath = if (parentPath.isEmpty()) {
                        name
                    } else {
                        "$parentPath/$name"
                    }
                    if (
                        name.isEmpty() ||
                        name == "." ||
                        name == ".." ||
                        '/' in name ||
                        '\\' in name
                    ) {
                        addFailure(relativePath, "安全な相対パスを作成できません")
                        continue
                    }

                    try {
                        val documentUri =
                            DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
                        if (
                            !DocumentsContract.isChildDocument(
                                contentResolver,
                                parentDocumentUri,
                                documentUri,
                            )
                        ) {
                            throw SecurityException("指定フォルダー外の項目を検出しました")
                        }

                        val documentPath = DocumentsContract.findDocumentPath(
                            contentResolver,
                            documentUri,
                        )?.path ?: throw FileNotFoundException("項目の位置を確認できません")
                        if (
                            documentPath.size < 2 ||
                            documentPath[documentPath.lastIndex - 1] != parentDocumentId ||
                            documentPath.last() != documentId
                        ) {
                            throw SecurityException("リンクまたは安全でない階層を検出しました")
                        }
                        if (!visitedDocumentIds.add(documentId)) {
                            throw SecurityException("循環または重複した項目を検出しました")
                        }
                        if (
                            flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT != 0
                        ) {
                            throw IOException("仮想ドキュメントは読み込めません")
                        }

                        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                            try {
                                readChildren(documentId, relativePath)
                            } catch (error: SecurityException) {
                                addFailure(relativePath, error.message ?: "権限がありません")
                            } catch (error: IOException) {
                                addFailure(relativePath, error.message ?: "フォルダーを読み込めません")
                            } catch (error: IllegalArgumentException) {
                                addFailure(relativePath, error.message ?: "フォルダー情報が不正です")
                            } catch (error: UnsupportedOperationException) {
                                addFailure(relativePath, error.message ?: "フォルダーを読み込めません")
                            }
                        } else if (name.lowercase(Locale.ROOT).endsWith(".md")) {
                            val bytes = contentResolver.openInputStream(documentUri)?.use {
                                it.readBytes()
                            } ?: throw FileNotFoundException("ファイルを開けません")
                            val content = StandardCharsets.UTF_8.newDecoder()
                                .onMalformedInput(CodingErrorAction.REPORT)
                                .onUnmappableCharacter(CodingErrorAction.REPORT)
                                .decode(ByteBuffer.wrap(bytes))
                                .toString()
                            notes.add(mapOf("path" to relativePath, "content" to content))
                        }
                    } catch (error: SecurityException) {
                        addFailure(relativePath, error.message ?: "権限がありません")
                    } catch (error: IOException) {
                        addFailure(relativePath, error.message ?: "ファイルを読み込めません")
                    } catch (error: IllegalArgumentException) {
                        addFailure(relativePath, error.message ?: "ファイル情報が不正です")
                    } catch (error: UnsupportedOperationException) {
                        addFailure(relativePath, error.message ?: "ファイルを読み込めません")
                    }
                }
            }
        }

        readChildren(rootDocumentId, "")
        return mapOf("notes" to notes, "failures" to failures)
    }

    private companion object {
        const val TEST_FOLDER_PICKER_REQUEST_CODE = 1073
        const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
        const val TEST_FOLDER_DOCUMENT_ID_PREFIX =
            "primary:Documents/TodoSdd_IntegrationTest_"
    }
}
