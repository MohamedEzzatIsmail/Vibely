// test/widgets/blocked_users_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vibely/layout/blocked_users/blocked_users_screen.dart';
import 'package:vibely/layout/cubit/cubit.dart';
import 'package:vibely/layout/cubit/states.dart';
import 'package:vibely/models/user_model.dart';
import 'package:vibely/share/style/theme.dart';

class MockMainCubit extends MockBloc<MainStates, MainStates>
    implements MainCubit {}

Widget _wrap(Widget child, MockMainCubit cubit) => MaterialApp(
  theme: darkTheme,
  home: BlocProvider<MainCubit>.value(value: cubit, child: child),
);

void main() {
  late MockMainCubit cubit;

  setUp(() {
    cubit = MockMainCubit();
    when(() => cubit.model).thenReturn(
      UserModel(uid: 'me', name: 'Me', email: 'me@test.com',
          image: '', phone: '', bio: '', cover: '')
          .copyWith(blockedUids: []),
    );
    whenListen(cubit, Stream<MainStates>.fromIterable([MainGetUserDataSuccessStates()]),
        initialState: MainGetUserDataSuccessStates());
  });

  tearDown(() => cubit.close());

  testWidgets('shows Blocked Accounts title', (tester) async {
    await tester.pumpWidget(_wrap(const BlockedUsersScreen(), cubit));
    await tester.pump();
    expect(find.text('Blocked Accounts'), findsOneWidget);
  });

  testWidgets('shows empty state when no blocked users', (tester) async {
    await tester.pumpWidget(_wrap(const BlockedUsersScreen(), cubit));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('No blocked accounts'), findsOneWidget);
  });

  testWidgets('shows correct empty state description', (tester) async {
    await tester.pumpWidget(_wrap(const BlockedUsersScreen(), cubit));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining("won't be able to find"), findsOneWidget);
  });
}
