// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realtime_chart_app/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  testWidgets('Dashboard renders correctly with mock data', (WidgetTester tester) async {
    // Mock the HTTP client
    final mockClient = MockClient((request) async {
      return http.Response(
        json.encode({
          'status': 'success',
          'data': [
            {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'temperature': 25.5,
              'humidity': 60.0,
            }
          ],
        }),
        200,
      );
    });

    // Inject mockClient into DashboardPage
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(httpClient: mockClient), 
      ),
    );

    // Initial render: if you don't have a CircularProgressIndicator, change the expectation:
    expect(find.text('Fetching data...'), findsOneWidget);

    // Wait for fetchSensorData to complete
    await tester.pumpAndSettle();

    // Verify title and cards are rendered
    expect(find.text('Sensor Dashboard'), findsOneWidget);
    expect(find.textContaining('Temperature'), findsOneWidget);
    expect(find.textContaining('Humidity'), findsOneWidget);
    expect(find.textContaining('Relay'), findsOneWidget);
  });
}
