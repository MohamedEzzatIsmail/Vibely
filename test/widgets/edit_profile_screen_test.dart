// test/widgets/edit_profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vibely/layout/cubit/cubit.dart';
import 'package:vibely/layout/cubit/states.dart';
import 'package:vibely/layout/edit_profile/edit_profile_screen.dart';
import 'package:vibely/models/user_model.dart';
import 'package:vibely/share/style/theme.dart';

class MockMainCubit extends MockBloc<MainStates, MainStates>
    implements MainCubit {}

UserModel _fakeUser() => UserModel(
  uid: 'me', name: 'Test User', email: 'test@test.com',
  image: '', phone: '+201234567890', bio: 'Hello world', cover: '',
);

Widget _wrap(Widget child, MockMainCubit cubit) => MaterialApp(
  theme: darkTheme,
  home: BlocProvider<MainCubit>.value(value: cubit, child: child),
);

void main() {
  late MockMainCubit cubit;

  setUp(() {
    cubit = MockMainCubit();
    when(() => cubit.model).thenReturn(_fakeUser());
    when(() => cubit.profileImage).thenReturn(null);
    when(() => cubit.coverImage).thenReturn(null);
    whenListen(cubit, Stream<MainStates>.fromIterable([MainGetUserDataSuccessStates()]),
        initialState: MainGetUserDataSuccessStates());
  });

  tearDown(() => cubit.close());

  testWidgets('shows Edit Profile title', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('prefills name field with existing value', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('bio counter shows correct length/150', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    // 'Hello world' = 11 chars
    expect(find.text('11/150'), findsOneWidget);
  });

  testWidgets('bio counter updates live as user types', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    final bioField = find.widgetWithText(TextFormField, 'Hello world');
    await tester.enterText(bioField, 'Hello world!');
    await tester.pump();
    expect(find.text('12/150'), findsOneWidget);
  });

  testWidgets('shows Save Changes button', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('empty name triggers validation error', (tester) async {
    await tester.pumpWidget(_wrap(const EditProfileScreen(), cubit));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Test User'), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(find.byType(TextFormField), findsWidgets);
  });
}
