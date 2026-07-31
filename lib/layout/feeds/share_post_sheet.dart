import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../cubit/chat/chat_cubit.dart';
import '../cubit/cubit.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../share/local/media_permission_service.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';



class SharePostSheet {
  static void show(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => BlocProviderWrapper(context: context, child: _ShareSheet(post: post)),
    );
  }
}

// Pass existing BLoC providers into the new modal context
class BlocProviderWrapper extends StatelessWidget {
  final BuildContext context;
  final Widget child;
  const BlocProviderWrapper({required this.context, required this.child, super.key});

  @override
  Widget build(BuildContext ctx) {
    // Re-use the cubits from the parent context so they're available inside the sheet
    final chatCubit = ChatCubit.get(context);
    final mainCubit = MainCubit.get(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: chatCubit),
        BlocProvider.value(value: mainCubit),
      ],
      child: child,
    );
  }
}


class _ShareSheet extends StatefulWidget {
  final PostModel post;
  const _ShareSheet({required this.post});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _captionCtrl  = TextEditingController();
  List<UserModel> _users = [];
  bool  _loading    = true;
  List<File> _selectedPhotos = [];
  String?    _sendingTo;           // uid currently being sent to
  final Set<String> _sentTo = {}; // uids already successfully sent

  @override
  void initState() { super.initState(); _loadUsers(); }

  @override
  void dispose() { _captionCtrl.dispose(); super.dispose(); }

  Future<void> _loadUsers() async {
    final mainCubit = MainCubit.get(context);
    final myUid     = mainCubit.model?.uid;
    try {
      // Prefer showing following users first, then fall back to all users
      final followingUids = mainCubit.model?.followingUids ?? [];
      List<UserModel> users = [];

      if (followingUids.isNotEmpty) {
        // Fetch in chunks of 30 (Firestore whereIn limit)
        for (var i = 0; i < followingUids.length; i += 30) {
          final chunk = followingUids.sublist(i, (i + 30).clamp(0, followingUids.length));
          final snap  = await FirebaseFirestore.instance
              .collection('Users')
              .where('uid', whereIn: chunk)
              .get();
          users.addAll(snap.docs.map((d) => UserModel.fromJson(d.data())));
        }
      }

      // If not following anyone yet, show all users (new user experience)
      if (users.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('Users')
            .limit(50)
            .get();
        users = snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
      }

      users = users.where((u) => u.uid != null && u.uid != myUid).toList();
      users.sort((a, b) {
        // Online users first, then alphabetical
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return (a.name ?? '').compareTo(b.name ?? '');
      });

      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // vibely:// opens the app directly via the intent-filter (no server needed).
  // On Android, vibely:// links ARE shown as tappable blue text in WhatsApp.
  String get _postUrl => 'https://vibely-official.web.app/post/${widget.post.postId}';
  String get _webUrl  => 'https://vibely-official.web.app/post/${widget.post.postId}';

  void _shareExternal() {
    // Send ONLY the bare https:// URL so every app renders it as a clickable link.
    SharePlus.instance.share(ShareParams(text: _webUrl, subject: 'Check this post on Vibely'));
  }

  Future<void> _shareWhatsApp() async {
    final text = Uri.encodeComponent(_webUrl);
    final uri  = Uri.parse('https://wa.me/?text=$text');

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      await Clipboard.setData(ClipboardData(text: _webUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp not found — link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp'),
          backgroundColor: Color(0xFFc0392b),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyLink() {
    // Copy the https URL — it's human-readable, clickable in any messaging app,
    // and the Android intent-filter / iOS URL scheme opens it in Vibely.
    Clipboard.setData(ClipboardData(text: _webUrl));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).linkCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final ok = await MediaPermissionService.requestMediaPermission(context);
    if (!ok) return;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty && mounted) {
      setState(() => _selectedPhotos = picked.map((e) => File(e.path)).toList());
    }
  }

  Future<void> _sendToUser(UserModel user) async {
    if (user.uid == null) return;
    setState(() => _sendingTo = user.uid);
    try {
      final cubit    = ChatCubit.get(context);
      final post     = widget.post;
      final caption  = _captionCtrl.text.trim();
      final imageUrl = (post.postImage?.isNotEmpty == true)
          ? post.postImage!.split(',').first.trim()
          : null;

      await cubit.sendSharedPost(
        receiverId:           user.uid!,
        caption:              caption,
        sharedPostId:         post.postId ?? '',
        sharedPostOwnerName:  post.name ?? '',
        sharedPostOwnerImage: post.image ?? '',
        sharedPostText:       post.text ?? '',
        sharedPostImage:      imageUrl,
        sharedPostVideo:      post.postVideo,
      );

      if (!mounted) return;
      setState(() {
        _sendingTo  = null;
        _sentTo.add(user.uid!); // track who we already sent to
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.of(context).sentTo} ${user.name ?? ''}'),
        backgroundColor: const Color(0xFF2e7d32),
        behavior:  SnackBarBehavior.floating,
        duration:  const Duration(seconds: 2),
        shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.of(context).failedToSend}: ${e.toString().split(']').last.trim()}'),
        backgroundColor: const Color(0xFFc0392b),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.70,
      maxChildSize: 0.95,
      minChildSize: 0.40,
      builder: (_, scroll) => Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          Text(AppStrings.of(context).shareLabel, style: TextStyle(
            color: AppColors.of(context).text, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          // ── Post preview ─────────────────────────────────────────────
          _PostPreview(post: widget.post),
          const SizedBox(height: 14),

          // ── External share buttons ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _ExtBtn(icon: Icons.share_rounded,      label: AppStrings.of(context).shareLabel,    color: const Color(0xFF3b82f6), onTap: _shareExternal),
              const SizedBox(width: 10),
              _ExtBtn(icon: Icons.chat_rounded,       label: 'WhatsApp', color: const Color(0xFF25D366), onTap: _shareWhatsApp),
              const SizedBox(width: 10),
              _ExtBtn(icon: Icons.link_rounded,       label: AppStrings.of(context).copyLink, color: const Color(0xFF6366f1), onTap: _copyLink),
            ]),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),

          // ── Caption + photo picker ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _captionCtrl,
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 14),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add a message…',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true, fillColor: const Color(0xFF21262d),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFe5c687).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFe5c687).withValues(alpha: 0.4)),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFe5c687), size: 24),
                    if (_selectedPhotos.isNotEmpty)
                      Positioned(top: 4, right: 4,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: Color(0xFFe5c687), shape: BoxShape.circle),
                          child: Center(child: Text('${_selectedPhotos.length}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
                        )),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Photo preview strip ──────────────────────────────────────
          if (_selectedPhotos.isNotEmpty)
            SizedBox(height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _selectedPhotos.length,
                itemBuilder: (_, i) => Stack(children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(image: FileImage(_selectedPhotos[i]), fit: BoxFit.cover)),
                  ),
                  Positioned(top: 2, right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPhotos.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(Icons.close, color: AppColors.of(context).text, size: 14)),
                    )),
                ]),
              ),
            ),

          // ── Section header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Text(AppStrings.of(context).sendToLabel, style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!_loading)
                Text('${_users.length} ${AppStrings.of(context).people}', style: const TextStyle(
                  color: Colors.grey, fontSize: 12)),
            ]),
          ),

          // ── Users list ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2))
                : _users.isEmpty
                    ? Center(child: Text(AppStrings.of(context).noUsersYet, style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _users.length,
                        itemBuilder: (_, i) {
                          final u = _users[i];
                          final isSending = _sendingTo == u.uid;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF21262d),
                              backgroundImage: (u.image ?? '').isNotEmpty
                                  ? CachedNetworkImageProvider(u.image!) : null,
                              child: (u.image ?? '').isEmpty
                                  ? Text((u.name ?? '?')[0].toUpperCase(),
                                      style: TextStyle(color: AppColors.of(context).text, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Row(children: [
                              Text(u.name ?? '', style: TextStyle(
                                color: AppColors.of(context).text, fontSize: 14, fontWeight: FontWeight.w500)),
                              if (u.isVerified == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, color: Color(0xFFe5c687), size: 13),
                              ],
                              if (u.isOnline) ...[
                                const SizedBox(width: 6),
                                Container(width: 7, height: 7,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              ],
                            ]),
                            subtitle: u.bio?.isNotEmpty == true
                                ? Text(u.bio!, style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)
                                : null,
                            trailing: SizedBox(
                              width: 72,
                              child: Builder(builder: (_) {
                                final alreadySent = _sentTo.contains(u.uid);
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: alreadySent
                                        ? const Color(0xFF2e7d32)
                                        : const Color(0xFFe5c687),
                                    foregroundColor: alreadySent ? Colors.white : Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: (isSending || alreadySent) ? null : () => _sendToUser(u),
                                  child: isSending
                                      ? const SizedBox(width: 16, height: 16,
                                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                      : alreadySent
                                          ? const Icon(Icons.check_rounded, size: 16)
                                          : Text(AppStrings.of(context).sendLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                );
                              }),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  final PostModel post;
  const _PostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (post.postImage?.isNotEmpty == true)
        ? post.postImage!.split(',').first.trim() : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl, width: 52, height: 52, fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Color(0xFF30363d)),
              errorWidget: (_, _, ___) => const ColoredBox(color: Color(0xFF30363d))),
          ),
        if (imageUrl != null) const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((post.name ?? '').isNotEmpty)
              Text(post.name!, style: const TextStyle(
                color: Color(0xFFe5c687), fontSize: 12, fontWeight: FontWeight.w600)),
            if ((post.text ?? '').isNotEmpty)
              Text(post.text!, style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (post.postVideo?.isNotEmpty == true)
              const Row(children: [
                Icon(Icons.videocam_rounded, color: Colors.grey, size: 14),
                SizedBox(width: 4),
                Text('Video', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
          ],
        )),
      ]),
    );
  }
}

class _ExtBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ExtBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}
