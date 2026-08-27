import 'package:flutter/material.dart';

import 'dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.service});

  final DashboardService? service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardService _service;
  Future<DashboardData>? _dashboard;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DashboardService();
    _dashboard = _service.loadDashboard();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _load() {
    final request = _service.loadDashboard();
    setState(() => _dashboard = request);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DashboardError(onRetry: _load);
        }
        return _content(snapshot.data!);
      },
    );
  }

  Widget _content(DashboardData data) {
    return RefreshIndicator(
      onRefresh: () async {
        final request = _service.loadDashboard();
        setState(() => _dashboard = request);
        await request;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const Text('Business overview', style: TextStyle(color: Color(0xFF102A43), fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('A quick view of the interest Nexa is creating.', style: TextStyle(color: Color(0xFF52606D), fontSize: 15)),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 650 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: [
              _MetricCard(label: 'Total leads', value: data.totalLeads, icon: Icons.people_alt_outlined, color: const Color(0xFF0F766E)),
              _MetricCard(label: 'New leads', value: data.newLeads, icon: Icons.fiber_new_rounded, color: const Color(0xFFD97706)),
              _MetricCard(label: 'Contacted', value: data.contactedLeads, icon: Icons.mark_email_read_outlined, color: const Color(0xFF2563EB)),
              _MetricCard(label: 'Products', value: data.totalProducts, icon: Icons.devices_other_outlined, color: const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 30),
          _SectionTitle(title: 'Recent leads', count: data.leads.length),
          const SizedBox(height: 10),
          if (data.leads.isEmpty) const _EmptyState(text: 'No leads yet. They will appear here as customers chat with Nexa.')
          else ...data.leads.reversed.take(8).map((lead) => _LeadTile(lead: lead)),
          const SizedBox(height: 26),
          const _SectionTitle(title: 'Top interested products'),
          const SizedBox(height: 10),
          if (data.topProducts.isEmpty) const _EmptyState(text: 'Product interest will appear after the first lead is captured.')
          else ...data.topProducts.map((product) => _TopProductTile(product: product)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0C102A43), blurRadius: 10, offset: Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 22),
      Text('$value', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF102A43))),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF52606D))),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(color: Color(0xFF102A43), fontSize: 18, fontWeight: FontWeight.w800)),
    if (count != null) ...[
      const SizedBox(width: 8),
      Text('$count', style: const TextStyle(color: Color(0xFF7B8794), fontSize: 13)),
    ],
  ]);
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead});

  final AdminLead lead;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(backgroundColor: const Color(0xFFE4F6F1), foregroundColor: const Color(0xFF0F766E), child: Text(lead.name.isEmpty ? '?' : lead.name[0].toUpperCase())),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF102A43))),
        const SizedBox(height: 3),
        Text(lead.email, style: const TextStyle(color: Color(0xFF52606D), fontSize: 12)),
        const SizedBox(height: 7),
        Text(lead.product, style: const TextStyle(color: Color(0xFF243B53), fontSize: 13, fontWeight: FontWeight.w600)),
        if (lead.budget != null) Text('Budget: PKR ${_formatPrice(lead.budget!)}', style: const TextStyle(color: Color(0xFF7B8794), fontSize: 12)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFE4F6F1), borderRadius: BorderRadius.circular(20)), child: Text(lead.status, style: const TextStyle(color: Color(0xFF0F766E), fontSize: 11, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Text(_dateOnly(lead.createdAt), style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 11)),
      ]),
    ]),
  );
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      const Icon(Icons.trending_up_rounded, color: Color(0xFF0F766E)),
      const SizedBox(width: 12),
      Expanded(child: Text(product.name, style: const TextStyle(color: Color(0xFF243B53), fontWeight: FontWeight.w700))),
      Text('${product.leadCount} lead${product.leadCount == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF0F766E), fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFEFF3F1), borderRadius: BorderRadius.circular(15)), child: Text(text, style: const TextStyle(color: Color(0xFF52606D), fontSize: 13)));
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318), size: 42),
    const SizedBox(height: 12),
    const Text('Dashboard unavailable', style: TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w800, fontSize: 18)),
    const SizedBox(height: 6),
    const Text('Check that FastAPI is running, then try again.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF52606D))),
    const SizedBox(height: 14),
    FilledButton(onPressed: onRetry, child: const Text('Retry')),
  ])));
}

String _formatPrice(int price) => price.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (match) => ',');

String _dateOnly(String value) => value.length >= 10 ? value.substring(0, 10) : value;
