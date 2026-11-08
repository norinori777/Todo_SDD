import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

import 'windows_volume_policy.dart';

class SecureFileReader {
  SecureFileReader._(this._rootHandle, this._rootPath, this._rootVolumePath);

  final int _rootHandle;
  final String _rootPath;
  final String _rootVolumePath;

  static SecureFileReader open(Directory root) {
    if (!Platform.isWindows) {
      throw FileSystemException('安全なファイル読み込みに対応していません', root.path);
    }
    final handle = _open(root.path, 0, FILE_FLAG_BACKUP_SEMANTICS);
    try {
      final finalPath = _finalPath(handle, root.path);
      if (!path.windows.equals(
        path.windows.absolute(root.path),
        _windowsPath(finalPath),
      )) {
        throw FileSystemException('リンクを含むルートは利用できません', root.path);
      }
      final volume = _volumeInfo(handle, root.path);
      final drive = path.windows.rootPrefix(_windowsPath(finalPath));
      final drivePath = drive.toNativeUtf16();
      try {
        if (!isVerifiedWindowsVolume(
          GetDriveType(drivePath),
          volume.fileSystem,
        )) {
          throw FileSystemException('未検証のボリュームは利用できません', root.path);
        }
      } finally {
        calloc.free(drivePath);
      }
      final volumePath = _finalPath(handle, root.path, flags: VOLUME_NAME_GUID);
      if (!isSameWindowsVolume(volumePath, volumePath)) {
        throw FileSystemException('ボリュームの識別子が不正です', root.path);
      }
      return SecureFileReader._(handle, finalPath, volumePath);
    } catch (_) {
      _close(handle, root.path);
      rethrow;
    }
  }

  String read(String relativePath) {
    final filePath = path.joinAll([
      _rootPath,
      ...path.posix.split(relativePath),
    ]);
    final handle = _open(filePath, GENERIC_READ, FILE_ATTRIBUTE_NORMAL);
    try {
      final finalPath = _finalPath(handle, filePath);
      if (!path.windows.isWithin(_rootPath, finalPath)) {
        throw FileSystemException('指定フォルダー外のファイルです', relativePath);
      }
      _checkVolume(handle, relativePath);

      final buffer = calloc<Uint8>(65536);
      final bytesRead = calloc<Uint32>();
      try {
        final bytes = BytesBuilder();
        while (true) {
          if (ReadFile(handle, buffer, 65536, bytesRead, nullptr) == 0) {
            throw FileSystemException(
              'ファイルの読み込みに失敗しました',
              relativePath,
              OSError('ReadFile', GetLastError()),
            );
          }
          if (bytesRead.value == 0) break;
          bytes.add(buffer.asTypedList(bytesRead.value));
        }
        try {
          return utf8.decode(bytes.takeBytes());
        } on FormatException {
          throw FileSystemException('UTF-8をデコードできません', relativePath);
        }
      } finally {
        calloc.free(bytesRead);
        calloc.free(buffer);
      }
    } finally {
      _close(handle, relativePath);
    }
  }

  int openDirectory(String relativePath) {
    final directoryPath = path.joinAll([
      _rootPath,
      ...path.posix.split(relativePath),
    ]);
    final handle = _open(directoryPath, 0, FILE_FLAG_BACKUP_SEMANTICS);
    try {
      if (!path.windows.isWithin(
        _rootPath,
        _finalPath(handle, directoryPath),
      )) {
        throw FileSystemException('指定フォルダー外のフォルダーです', relativePath);
      }
      _checkVolume(handle, relativePath);
      return handle;
    } catch (_) {
      _close(handle, relativePath);
      rethrow;
    }
  }

  void closeDirectory(int handle) {
    _close(handle, _rootPath);
  }

  void close() {
    closeDirectory(_rootHandle);
  }

  void _checkVolume(int handle, String relativePath) {
    final volumePath = _finalPath(
      handle,
      relativePath,
      flags: VOLUME_NAME_GUID,
    );
    if (!isSameWindowsVolume(_rootVolumePath, volumePath)) {
      throw FileSystemException('異なるボリュームは利用できません', relativePath);
    }
  }
}

({String fileSystem}) _volumeInfo(int handle, String filePath) {
  final name = calloc<Uint16>(256).cast<Utf16>();
  try {
    if (GetVolumeInformationByHandle(
          handle,
          nullptr,
          0,
          nullptr,
          nullptr,
          nullptr,
          name,
          256,
        ) ==
        0) {
      throw FileSystemException(
        'ボリューム情報を取得できません',
        filePath,
        OSError('GetVolumeInformationByHandle', GetLastError()),
      );
    }
    return (fileSystem: name.toDartString());
  } finally {
    calloc.free(name);
  }
}

void _close(int handle, String filePath) {
  if (CloseHandle(handle) == 0) {
    throw FileSystemException(
      'ハンドルを閉じられません',
      filePath,
      OSError('CloseHandle', GetLastError()),
    );
  }
}

String _windowsPath(String extendedPath) {
  const unc = r'\\?\UNC\';
  const prefix = r'\\?\';
  if (extendedPath.startsWith(unc)) {
    return r'\\' + extendedPath.substring(unc.length);
  }
  if (extendedPath.startsWith(prefix)) {
    return extendedPath.substring(prefix.length);
  }
  return extendedPath;
}

int _open(String filePath, int access, int flags) {
  final nativePath = filePath.toNativeUtf16();
  try {
    final handle = CreateFile(
      nativePath,
      access,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      nullptr,
      OPEN_EXISTING,
      flags,
      0,
    );
    if (handle == INVALID_HANDLE_VALUE) {
      throw FileSystemException(
        'ファイルを開けません',
        filePath,
        OSError('CreateFile', GetLastError()),
      );
    }
    return handle;
  } finally {
    calloc.free(nativePath);
  }
}

String _finalPath(int handle, String filePath, {int flags = 0}) {
  final required = GetFinalPathNameByHandle(handle, nullptr, 0, flags);
  if (required == 0) {
    throw FileSystemException(
      '開いたファイルのパスを取得できません',
      filePath,
      OSError('GetFinalPathNameByHandle', GetLastError()),
    );
  }
  final buffer = calloc<Uint16>(required + 1).cast<Utf16>();
  try {
    final length = GetFinalPathNameByHandle(
      handle,
      buffer,
      required + 1,
      flags,
    );
    if (length == 0 || length > required) {
      throw FileSystemException(
        '開いたファイルのパスを取得できません',
        filePath,
        OSError('GetFinalPathNameByHandle', GetLastError()),
      );
    }
    return buffer.toDartString(length: length);
  } finally {
    calloc.free(buffer);
  }
}
