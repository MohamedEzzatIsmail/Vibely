class MainStates {}

class MainInitStates extends MainStates {}

class MainGetUserDataLoadingStates extends MainStates {}

class MainGetUserDataSuccessStates extends MainStates {}

class MainGetUserDataErrorStates extends MainStates {
  final String error;
  MainGetUserDataErrorStates(this.error);
}

class ChangingBottomNavStates extends MainStates {}

class UpdateProfileLoadingState extends MainStates {}

class UpdateProfileSuccessState extends MainStates {}

class UpdateProfileErrorState extends MainStates {
  final String error;
  UpdateProfileErrorState(this.error);
}

class UpdateProfileImagePickedState extends MainStates {}

class ProfileImagePickedSuccessState extends MainStates {}

class ProfileImagePickedErrorState extends MainStates {}

class UpdateCoverImagePickedState extends MainStates {}

class CoverImagePickedSuccessState extends MainStates {}

class CoverImagePickedErrorState extends MainStates {}

class CreatePostLoadingState extends MainStates {}

class CreatePostSuccessState extends MainStates {}

class CreatePostErrorState extends MainStates {
  final String error;
  CreatePostErrorState(this.error);
}

class PostImagePickedSuccessState extends MainStates {}

class GetPostsLoadingState extends MainStates {}

class GetPostsSuccessState extends MainStates {}

class UpdatePostReactionState extends MainStates {}

class MainGetPostsSuccessState extends MainStates {}

class UpdatePostReactionSuccessState extends MainStates {}

class UpdatePostReactionErrorState extends MainStates {
  final String error;
  UpdatePostReactionErrorState(this.error);
}

class DeleteAccountLoadingState extends MainStates {}

class DeleteAccountSuccessState extends MainStates {}

class DeleteAccountErrorState extends MainStates {
  final String error;
  DeleteAccountErrorState(this.error);
}

