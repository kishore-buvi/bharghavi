import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<bool> _requestPermissions(BuildContext context) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      Permission targetPermission = sdkInt >= 33 ? Permission.photos : Permission.storage;

      final status = await targetPermission.status;
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        _showPermissionDialog(context);
        return false;
      } else {
        final requestStatus = await targetPermission.request();
        if (requestStatus.isGranted) {
          return true;
        } else if (requestStatus.isPermanentlyDenied) {
          _showPermissionDialog(context);
          return false;
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Permission denied. Please allow access to photos.'),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _requestPermissions(context),
                ),
              ),
            );
          }
          return false;
        }
      }
    } catch (e) {
      print('Error requesting permission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission error. Please try again.')),
        );
      }
      return false;
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('This app needs access to your photos to upload images. Please enable it in app settings.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<File?> pickImage(BuildContext context) async {
    try {
      final hasPermission = await _requestPermissions(context);
      if (!hasPermission) return null;

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image. Please try again.')),
        );
      }
      return null;
    }
  }
}