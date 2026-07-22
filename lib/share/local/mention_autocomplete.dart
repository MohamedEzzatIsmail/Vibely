// lib/share/local/mention_autocomplete.dart
//
// When the user types '@' in a TextEditingController, this widget shows a
// floating list of up to 5 matching users and inserts '@username' on tap.
//
// Usage:
//   Wrap your input scaffold in a Stack and add MentionOverlay as the second
//   layer.  Pass the controller and a callback to receive the selected user UID.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MentionAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String uid, String username) onMentionSelected;

  const MentionAutocomplete({
    super.key,
    required this.controller,
    required this.onMentionSelected,
  });

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  List<Map<String, dynamic>> _results = [];
  bool _visible = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final before = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(before);

    if (match != null) {
      final q = match.group(1) ?? '';
      if (q != _query) {
        _query = q;
        _search(q);
      }
    } else {
      setState(() {
        _visible = false;
        _results = [];
        _query = '';
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _visible = false;
        _results = [];
      });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();

      setState(() {
        _results = snap.docs.map((d) => d.data()).toList();
        _visible = _results.isNotEmpty;
      });
    } catch (_) {}
  }

  void _selectUser(Map<String, dynamic> user) {
    final username = (user['name'] as String? ?? '').replaceAll(' ', '_');
    final uid = user['uid'] as String? ?? '';
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final newBefore = before.replaceAll(RegExp(r'@\w*$'), '@$username ');
    widget.controller.value = TextEditingValue(
      text: '$newBefore$after',
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    widget.onMentionSelected(uid, username);
    setState(() {
      _visible = false;
      _results = [];
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _results.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final user = _results[i];
          final name = user['name'] as String? ?? '';
          final image = user['image'] as String?;
          return InkWell(
            onTap: () => _selectUser(user),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: image != null && image.isNotEmpty
                        ? CachedNetworkImageProvider(image)
                        : null,
                    backgroundColor: Colors.white12,
                    child: image == null || image.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white38, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
