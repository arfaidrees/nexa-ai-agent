import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class DashboardService {
  DashboardService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<DashboardData> loadDashboard() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/dashboard/summary')).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw const ApiException('The dashboard could not be loaded.');
      final summary = jsonDecode(response.body) as Map<String, dynamic>;
      final leadsResponse = await _client.get(Uri.parse('$baseUrl/leads')).timeout(const Duration(seconds: 10));
      if (leadsResponse.statusCode != 200) throw const ApiException('Recent leads could not be loaded.');
      final leadsBody = jsonDecode(leadsResponse.body) as Map<String, dynamic>;
      return DashboardData.fromJson(summary, leadsBody);
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException('The dashboard is unreachable. Check that the backend is running.');
    }
  }

  void dispose() => _client.close();
}

class DashboardData {
  const DashboardData({required this.totalLeads, required this.newLeads, required this.contactedLeads, required this.totalProducts, required this.leads, required this.topProducts});

  factory DashboardData.fromJson(Map<String, dynamic> summary, Map<String, dynamic> leadsBody) => DashboardData(
    totalLeads: _integer(summary['total_leads']),
    newLeads: _integer(summary['new_leads']),
    contactedLeads: _integer(summary['contacted_leads']),
    totalProducts: _integer(summary['total_products']),
    leads: (leadsBody['leads'] is List ? leadsBody['leads'] as List : const []).whereType<Map<String, dynamic>>().map(AdminLead.fromJson).toList(),
    topProducts: (summary['top_interested_products'] is List ? summary['top_interested_products'] as List : const []).whereType<Map<String, dynamic>>().map(TopProduct.fromJson).toList(),
  );

  final int totalLeads;
  final int newLeads;
  final int contactedLeads;
  final int totalProducts;
  final List<AdminLead> leads;
  final List<TopProduct> topProducts;
}

class AdminLead {
  const AdminLead({required this.name, required this.email, required this.product, required this.budget, required this.status, required this.createdAt});

  factory AdminLead.fromJson(Map<String, dynamic> json) => AdminLead(
    name: json['name'] as String? ?? 'Unknown',
    email: json['email'] as String? ?? '',
    product: json['interested_product'] as String? ?? 'Unknown product',
    budget: (json['budget'] as num?)?.toInt(),
    status: json['status'] as String? ?? 'new',
    createdAt: json['created_at'] as String? ?? '',
  );

  final String name;
  final String email;
  final String product;
  final int? budget;
  final String status;
  final String createdAt;
}

class TopProduct {
  const TopProduct({required this.name, required this.leadCount});

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(name: json['name'] as String? ?? 'Unknown product', leadCount: _integer(json['lead_count']));

  final String name;
  final int leadCount;
}

int _integer(Object? value) => value is num ? value.toInt() : 0;
