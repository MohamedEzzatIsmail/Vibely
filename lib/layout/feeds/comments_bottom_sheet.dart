import '../../layout/cubit/post/post_cubit.dart';
import '../../models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import '../report/report_sheet.dart';

class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;

  const CommentsBottomSheet({super.key, required this.post});

  @override
  State<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState
    extends State<CommentsBottomSheet> {
  final TextEditingController _commentController =
  TextEditingController();

  final TextEditingController _replyController =
  TextEditingController();

  String? replyingToCommentId;
  Set<String> expandedComments = {};

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = PostsCubit.get(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF20262c),
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// DRAG HANDLE
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 10),

            /// COMMENTS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Posts')
                    .doc(widget.post.postId)
                    .collection('comments')
                    .orderBy('dateTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!.docs;

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment =
                      comments[index].data()
                      as Map<String, dynamic>;

                      final userId = cubit.currentUser?.uid;
                      final reaction =
                      comment['reactions']?[userId];

                      final isOwner =
                          userId == comment['userId'] ||
                              userId == widget.post.uid;

                      final isExpanded =
                      expandedComments.contains(
                          comment['commentId']);

                      return Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          /// COMMENT TILE
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  comment['userImage'] ?? ''),
                            ),
                            title: Text(
                              comment['userName'] ?? '',
                              style: TextStyle(
                                  color: AppColors.of(context).text,
                                  fontWeight:
                                  FontWeight.bold),
                            ),
                            subtitle: Text(
                              comment['text'] ?? '',
                              style: TextStyle(
                                  color: AppColors.of(context).textSub),
                            ),

                            /// DELETE (own comment or post owner moderating)
                            /// / REPORT (someone else's comment)
                            trailing: isOwner
                                ? IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                cubit.deleteComment(
                                  postId:
                                  widget.post.postId!,
                                  comment: comment,
                                );
                              },
                            )
                                : IconButton(
                              icon: const Icon(
                                Icons.flag_outlined,
                                color: Colors.orangeAccent,
                                size: 20,
                              ),
                              onPressed: () {
                                ReportSheet.show(context,
                                    targetUid: comment['userId'] ?? '',
                                    targetType: 'comment',
                                    postId: widget.post.postId);
                              },
                            ),
                          ),

                          /// REACTIONS + REPLY
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 16),
                            child: Row(
                              children: [
                                /// LIKE
                                GestureDetector(
                                  onTap: () {
                                    cubit.reactToComment(
                                      postId:
                                      widget.post.postId!,
                                      commentId: comment[
                                      'commentId'],
                                      isLike: true,
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        reaction == true
                                            ? Icons.favorite
                                            : Icons
                                            .favorite_border,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${comment['likes'] ?? 0}",
                                        style: TextStyle(
                                            color: AppColors.of(context).text),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                /// DISLIKE
                                GestureDetector(
                                  onTap: () {
                                    cubit.reactToComment(
                                      postId:
                                      widget.post.postId!,
                                      commentId: comment[
                                      'commentId'],
                                      isLike: false,
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        reaction == false
                                            ? Icons
                                            .heart_broken
                                            : Icons
                                            .heart_broken_outlined,
                                        color: AppColors.of(context).text,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${comment['dislikes'] ?? 0}",
                                        style: TextStyle(
                                            color: AppColors.of(context).text),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                /// REPLY BUTTON
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      replyingToCommentId =
                                      comment[
                                      'commentId'];
                                    });
                                  },
                                  child: Text(
                                    AppStrings.of(context).replyComment,
                                    style: const TextStyle(
                                        color: Colors.grey),
                                  ),
                                ),

                                const Spacer(),

                                /// SHOW REPLIES BUTTON
                                if ((comment[
                                'repliesCount'] ??
                                    0) >
                                    0)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (isExpanded) {
                                          expandedComments
                                              .remove(comment[
                                          'commentId']);
                                        } else {
                                          expandedComments
                                              .add(comment[
                                          'commentId']);
                                        }
                                      });
                                    },
                                    child: Text(
                                      isExpanded
                                          ? 'Hide replies'
                                          : "View replies (${comment['repliesCount']})",
                                      style:
                                      const TextStyle(
                                          color:
                                          Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          /// REPLY INPUT
                          if (replyingToCommentId ==
                              comment['commentId'])
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller:
                                      _replyController,
                                      style: TextStyle(
                                          color: AppColors.of(context).text),
                                      decoration:
                                      const InputDecoration(
                                        hintText:
                                        'Write a reply...',
                                        hintStyle:
                                        TextStyle(
                                            color: Colors
                                                .grey),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.send,
                                        color:
                                        Color(0xFFe5c687)),
                                    onPressed: () {
                                      final text =
                                      _replyController
                                          .text
                                          .trim();
                                      if (text.isEmpty)
                                        return;

                                      cubit.addReply(
                                        postId: widget
                                            .post.postId!,
                                        commentId: comment[
                                        'commentId'],
                                        text: text,
                                      );

                                      _replyController
                                          .clear();

                                      setState(() {
                                        replyingToCommentId =
                                        null;
                                      });
                                    },
                                  )
                                ],
                              ),
                            ),

                          /// REPLIES LIST
                          if (isExpanded)
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('Posts')
                                  .doc(widget.post.postId)
                                  .collection('comments')
                                  .doc(comment['commentId'])
                                  .collection('replies')
                                  .orderBy('dateTime')
                                  .snapshots(),
                              builder:
                                  (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox();

                                final replies =
                                    snapshot.data!.docs;

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  itemCount:
                                  replies.length,
                                  itemBuilder:
                                      (context, i) {
                                    final reply =
                                    replies[i].data()
                                    as Map<String,
                                        dynamic>;

                                    return Padding(
                                      padding:
                                      const EdgeInsets
                                          .only(
                                          left: 50),
                                      child: ListTile(
                                        leading:
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundImage:
                                          NetworkImage(
                                              reply[
                                              'userImage'] ??
                                                  ''),
                                        ),
                                        title: Text(
                                          reply[
                                          'userName'] ??
                                              '',
                                          style:
                                          TextStyle(
                                            color: AppColors.of(context).text,
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          reply['text'] ??
                                              '',
                                          style:
                                          const TextStyle(
                                            color: Colors
                                                .white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                          const Divider(color: Colors.grey),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            /// ADD COMMENT INPUT
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style:
                      TextStyle(color: AppColors.of(context).text),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle:
                        TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send,
                        color: Color(0xFFe5c687)),
                    onPressed: () {
                      final text =
                      _commentController.text.trim();
                      if (text.isEmpty) return;

                      cubit.addComment(
                        postId: widget.post.postId!,
                        commentText: text,
                      );

                      _commentController.clear();
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}