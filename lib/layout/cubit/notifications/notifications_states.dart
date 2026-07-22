abstract class NotificationsState {}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsUpdated extends NotificationsState {}

class NotificationsError extends NotificationsState {
  final String message;
  NotificationsError(this.message);
}