import '../settings/folder_access.dart';

class FolderAccessException implements Exception {
  const FolderAccessException(this.reason);

  final FolderUnavailableReason reason;
}

Future<Uri> requireFolderAccess(FolderAccessSource source) async {
  final access = await source.currentFolder();
  switch (access) {
    case FolderAvailable(:final uri):
      return uri;
    case FolderUnavailable(:final reason):
      throw FolderAccessException(reason);
  }
}
