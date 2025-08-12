// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:device_info_plus/device_info_plus.dart';
//
// class PermissionService {
//   Future<bool> requestPermissions(BuildContext context) async {
//     try {
//       final deviceInfo = DeviceInfoPlugin();
//       final androidInfo = await deviceInfo.androidInfo;
//       final sdkInt = androidInfo.version.sdkInt;
//       Permission targetPermission = sdkInt >= 33 ? Permission.photos : Permission.storage;
//
//       final status = await targetPermission.status;
//       if (status.isGranted) return true;
//       if (status.isPermanentlyDenied) {
//         _showPermissionDialog(context);
//         return false;
//       }
//       final requestStatus = await targetPermission.request();
//       if (requestStatus.isGranted) return true;
//       if (requestStatus.isPermanentlyDenied) {
//         _showPermissionDialog(context);
//         return false;
//       }
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Permission denied. Please allow access to photos.'),
//             action: SnackBarAction(label: 'Retry', onPressed: () => requestPermissions(context)),
//           ),
//         );
//       }
//       return false;
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Permission error. Please try again.')),
//         );
//       }
//       return false;
//     }
//   }
//
//   void _showPermissionDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: const Text('Permission Required'),
//         content: const Text('This app needs access to your photos to upload images. Please enable it in app settings.'),
//         actions: [
//           TextButton(
//             child: const Text('Cancel'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           TextButton(
//             child: const Text('Settings'),
//             onPressed: () async {
//               Navigator.of(context).pop();
//               await openAppSettings();
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }