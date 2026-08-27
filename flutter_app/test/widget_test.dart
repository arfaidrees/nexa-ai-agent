import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:nexa_customer_app/main.dart';
import 'package:nexa_customer_app/api_service.dart';
import 'package:nexa_customer_app/dashboard_screen.dart';
import 'package:nexa_customer_app/dashboard_service.dart';

class _StructuredResponseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({
      'session_id': 'test-session',
      'reply': 'I found one good option.',
      'type': 'product_results',
      'data': {
        'products': [
          {
            'id': 'phone-001',
            'name': 'Nexa Photon X1',
            'brand': 'Nexa',
            'category': 'phone',
            'price': 69999,
            'rating': 4.6,
            'stock': 12,
            'attributes': {'camera': '50MP'},
          },
        ],
      },
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _DashboardResponseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request.url.path.endsWith('/summary')
        ? {
            'total_leads': 3,
            'new_leads': 2,
            'contacted_leads': 1,
            'total_products': 36,
            'top_interested_products': [
              {'name': 'Nexa Photon X1', 'lead_count': 2},
            ],
          }
        : {
            'count': 1,
            'leads': [
              {
                'name': 'Arfa',
                'email': 'arfa@example.com',
                'interested_product': 'phone-001',
                'budget': 80000,
                'status': 'new',
                'created_at': '2026-08-26T10:00:00+00:00',
              },
            ],
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  testWidgets('shows the Nexa welcome experience', (tester) async {
    await tester.pumpWidget(const NexaApp());

    expect(find.text('Hi, I\'m Nexa.'), findsOneWidget);
    expect(find.text('Phone under 80k'), findsOneWidget);
    expect(find.text('Best laptop for university'), findsOneWidget);
    expect(find.text('Ask Nexa anything about your next device...'), findsOneWidget);
  });

  testWidgets('renders structured product results', (tester) async {
    final api = ApiService(baseUrl: 'http://test', client: _StructuredResponseClient());
    await tester.pumpWidget(MaterialApp(home: ChatScreen(apiService: api)));
    await tester.tap(find.text('Phone under 80k'));
    await tester.pumpAndSettle();

    expect(find.text('Nexa Photon X1'), findsOneWidget);
    expect(find.text('PKR 69,999'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('renders the admin dashboard summary and leads', (tester) async {
    final service = DashboardService(baseUrl: 'http://test', client: _DashboardResponseClient());
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Business overview'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Arfa'), findsOneWidget);
    expect(find.text('Nexa Photon X1'), findsOneWidget);
  });
}
