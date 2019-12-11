// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_chat_app/login.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
library appengine.api.errors;

import 'dart:io';

class AppEngineError implements Exception {
  final String message;

  const AppEngineError(this.message);

  @override
  String toString() => 'AppEngineException: $message';
}

class NetworkError extends AppEngineError implements IOException {
  NetworkError(String message) : super(message);

  @override
  String toString() => 'NetworkError: $message';
}

class ProtocolError extends AppEngineError implements IOException {
  static const ProtocolError INVALID_RESPONSE =
      ProtocolError('Invalid response');

  const ProtocolError(String message) : super(message);

  @override
  String toString() => 'ProtocolError: $message';
}

class ServiceError extends AppEngineError {
  final String serviceName;

  ServiceError(String message, {this.serviceName = 'ServiceError'})
      : super(message);

  @override
  String toString() => '$serviceName: $message';
}

class ApplicationError extends AppEngineError {
  ApplicationError(String message) : super(message);

  @override
  String toString() => 'ApplicationError: $message';
}
