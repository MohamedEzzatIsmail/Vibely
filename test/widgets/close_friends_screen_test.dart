// test/widgets/close_friends_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vibely/layout/close_friends/close_friends_screen.dart';
import 'package:vibely/layout/cubit/cubit.dart';
import 'package:vibely/layout/cubit/states.dart';
import 'package:vibely/models/user_model.dart';
import 'package:vibely/share/style/theme.dart';

// ── Correct mock pattern: MockBloc, not MockCubit ────────────────────────────
class MockMainCubit extends MockBloc<MainStates, MainStates>
    implements MainCubit {}

UserModel _fakeUser({List<String> followers = const [], List<String> following = const []}) =>
    UserModel(
      uid: 'me', name: 'Alice', email: 'alice@test.com',
      image: '', phone: '', bio: '', cover: '',
    ).copyWith(followersUids: followers, followingUids: following, closeFriendsUids: []);

Widget _wrap(Widget child, MockMainCubit cubit) => MaterialApp(
  theme: darkTheme,
  home: BlocProvider<MainCubit>.value(value: cubit, child: child),
);

void main() {
  late MockMainCubit cubit;

  setUp(() {
    cubit = MockMainCubit();
    when(() => cubit.model).thenReturn(_fakeUser());
    whenListen(cubit, Stream<MainStates>.fromIterable([MainGetUserDataSuccessStates()]),
        initialState: MainGetUserDataSuccessStates());
  });

  tearDown(() => cubit.close());

  testWidgets('shows Close Friends title in AppBar', (tester) async {
    await tester.pumpWidget(_wrap(const CloseFriendsScreen(), cubit));
    await tester.pump();
    expect(find.text('Close Friends'), findsOneWidget);
  });

  testWidgets('shows info banner about stories visibility', (tester) async {
    await tester.pumpWidget(_wrap(const CloseFriendsScreen(), cubit));
    await tester.pump();
    expect(find.textContaining('Stories posted to Close Friends'), findsOneWidget);
  });

  testWidgets('shows search TextField', (tester) async {
    await tester.pumpWidget(_wrap(const CloseFriendsScreen(), cubit));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows empty state when no followers or following', (tester) async {
    await tester.pumpWidget(_wrap(const CloseFriendsScreen(), cubit));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining('No followers'), findsOneWidget);
  });
}
