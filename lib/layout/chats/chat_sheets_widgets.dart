part of 'chats_screen.dart';

class _NewChatSheet extends StatefulWidget {
  final ChatCubit cubit;
  const _NewChatSheet({required this.cubit});
  @override State<_NewChatSheet> createState() => _NewChatSheetState();
}
class _NewChatSheetState extends State<_NewChatSheet> {
  final _ctrl = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  /// Fetches the user list once when the sheet opens; [_search] then
  /// filters this same in-memory list on every keystroke rather than
  /// re-querying Firestore per character typed.
  Future<void> _loadAllUsers() async {
    final snap =
        await FirebaseFirestore.instance.collection('Users').limit(200).get();
    final myUid = widget.cubit.currentUser?.uid;
    if (!mounted) return;
    setState(() {
      _allUsers = snap.docs
          .map((d) => UserModel.fromJson(d.data()))
          .where((u) => u.uid != myUid)
          .toList();
      _loading = false;
    });
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = _allUsers
          .where((u) => (u.name ?? '').toLowerCase().contains(query))
          .toList();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.85,
      builder: (_, sc) => Column(children: [
        Container(margin: const EdgeInsets.only(top: 8, bottom: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(controller: _ctrl, autofocus: true, style: TextStyle(color: AppColors.of(context).text),
                onChanged: _search,
                decoration: InputDecoration(hintText: 'Search by name…', hintStyle: TextStyle(color: AppColors.of(context).textHint),
                    filled: true, fillColor: AppColors.of(context).elevated,
                    prefixIcon: Icon(Icons.search, color: AppColors.of(context).textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12)))),
        const SizedBox(height: 8),
        if (_loading) const Padding(padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
        Expanded(child: ListView.builder(controller: sc, itemCount: _results.length,
            itemBuilder: (_, i) {
              final u = _results[i];
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.white12,
                    backgroundImage: u.image?.isNotEmpty == true ? CachedNetworkImageProvider(u.image!) : null,
                    child: u.image?.isEmpty != false ? Icon(Icons.person, color: AppColors.of(context).textHint) : null),
                title: Text(u.name ?? '', style: TextStyle(color: AppColors.of(context).text)),
                onTap: () async {
                  Navigator.pop(context);
                  await widget.cubit.ensureChat(u.uid!);
                  if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: u)));
                },
              );
            })),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CREATE GROUP SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _CreateGroupSheet extends StatefulWidget {
  final ChatCubit cubit;
  const _CreateGroupSheet({required this.cubit});
  @override State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}
class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;
  @override void dispose() { _nameCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final users = widget.cubit.users;
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.85,
      builder: (_, sc) => Column(children: [
        Container(margin: const EdgeInsets.only(top: 8, bottom: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(controller: _nameCtrl, style: TextStyle(color: AppColors.of(context).text),
                decoration: InputDecoration(hintText: 'Group name…', hintStyle: TextStyle(color: AppColors.of(context).textHint),
                    filled: true, fillColor: AppColors.of(context).elevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)))),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(alignment: Alignment.centerLeft,
                child: Text(AppStrings.of(context).selectMembers, style: TextStyle(color: AppColors.of(context).textSub, fontSize: 12)))),
        Expanded(child: ListView.builder(controller: sc, itemCount: users.length,
            itemBuilder: (_, i) {
              final u   = users[i]; final sel = _selected.contains(u.uid);
              return CheckboxListTile(value: sel, activeColor: kGold,
                  onChanged: (_) => setState(() { if (sel) _selected.remove(u.uid); else _selected.add(u.uid!); }),
                  secondary: CircleAvatar(backgroundColor: Colors.white12,
                      backgroundImage: u.image?.isNotEmpty == true ? CachedNetworkImageProvider(u.image!) : null),
                  title: Text(u.name ?? '', style: TextStyle(color: AppColors.of(context).text)));
            })),
        Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _creating || _selected.isEmpty ? null : () async {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() => _creating = true);
                      await widget.cubit.createGroup(name: name, memberUids: _selected.toList());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: _creating
                        ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2))
                        : Text(AppStrings.of(context).createGroup, style: TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    );
  }
}

// ── Empty state widget ─────────────────────────────────────────────────────────
class _EmptyChatsWidget extends StatelessWidget {
  const _EmptyChatsWidget();
  @override Widget build(BuildContext context) => Center(
    child: Column(children: [
      const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white12, size: 64),
      const SizedBox(height: 16),
      Text(AppStrings.of(context).noConversationsYet, style: TextStyle(color: AppColors.of(context).textHint, fontSize: 15)),
      const SizedBox(height: 6),
      Text(AppStrings.of(context).tapToStartChatting, style: const TextStyle(color: Colors.white24, fontSize: 13)),
    ]),
  );
}

// ── Skeleton tile ──────────────────────────────────────────────────────────────
class _ChatTileSkeleton extends StatelessWidget {
  const _ChatTileSkeleton();
  @override Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    leading: CircleAvatar(radius: 24, backgroundColor: AppColors.of(context).elevated),
    title: Container(height: 13, width: 120, decoration: BoxDecoration(color: AppColors.of(context).elevated, borderRadius: BorderRadius.circular(6))),
    subtitle: Container(margin: EdgeInsets.only(top: 6), height: 11, width: 180, decoration: BoxDecoration(color: AppColors.of(context).surface, borderRadius: BorderRadius.circular(6))),
    trailing: Container(height: 10, width: 32, decoration: BoxDecoration(color: AppColors.of(context).elevated, borderRadius: BorderRadius.circular(5))),
  );
}
