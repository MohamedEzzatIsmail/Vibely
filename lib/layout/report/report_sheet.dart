import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';

class ReportSheet {
  static void show(BuildContext context, {
    required String targetUid,
    required String targetType, // 'post' | 'user' | 'comment'
    String? postId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF20262c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportSheet(
        targetUid: targetUid,
        targetType: targetType,
        postId: postId,
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String targetUid;
  final String targetType;
  final String? postId;
  const _ReportSheet({required this.targetUid, required this.targetType, this.postId});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selected;
  bool _submitting = false;

  static const List<String> _reasons = [
    'Spam or misleading',
    'Nudity or sexual content',
    'Hate speech or symbols',
    'Violence or dangerous acts',
    'Bullying or harassment',
    'Intellectual property violation',
    'Scam or fraud',
    'Other',
  ];

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('Reports').add({
        'reportedBy': FirebaseAuth.instance.currentUser?.uid,
        'targetUid': widget.targetUid,
        'targetType': widget.targetType,
        'postId': widget.postId,
        'reason': _selected,
        'dateTime': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).reportThanks),
            backgroundColor: const Color(0xFF2e7d32),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text(AppStrings.of(context).reportTitle, style: TextStyle(color: Color(0xFFe5c687), fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(AppStrings.of(context).whyReporting, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          ..._reasons.map((r) => RadioListTile<String>(
            dense: true,
            value: r,
            groupValue: _selected,
            activeColor: const Color(0xFFe5c687),
            title: Text(r, style: TextStyle(color: AppColors.of(context).text, fontSize: 14)),
            onChanged: (v) => setState(() => _selected = v),
          )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe5c687),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _selected == null || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(AppStrings.of(context).submitReport2, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
