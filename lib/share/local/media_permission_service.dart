import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPermissionService {
  MediaPermissionService._();

  static Future<bool> hasPermission() async {
    final status = await _mediaPermission().status;
    return status.isGranted || status.isLimited;
  }

  static Future<bool> requestMediaPermission(BuildContext context) async {
    final permission = _mediaPermission();
    var status = await permission.status;

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) await _showSettingsDialog(context);
      return false;
    }

    status = await permission.request();

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(context);
    } else if (status.isDenied && context.mounted) {
      _showDeniedSnack(context);
    }

    return false;
  }

  static Future<bool> requestWithRationale(BuildContext context) async {
    if (await hasPermission()) return true;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: false,
      isScrollControlled: true,
      builder: (_) => const _PermissionRationaleSheet(),
    );

    if (agreed != true) return false;
    return requestMediaPermission(context);
  }

  static Permission _mediaPermission() => Permission.photos;

  static Future<void> _showSettingsDialog(BuildContext context) async {
    final s = AppStrings.of(context);
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF21262d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.permissionRequired,
            style: TextStyle(color: AppColors.of(context).text, fontWeight: FontWeight.bold)),
        content: Text(
          s.permissionSettingsBody,
          style: TextStyle(color: AppColors.of(context).textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.notNow, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe5c687),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.openSettings,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (open == true) await openAppSettings();
  }

  static void _showDeniedSnack(BuildContext context) {
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.mediaDeniedSnack),
        backgroundColor: const Color(0xFFc0392b),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: s.settingsLabel,
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
      ),
    );
  }
}

class _PermissionRationaleSheet extends StatelessWidget {
  const _PermissionRationaleSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFe5c687).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_rounded,
                color: Color(0xFFe5c687), size: 36),
          ),
          const SizedBox(height: 16),
          Text(s.allowMediaAccess,
              style: TextStyle(
                  color: AppColors.of(context).text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            s.allowMediaBody,
            style: TextStyle(color: AppColors.of(context).textSub, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe5c687),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.allowAccess,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.dontAllow,
                  style: const TextStyle(color: Colors.grey, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
