// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';

void main() {
  testWidgets('login lets a person choose the approved owner path', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthBloc(AuthRepository(ApiClient())),
          child: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Player Login'), findsOneWidget);
    await tester.tap(find.text('Turf owner'));
    await tester.pump();
    expect(find.text('Owner Login'), findsOneWidget);
  });
}
