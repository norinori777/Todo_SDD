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
    private var pendingFolderResult: MethodChannel.Result? = null
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
                        } else if (uri.authority != EXTERNAL_STORAGE_AUTHORITY) {
                            result.error(
                                "unsupported_provider",
                                "対応していないフォルダー提供元です",
                                null,
                            )
                        } else {
                            try {
                                val permission = contentResolver.persistedUriPermissions
                                    .firstOrNull { it.uri == uri }
                                if (permission == null || !permission.isReadPermission) {
                                    result.success(false)
                                } else if (!permission.isWritePermission) {
                                    result.error(
                                        "permission_denied",
                                        "フォルダーの永続書込権限がありません",
                                        null,
                                    )
                                } else {
                                    result.success(true)
                                }
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
                        val uri = Uri.parse(value)
                        if (uri.authority != EXTERNAL_STORAGE_AUTHORITY) {
                            result.error(
                                "unsupported_provider",
                                "対応していないフォルダー提供元です",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                            )
                            val permission = contentResolver.persistedUriPermissions
                                .firstOrNull { it.uri == uri }
                            if (
                                permission == null ||
                                !permission.isReadPermission ||
                                !permission.isWritePermission
                            ) {
                                result.error(
                                    "permission_denied",
                                    "フォルダーの永続読取・書込権限を取得できませんでした",
                                    null,
                                )
                                return@setMethodCallHandler
                            }
                            val stored = getSharedPreferences(
                                "todo_sdd_settings",
                                MODE_PRIVATE,
                            )
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
                "pickFolder" -> {
                    if (pendingFolderResult != null) {
                        result.error(
                            "selection_in_progress",
                            "フォルダー選択がすでに実行中です",
                            null,
                        )
                    } else {
                        pendingFolderResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
                            )
                        }
                        try {
                            startActivityForResult(intent, FOLDER_PICKER_REQUEST_CODE)
                        } catch (error: ActivityNotFoundException) {
                            pendingFolderResult = null
                            result.error(
                                "picker_unavailable",
                                "フォルダー選択画面を開けません",
                                null,
                            )
                        } catch (error: SecurityException) {
                            pendingFolderResult = null
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
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
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
                                val permission = contentResolver.persistedUriPermissions
                                    .firstOrNull { it.uri == uri }
                                if (permission != null) {
                                    var flags = 0
                                    if (permission.isReadPermission) {
                                        flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    }
                                    if (permission.isWritePermission) {
                                        flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                                    }
                                    contentResolver.releasePersistableUriPermission(
                                        uri,
                                        flags,
                                    )
                                }
                                result.success(null)
                            } catch (error: SecurityException) {
                                result.error("permission_denied", error.message, null)
                            }
                        }
                    }
                }
                "createMarkdown" -> handleCreateMarkdown(call.arguments, result)
                "testCreateMarkdown" -> {
                    if (!isDebugBuild()) {
                        result.notImplemented()
                    } else {
                        val arguments = call.arguments as? Map<*, *>
                        val folderValue = arguments?.get("uri") as? String
                        val testFailure = arguments?.get("failure") as? String
                        val treeUri = folderValue?.let(Uri::parse)
                        if (treeUri == null || !isTestFolderUri(treeUri)) {
                            result.error(
                                "invalid_test_folder",
                                "失敗注入は専用のテストフォルダーでのみ利用できます",
                                null,
                            )
                        } else if (
                            testFailure !in setOf("open", "write", "close", "cleanup", "renamed")
                        ) {
                            result.error(
                                "invalid_test_failure",
                                "テスト用の失敗種別が不正です",
                                null,
                            )
                        } else {
                            handleCreateMarkdown(call.arguments, result, testFailure)
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

    private fun handleCreateMarkdown(
        argumentsValue: Any?,
        result: MethodChannel.Result,
        testFailure: String? = null,
    ) {
        val arguments = argumentsValue as? Map<*, *>
        val folderValue = arguments?.get("uri") as? String
        val fileName = arguments?.get("name") as? String
        val content = arguments?.get("content") as? String
        if (folderValue == null || fileName == null || content == null) {
            result.error("invalid_name", "Markdown作成の引数が不正です", null)
            return
        }

        try {
            result.success(
                createMarkdown(
                    Uri.parse(folderValue),
                    fileName,
                    content,
                    testFailure,
                ),
            )
        } catch (error: TodoCreateException) {
            result.error(error.code, error.message, error.details)
        } catch (error: SecurityException) {
            result.error("permission_denied", error.message, null)
        } catch (error: IOException) {
            result.error("write_failed", error.message, null)
        } catch (error: IllegalArgumentException) {
            result.error("write_failed", error.message, null)
        } catch (error: UnsupportedOperationException) {
            result.error("write_failed", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FOLDER_PICKER_REQUEST_CODE) {
            completeFolderSelection(
                if (resultCode == RESULT_OK) data else null,
            )
        }
        if (requestCode == TEST_FOLDER_PICKER_REQUEST_CODE) {
            completeTestFolderSelection(
                if (resultCode == RESULT_OK) data else null,
            )
        }
    }

    private fun completeFolderSelection(data: Intent?) {
        val callback = pendingFolderResult ?: return
        pendingFolderResult = null

        val selectedData = data
        if (selectedData == null) {
            callback.error("selection_cancelled", "フォルダー選択がキャンセルされました", null)
            return
        }
        val uri = selectedData.data
        if (uri == null) {
            callback.error("selection_cancelled", "フォルダー選択がキャンセルされました", null)
            return
        }
        if (
            !DocumentsContract.isTreeUri(uri) ||
            uri.authority != EXTERNAL_STORAGE_AUTHORITY
        ) {
            callback.error(
                "unsupported_provider",
                "対応していないフォルダー提供元です",
                null,
            )
            return
        }
        val requiredFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if ((selectedData.flags and requiredFlags) != requiredFlags) {
            callback.error(
                "permission_denied",
                "選択したフォルダーの読取・書込権限がありません",
                null,
            )
            return
        }

        try {
            contentResolver.takePersistableUriPermission(uri, requiredFlags)
            val permission = contentResolver.persistedUriPermissions
                .firstOrNull { it.uri == uri }
            if (
                permission == null ||
                !permission.isReadPermission ||
                !permission.isWritePermission
            ) {
                callback.error(
                    "permission_denied",
                    "フォルダーの永続読取・書込権限を取得できませんでした",
                    null,
                )
                return
            }
            val stored = getSharedPreferences("todo_sdd_settings", MODE_PRIVATE)
                .edit()
                .putString("folder_uri", uri.toString())
                .commit()
            if (!stored) {
                try {
                    contentResolver.releasePersistableUriPermission(uri, requiredFlags)
                } catch (error: SecurityException) {
                    callback.error(
                        "storage_error",
                        "フォルダー設定を保存できず、取得した権限も解除できませんでした",
                        mapOf("uri" to uri.toString(), "cause" to error.message),
                    )
                    return
                }
                callback.error("storage_error", "フォルダー設定を保存できません", null)
                return
            }
            callback.success(uri.toString())
        } catch (error: SecurityException) {
            callback.error("permission_denied", error.message, null)
        }
    }

    private fun completeTestFolderSelection(data: Intent?) {
        val callback = pendingTestFolderResult ?: return
        val expectedDocumentId = expectedTestFolderDocumentId
        pendingTestFolderResult = null
        expectedTestFolderDocumentId = null

        val selectedData = data
        if (selectedData == null) {
            callback.error("selection_cancelled", "フォルダー選択がキャンセルされました", null)
            return
        }
        val uri = selectedData.data
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
                mapOf(
                    "expectedDocumentId" to expectedDocumentId,
                    "selectedUri" to uri?.toString(),
                    "selectedDocumentId" to uri?.let {
                        if (DocumentsContract.isTreeUri(it)) {
                            DocumentsContract.getTreeDocumentId(it)
                        } else {
                            null
                        }
                    },
                ),
            )
            return
        }
        val requiredFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if ((selectedData.flags and requiredFlags) != requiredFlags) {
            callback.error(
                "permission_denied",
                "選択したフォルダーの読取・書込権限がありません",
                null,
            )
            return
        }

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                requiredFlags,
            )
            val permission = contentResolver.persistedUriPermissions
                .firstOrNull { it.uri == uri }
            val hasAccess =
                permission != null &&
                    permission.isReadPermission &&
                    permission.isWritePermission
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

    private fun createMarkdown(
        treeUri: Uri,
        fileName: String,
        content: String,
        testFailure: String? = null,
    ): Map<String, String> {
        if (!DocumentsContract.isTreeUri(treeUri)) {
            throw TodoCreateException("invalid_uri", "無効なフォルダーURIです")
        }
        if (treeUri.authority != EXTERNAL_STORAGE_AUTHORITY) {
            throw TodoCreateException(
                "unsupported_provider",
                "対応していないフォルダー提供元です",
            )
        }
        if (
            fileName.isBlank() ||
            fileName == "." ||
            fileName == ".." ||
            '/' in fileName ||
            '\\' in fileName ||
            fileName.any { it.code <= 0x1f || it.code == 0x7f }
        ) {
            throw TodoCreateException("invalid_name", "安全なMarkdownファイル名ではありません")
        }

        val permission = contentResolver.persistedUriPermissions
            .firstOrNull { it.uri == treeUri }
        if (permission == null || !permission.isReadPermission || !permission.isWritePermission) {
            throw TodoCreateException(
                "permission_denied",
                "フォルダーの永続読取・書込権限がありません",
            )
        }

        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootUri =
            DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
        val root = queryDocument(rootUri)
        if (
            root.mimeType != DocumentsContract.Document.MIME_TYPE_DIR ||
            root.flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE == 0
        ) {
            throw TodoCreateException(
                "write_failed",
                "保存先フォルダーは新規ファイル作成に対応していません",
            )
        }

        val collision = queryChildren(treeUri, rootDocumentId).firstOrNull {
            it.displayName.equals(fileName, ignoreCase = true)
        }
        if (collision != null) {
            val existingUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                collision.documentId,
            )
            if (!DocumentsContract.isChildDocument(contentResolver, rootUri, existingUri)) {
                throw TodoCreateException(
                    "write_failed",
                    "保存先の直下を安全に確認できません",
                )
            }
            throw TodoCreateException(
                "already_exists",
                "保存先直下に「${collision.displayName}」がすでに存在します",
            )
        }

        var createdUri: Uri? = null
        var residualPath = fileName
        try {
            createdUri = DocumentsContract.createDocument(
                contentResolver,
                rootUri,
                "text/markdown",
                fileName,
            ) ?: throw TodoCreateException(
                "invalid_name",
                "保存先が新しいMarkdownファイルを作成できませんでした",
            )

            val created = queryDocument(createdUri)
            residualPath = created.displayName
            val documentPath = DocumentsContract.findDocumentPath(
                contentResolver,
                createdUri,
            )?.path ?: throw FileNotFoundException("作成したファイルの位置を確認できません")
            val isDirectChild =
                DocumentsContract.isChildDocument(contentResolver, rootUri, createdUri) &&
                    documentPath.size == 2 &&
                    documentPath.first() == rootDocumentId &&
                    documentPath.last() == created.documentId
            if (
                !isDirectChild ||
                created.displayName != fileName ||
                testFailure == "renamed"
            ) {
                throw TodoCreateException(
                    "already_exists",
                    "保存先が別名のファイルを作成したため作成を取り消しました",
                )
            }
            if (created.flags and DocumentsContract.Document.FLAG_SUPPORTS_WRITE == 0) {
                throw TodoCreateException(
                    "write_failed",
                    "保存先が作成したファイルへの書き込みに対応していません",
                )
            }

            if (testFailure == "open" || testFailure == "cleanup") {
                throw FileNotFoundException("テスト用にファイルを開けない状態を再現しました")
            }
            val output = contentResolver.openOutputStream(createdUri, "wt")
                ?: throw FileNotFoundException("作成したファイルを開けません")
            val stream = if (testFailure == "close") {
                object : java.io.FilterOutputStream(output) {
                    override fun close() {
                        super.close()
                        throw IOException("テスト用にclose失敗を再現しました")
                    }
                }
            } else {
                output
            }
            stream.use {
                if (testFailure == "write") {
                    throw IOException("テスト用にwrite失敗を再現しました")
                }
                it.write(content.toByteArray(StandardCharsets.UTF_8))
                it.flush()
            }
            return mapOf("path" to created.displayName)
        } catch (error: TodoCreateException) {
            throw failureAfterCreate(
                createdUri,
                residualPath,
                error.code,
                error.message ?: "Markdown作成に失敗しました",
                error.details,
            )
        } catch (error: SecurityException) {
            throw failureAfterCreate(
                createdUri,
                residualPath,
                "permission_denied",
                error.message ?: "保存先の権限がありません",
            )
        } catch (error: IOException) {
            throw failureAfterCreate(
                createdUri,
                residualPath,
                "write_failed",
                error.message ?: "Markdownを書き込めませんでした",
                testCleanupFailure = testFailure == "cleanup",
            )
        } catch (error: IllegalArgumentException) {
            throw failureAfterCreate(
                createdUri,
                residualPath,
                "write_failed",
                error.message ?: "保存先から不正な情報が返されました",
            )
        } catch (error: UnsupportedOperationException) {
            throw failureAfterCreate(
                createdUri,
                residualPath,
                "write_failed",
                error.message ?: "保存先の書き込み操作に対応していません",
            )
        }
    }

    private fun failureAfterCreate(
        createdUri: Uri?,
        residualPath: String,
        code: String,
        message: String,
        details: Any? = null,
        testCleanupFailure: Boolean = false,
    ): TodoCreateException {
        if (createdUri == null) return TodoCreateException(code, message, details)

        return try {
            if (testCleanupFailure) {
                throw IOException("テスト用に後始末失敗を再現しました")
            }
            if (DocumentsContract.deleteDocument(contentResolver, createdUri)) {
                TodoCreateException(code, message, details)
            } else {
                residualFileFailure(residualPath, message, "削除要求が拒否されました")
            }
        } catch (error: SecurityException) {
            residualFileFailure(
                residualPath,
                message,
                error.message ?: "削除権限がありません",
            )
        } catch (error: IOException) {
            residualFileFailure(
                residualPath,
                message,
                error.message ?: "削除時に入出力エラーが発生しました",
            )
        } catch (error: UnsupportedOperationException) {
            residualFileFailure(
                residualPath,
                message,
                error.message ?: "保存先が削除に対応していません",
            )
        }
    }

    private fun residualFileFailure(
        residualPath: String,
        message: String,
        cleanupMessage: String,
    ) = TodoCreateException(
        "write_failed",
        "$message。不完全なファイル「$residualPath」が残っています。保存先で確認し、手動で削除してください。",
        mapOf("residualPath" to residualPath, "cleanupError" to cleanupMessage),
    )

    private fun queryDocument(uri: Uri): SafDocument {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        val cursor = contentResolver.query(uri, projection, null, null, null)
            ?: throw FileNotFoundException("保存先の項目情報を取得できません")
        cursor.use {
            if (!it.moveToFirst()) {
                throw FileNotFoundException("保存先の項目情報がありません")
            }
            return SafDocument(
                it.getString(
                    it.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    ),
                ),
                it.getString(
                    it.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    ),
                ),
                it.getString(
                    it.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                    ),
                ),
                it.getLong(
                    it.getColumnIndexOrThrow(
                        DocumentsContract.Document.COLUMN_FLAGS,
                    ),
                ).toInt(),
            )
        }
    }

    private fun queryChildren(treeUri: Uri, parentDocumentId: String): List<SafDocument> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentDocumentId,
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        val cursor = contentResolver.query(childrenUri, projection, null, null, null)
            ?: throw FileNotFoundException("保存先の内容を取得できません")
        cursor.use {
            val documents = mutableListOf<SafDocument>()
            while (it.moveToNext()) {
                documents.add(
                    SafDocument(
                        it.getString(
                            it.getColumnIndexOrThrow(
                                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                            ),
                        ),
                        it.getString(
                            it.getColumnIndexOrThrow(
                                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                            ),
                        ),
                        it.getString(
                            it.getColumnIndexOrThrow(
                                DocumentsContract.Document.COLUMN_MIME_TYPE,
                            ),
                        ),
                        it.getLong(
                            it.getColumnIndexOrThrow(
                                DocumentsContract.Document.COLUMN_FLAGS,
                            ),
                        ).toInt(),
                    ),
                )
            }
            return documents
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
        const val FOLDER_PICKER_REQUEST_CODE = 1072
        const val TEST_FOLDER_PICKER_REQUEST_CODE = 1073
        const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
        const val TEST_FOLDER_DOCUMENT_ID_PREFIX =
            "primary:Documents/TodoSdd_IntegrationTest_"
    }

    private data class SafDocument(
        val documentId: String,
        val displayName: String,
        val mimeType: String,
        val flags: Int,
    )

    private class TodoCreateException(
        val code: String,
        override val message: String,
        val details: Any? = null,
    ) : Exception(message)
}
