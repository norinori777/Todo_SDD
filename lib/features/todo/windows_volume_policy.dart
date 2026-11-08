import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

bool isVerifiedWindowsVolume(int driveType, String fileSystem) {
  return driveType == DRIVE_FIXED && fileSystem.toUpperCase() == 'NTFS';
}

bool isSameWindowsVolume(String rootVolumePath, String fileVolumePath) {
  final rootPrefix = path.windows.rootPrefix(rootVolumePath);
  final filePrefix = path.windows.rootPrefix(fileVolumePath);
  final volumePrefix = RegExp(
    r'^\\\\\?\\Volume\{[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}\\?$',
    caseSensitive: false,
  );
  if (!volumePrefix.hasMatch(rootPrefix) ||
      !volumePrefix.hasMatch(filePrefix)) {
    return false;
  }
  return path.windows.equals(rootPrefix, filePrefix);
}
