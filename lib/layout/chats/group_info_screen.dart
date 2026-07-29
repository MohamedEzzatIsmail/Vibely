/// Group settings screen: rename, change photo, admin-only-send toggle,
/// member list with add/remove/promote, leave group, and delete group.

import 'dart:io';
import '../../share/style/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../layout/cubit/chat/chat_cubit.dart';
import '../../layout/cubit/chat/chat_states.dart';

// ─── Design tokens (mirror chat.dart) ─────────────────────────────────────────
const _kS2      = Color(0xFF21262D);
const _kGold    = Color(0xFFE5C687);

class GroupInfoScreen extends StatefulWidget {
  final GroupModel group;
  const GroupInfoScreen({super.key, required this.group});
  @override State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupModel _group;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    // Refresh group from cubit in case it changed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = ChatCubit.get(context);
      final fresh = cubit.groups.firstWhere((g) => g.id == _group.id, orElse: () => _group);
      if (mounted) setState(() => _group = fresh);
    });
  }

  bool get _isAdmin => ChatCubit.get(context).currentUser?.uid == _group.adminUid;

  // ── Rename group ────────────────────────────────────────────────────────────
  void _renameGroup() {
    final cubit = ChatCubit.get(context);
    final ctrl  = TextEditingController(text: _group.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).renameGroup, style: TextStyle(color: AppColors.of(context).text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.of(context).text),
          decoration: InputDecoration(
            hintText: AppStrings.of(context).groupName,
            hintStyle: TextStyle(color: AppColors.of(context).textHint),
            filled: true, fillColor: _kS2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await cubit.updateGroupName(groupId: _group.id, newName: name);
              _refreshGroup();
            },
            child: Text(AppStrings.of(context).save, style: const TextStyle(color: _kGold)),
          ),
        ],
      ),
    );
  }

  // ── Change group photo ─────────────────────────────────────────────────────
  Future<void> _changePhoto() async {
    final cubit  = ChatCubit.get(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _saving = true);
    await cubit.updateGroupPhoto(groupId: _group.id, imageFile: File(picked.path));
    _refreshGroup();
    setState(() => _saving = false);
  }

  // ── Add member ─────────────────────────────────────────────────────────────
  void _addMember() {
    final cubit = ChatCubit.get(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddMemberSheet(
        cubit:         cubit,
        existingUids:  _group.memberUids,
        onAdd: (uid) async {
          await cubit.addGroupMember(groupId: _group.id, newMemberUid: uid);
          _refreshGroup();
        },
      ),
    );
  }

  // ── Member options (admin only) ────────────────────────────────────────────
  void _memberOptions(String uid, String name) {
    final cubit = ChatCubit.get(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(14),
            child: Text(name, style: TextStyle(color: AppColors.of(context).text, fontSize: 15, fontWeight: FontWeight.w600))),
        if (uid != _group.adminUid)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_rounded, color: _kGold),
            title: Text(AppStrings.of(context).makeAdminLabel, style: TextStyle(color: AppColors.of(context).textSub)),
            onTap: () async {
              Navigator.pop(context);
              await cubit.makeGroupAdmin(groupId: _group.id, newAdminUid: uid);
              _refreshGroup();
            },
          ),
        ListTile(
          leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
          title: Text(AppStrings.of(context).removeFromGroupLabel, style: const TextStyle(color: Colors.redAccent)),
          onTap: () {
            Navigator.pop(context);
            _confirmRemove(uid, name);
          },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _confirmRemove(String uid, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text('${AppStrings.of(context).removeConfirmTitle} $name?', style: TextStyle(color: AppColors.of(context).text)),
        content: Text('$name ${AppStrings.of(context).removeFromGroupLabel.toLowerCase()}.', style: TextStyle(color: AppColors.of(context).textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ChatCubit.get(context).removeGroupMember(groupId: _group.id, memberUid: uid);
              _refreshGroup();
            },
            child: Text(AppStrings.of(context).removeFromGroup, style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Leave group ────────────────────────────────────────────────────────────
  void _leaveGroup() {
    final cubit   = ChatCubit.get(context);
    final isOnlyAdmin = _group.adminUid == cubit.currentUser?.uid &&
        _group.memberUids.where((u) => u == _group.adminUid).length == 1;

    if (isOnlyAdmin && _group.memberUids.length > 1) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.of(context).surface,
          title: Text(AppStrings.of(context).cannotLeaveTitle, style: TextStyle(color: AppColors.of(context).text)),
          content: Text(AppStrings.of(context).cannotLeaveBody,
              style: TextStyle(color: AppColors.of(context).textSub)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.of(context).ok, style: const TextStyle(color: _kGold))),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text('${AppStrings.of(context).leaveGroupConfirmTitle} ${_group.name}?', style: TextStyle(color: AppColors.of(context).text)),
        content: Text(AppStrings.of(context).leaveGroupConfirmBody,
            style: TextStyle(color: AppColors.of(context).textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await cubit.leaveGroup(_group.id);
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            child: Text(AppStrings.of(context).leaveGroup, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Delete group (admin) ───────────────────────────────────────────────────
  void _deleteGroup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).deleteGroupTitle, style: TextStyle(color: AppColors.of(context).text)),
        content: Text(AppStrings.of(context).cannotUndone,
            style: TextStyle(color: AppColors.of(context).textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ChatCubit.get(context).deleteGroup(_group.id);
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: Text(AppStrings.of(context).delete, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Admin-only messaging toggle ────────────────────────────────────────────
  Future<void> _toggleAdminOnly(bool value) async {
    await ChatCubit.get(context).setGroupOnlyAdmins(groupId: _group.id, onlyAdmins: value);
    _refreshGroup();
  }

  void _refreshGroup() {
    if (!mounted) return;
    final cubit = ChatCubit.get(context);
    final fresh = cubit.groups.firstWhere((g) => g.id == _group.id, orElse: () => _group);
    setState(() => _group = fresh);
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cubit  = ChatCubit.get(context);
    final myUid  = cubit.currentUser?.uid ?? '';

    return BlocListener<ChatCubit, ChatStates>(
      listener: (_, state) {
        if (state is ChatGroupUpdatedState || state is ChatGroupMemberAddedState ||
            state is ChatGroupMemberRemovedState) {
          _refreshGroup();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).bg,
        appBar: AppBar(
          backgroundColor: AppColors.of(context).surface,
          elevation: 0,
          title: Text(AppStrings.of(context).groupInfo, style: TextStyle(color: AppColors.of(context).text, fontSize: 16)),
          iconTheme: IconThemeData(color: AppColors.of(context).isDark ? Colors.white70 : const Color(0xFFe5c687)),
        ),
        body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: AppColors.of(context).surface,
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _kS2,
                  backgroundImage: _group.imageUrl != null
                      ? CachedNetworkImageProvider(_group.imageUrl!) : null,
                  child: _group.imageUrl == null
                      ? Icon(Icons.group, color: AppColors.of(context).textHint, size: 40) : null,
                ),
                if (_isAdmin && !_saving)
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(
                          color: _kGold, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 16),
                    ),
                  ),
                if (_saving)
                  const Positioned.fill(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
              ]),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _isAdmin ? _renameGroup : null,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_group.name,
                      style: TextStyle(color: AppColors.of(context).text, fontSize: 20, fontWeight: FontWeight.w700)),
                  if (_isAdmin) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, color: AppColors.of(context).textHint, size: 16),
                  ],
                ]),
              ),
              const SizedBox(height: 4),
              Text('${_group.memberUids.length} members',
                  style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13)),
              if (_group.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_group.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13)),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 8),

          // ── Admin-only send toggle ────────────────────────────────────────
          if (_isAdmin)
            Container(
              color: AppColors.of(context).surface,
              child: SwitchListTile(
                value: _group.onlyAdminsCanSend,
                activeColor: _kGold,
                onChanged: _toggleAdminOnly,
                secondary: Icon(Icons.lock_outline_rounded, color: AppColors.of(context).textSub),
                title: Text(AppStrings.of(context).onlyAdminsSend, style: TextStyle(color: AppColors.of(context).textSub)),
                subtitle: Text(AppStrings.of(context).membersCanRead,
                    style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12)),
              ),
            ),

          const SizedBox(height: 8),

          // ── Members section ────────────────────────────────────────────────
          Container(
            color: AppColors.of(context).surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Text(AppStrings.of(context).members, style: TextStyle(color: AppColors.of(context).textSub, fontSize: 12,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const Spacer(),
                  if (_isAdmin)
                    GestureDetector(
                      onTap: _addMember,
                      child: Row(children: [
                        const Icon(Icons.person_add_rounded, color: _kGold, size: 16),
                        const SizedBox(width: 4),
                        Text(AppStrings.of(context).add, style: const TextStyle(color: _kGold, fontSize: 13)),
                      ]),
                    ),
                ]),
              ),
              ..._group.memberUids.map((uid) {
                final user   = cubit.users.firstWhereOrNull((u) => u.uid == uid)
                    ?? cubit.livePresence[uid];
                final name   = user?.name ?? uid;
                final image  = user?.image;
                final isAdm  = uid == _group.adminUid;
                final isMe   = uid == myUid;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: _kS2,
                    backgroundImage: image?.isNotEmpty == true
                        ? CachedNetworkImageProvider(image!) : null,
                    child: image?.isEmpty != false
                        ? Icon(Icons.person, color: AppColors.of(context).textHint, size: 18) : null,
                  ),
                  title: Text(isMe ? 'You' : name,
                      style: TextStyle(color: AppColors.of(context).text, fontSize: 14)),
                  subtitle: isAdm
                      ? Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kGold.withValues(alpha: 0.4))),
                          child: Text(AppStrings.of(context).adminBadge,
                              style: const TextStyle(color: _kGold, fontSize: 11, fontWeight: FontWeight.w600)))
                      : null,
                  trailing: (_isAdmin && !isMe)
                      ? IconButton(
                          icon: Icon(Icons.more_vert, color: AppColors.of(context).textHint, size: 20),
                          onPressed: () => _memberOptions(uid, name),
                        )
                      : null,
                );
              }),
              const SizedBox(height: 8),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Leave / Delete ─────────────────────────────────────────────────
          Container(
            color: AppColors.of(context).surface,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                title: Text(AppStrings.of(context).leaveGroup, style: TextStyle(color: Colors.redAccent)),
                onTap: _leaveGroup,
              ),
              if (_isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: Text(AppStrings.of(context).deleteGroupTitle, style: const TextStyle(color: Colors.redAccent)),
                  onTap: _deleteGroup,
                ),
              const SizedBox(height: 4),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Helper to resolve user by uid ──────────────────────────────────────────────
extension _FirstWhere<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADD MEMBER SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _AddMemberSheet extends StatefulWidget {
  final ChatCubit    cubit;
  final List<String> existingUids;
  final Future<void> Function(String uid) onAdd;
  const _AddMemberSheet({required this.cubit, required this.existingUids, required this.onAdd});
  @override State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _ctrl = TextEditingController();

  List<_UserResult> get _candidates => widget.cubit.users
      .where((u) => !widget.existingUids.contains(u.uid) &&
          (u.name?.toLowerCase().contains(_ctrl.text.toLowerCase()) == true ||
           _ctrl.text.isEmpty))
      .map((u) => _UserResult(uid: u.uid!, name: u.name ?? '', image: u.image))
      .toList();

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7,
      builder: (_, sc) => Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: AppColors.of(context).text),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              hintStyle: TextStyle(color: AppColors.of(context).textHint),
              filled: true, fillColor: AppColors.of(context).elevated,
              prefixIcon: Icon(Icons.search, color: AppColors.of(context).textHint),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(child: ListView.builder(
          controller: sc,
          itemCount: _candidates.length,
          itemBuilder: (_, i) {
            final u = _candidates[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.of(context).elevated,
                backgroundImage: u.image?.isNotEmpty == true
                    ? CachedNetworkImageProvider(u.image!) : null,
                child: u.image?.isEmpty != false
                    ? Icon(Icons.person, color: AppColors.of(context).textHint) : null,
              ),
              title: Text(u.name, style: TextStyle(color: AppColors.of(context).text)),
              trailing: const Icon(Icons.add_rounded, color: _kGold),
              onTap: () async {
                Navigator.pop(context);
                await widget.onAdd(u.uid);
              },
            );
          },
        )),
      ]),
    );
  }
}

class _UserResult {
  final String  uid;
  final String  name;
  final String? image;
  _UserResult({required this.uid, required this.name, this.image});
}
