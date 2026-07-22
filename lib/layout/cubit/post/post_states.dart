// lib/layout/cubit/post/post_states.dart

abstract class PostsStates {}

class PostsInitialState extends PostsStates {}

class PostsLoadingState extends PostsStates {}

class PostsLoadingMoreState extends PostsStates {}

class PostsSuccessState extends PostsStates {}

class PostsErrorState extends PostsStates {
  final String error;
  PostsErrorState(this.error);
}

class PostCreatingState extends PostsStates {}

class PostCreatedState extends PostsStates {}

class PostImagesPickedState extends PostsStates {}

class PostDeletedState extends PostsStates {}

class PostErrorState extends PostsStates {
  final String error;
  PostErrorState(this.error);
}

class PostReactionUpdatedState extends PostsStates {
  final String postId;
  PostReactionUpdatedState({required this.postId});
}

class CommentAddedState extends PostsStates {
  final String postId;
  CommentAddedState({required this.postId});
}

class CommentDeletedState extends PostsStates {
  final String postId;
  CommentDeletedState({required this.postId});
}

class CommentReactionUpdatedState extends PostsStates {}

class PostEditedState extends PostsStates {}

class PostRateLimitedState extends PostsStates {
  final Duration remaining;
  PostRateLimitedState(this.remaining);
}

class PostImagesPickedSuccessState extends PostsStates {}

class PostImagesPickedErrorState extends PostsStates {
  final String error;
  PostImagesPickedErrorState(this.error);
}
