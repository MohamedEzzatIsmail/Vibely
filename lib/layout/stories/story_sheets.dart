part of 'story_viewer.dart';

class _StoryCommentsSheet extends StatefulWidget {
  final StoryModel story;
  final StoriesCubit cubit;
  final TextEditingController commentCtrl;
  const _StoryCommentsSheet(
      {required this.story, required this.cubit, required this.commentCtrl});
  @override
  State<_StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<_StoryCommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await widget.cubit.loadStoryComments(widget.story.storyId);
    if (mounted) setState(() { _comments = list; _loading = false; });
  }

  Future<void> _post() async {
    final text = widget.commentCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    await widget.cubit.addStoryComment(widget.story.storyId, text);
    widget.commentCtrl.clear();
    await _load();
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        Text(AppStrings.of(context).commentsLabel,
            style: TextStyle(
                color: AppColors.of(context).text,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: Color(0xFFe5c687), strokeWidth: 2))
        else if (_comments.isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child:
                  Text(AppStrings.of(context).beFirstToComment, style: const TextStyle(color: Colors.grey)))
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.38),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _comments.length,
              itemBuilder: (_, i) {
                final c = _comments[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF21262d),
                    backgroundImage: (c['image'] ?? '').isNotEmpty
                        ? NetworkImage(c['image'])
                        : null,
                    child: (c['image'] ?? '').isEmpty
                        ? Text(
                            ((c['name'] ?? '?') as String).isNotEmpty
                                ? (c['name'] as String)[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: AppColors.of(context).text,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(c['name'] ?? '',
                      style: TextStyle(
                          color: AppColors.of(context).text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(c['text'] ?? '',
                      style: TextStyle(
                          color: AppColors.of(context).textSub, fontSize: 13)),
                );
              },
            ),
          ),
        const Divider(color: Colors.white10, height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: widget.commentCtrl,
                style: TextStyle(color: AppColors.of(context).text),
                onSubmitted: (_) => _post(),
                decoration: InputDecoration(
                  hintText: 'Write a comment…',
                  hintStyle:
                      TextStyle(color: AppColors.of(context).textSub, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _posting
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        color: Color(0xFFe5c687), strokeWidth: 2))
                : GestureDetector(
                    onTap: _post,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: Color(0xFFe5c687), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.black, size: 18),
                    ),
                  ),
          ]),
        ),
      ]),
    );
  }
}

// ── Viewers sheet ─────────────────────────────────────────────────────────────
class _ViewersSheet extends StatefulWidget {
  final List<String> seenByUids;
  const _ViewersSheet({required this.seenByUids});
  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.seenByUids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final results = <UserModel>[];
    for (var i = 0; i < widget.seenByUids.length; i += 30) {
      final chunk = widget.seenByUids
          .sublist(i, (i + 30).clamp(0, widget.seenByUids.length));
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => UserModel.fromJson(d.data())));
    }
    if (mounted) setState(() { _users = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      Text(
          '${widget.seenByUids.length} Viewer${widget.seenByUids.length == 1 ? '' : 's'}',
          style: TextStyle(
              color: AppColors.of(context).text,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Divider(color: Colors.white10, height: 1),
      if (_loading)
        const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(
                color: Color(0xFFe5c687), strokeWidth: 2))
      else if (_users.isEmpty)
        Padding(
            padding: const EdgeInsets.all(24),
            child:
                Text(AppStrings.of(context).noViewersYet, style: const TextStyle(color: Colors.grey)))
      else
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _users.length,
            itemBuilder: (_, i) {
              final u = _users[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF21262d),
                  backgroundImage: (u.image ?? '').isNotEmpty
                      ? NetworkImage(u.image!)
                      : null,
                  child: (u.image ?? '').isEmpty
                      ? Text((u.name ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                              color: AppColors.of(context).text,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(u.name ?? '',
                    style: TextStyle(
                        color: AppColors.of(context).text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              );
            },
          ),
        ),
      const SizedBox(height: 16),
    ]);
  }
}
