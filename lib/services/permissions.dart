import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> requestStoragePermission() async {
  final PermissionStatus status = await Permission.storage.request();
  return status == PermissionStatus.granted;
}

Future<bool> checkStoragePermission() async {
  PermissionStatus storagePermissionStatus = await Permission.storage.status;
  if (storagePermissionStatus == PermissionStatus.granted) {
    return true;
  } else {
    return false;
  }
}

Future<bool> checkAllPermissions() async {
  bool storagePermissionStatus = await checkStoragePermission();
  if (storagePermissionStatus) {
    return true;
  } else {
    return false;
  }
}

Future<String?> getExternalStoragePath() async {
  try {
    if (Platform.isAndroid) {
      final PermissionStatus status = await Permission.storage.request();
      if (status.isGranted) {
        final Directory? directory = await getExternalStorageDirectory();
        return directory?.path;
      } else {
        return null;
      }
    } else if (Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    } else {
      return null;
    }
  } on PlatformException catch (e) {
    print('Error: ${e.toString()}');
    return null;
  }
}
