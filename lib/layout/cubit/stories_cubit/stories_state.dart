abstract class StoriesState {}

class StoriesInitial  extends StoriesState {}

class StoriesLoading  extends StoriesState {}

class StoriesLoaded   extends StoriesState {}

class StoryUploading  extends StoriesState {}

class StoryUploaded   extends StoriesState {}

class StoriesError    extends StoriesState {
  final String msg; StoriesError(this.msg);
}
