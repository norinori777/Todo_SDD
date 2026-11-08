sealed class FolderAccess {
  const FolderAccess();
}

class FolderAvailable extends FolderAccess {
  const FolderAvailable(this.uri);

  final Uri uri;
}

class FolderUnavailable extends FolderAccess {
  const FolderUnavailable(this.reason);

  final FolderUnavailableReason reason;
}

enum FolderUnavailableReason { notConfigured, expired, permissionDenied }

abstract interface class FolderAccessSource {
  Future<FolderAccess> currentFolder();
}
