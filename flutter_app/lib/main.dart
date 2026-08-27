import 'package:flutter/material.dart';

import 'api_service.dart';
import 'dashboard_screen.dart';

void main() => runApp(const NexaApp());

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102A43);
    const teal = Color(0xFF0F766E);
    return MaterialApp(
      title: 'Nexa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: const Color(0xFFF6F4EF),
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide.none),
        ),
      ),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  final _chatPage = const ChatScreen();
  Widget? _adminPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _chatPage,
          _adminPage ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            _adminPage ??= const _AdminPage();
          }
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Admin'),
        ],
      ),
    );
  }
}

class _AdminPage extends StatelessWidget {
  const _AdminPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Nexa Admin', style: TextStyle(fontWeight: FontWeight.w800))),
    body: const DashboardScreen(),
  );
}

class ChatMessage {
  const ChatMessage({required this.text, required this.isUser, this.type = 'text', this.data});

  final String text;
  final bool isUser;
  final String type;
  final Map<String, dynamic>? data;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const suggestions = <String>[
    'Phone under 80k',
    'Best laptop for university',
    'Headphones with noise cancellation',
    'Compare two products',
  ];

  late final ApiService _api;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  String? _sessionId;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? ApiService();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    if (widget.apiService == null) _api.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedMessage]) async {
    final message = (suggestedMessage ?? _inputController.text).trim();
    if (message.isEmpty || _isLoading) return;
    _inputController.clear();
    setState(() {
      _error = null;
      _isLoading = true;
      _messages.add(ChatMessage(text: message, isUser: true));
    });
    _scrollToBottom();

    try {
      final result = await _api.sendMessage(message: message, sessionId: _sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = result.sessionId;
        _messages.add(ChatMessage(text: result.reply, isUser: false, type: result.type, data: result.data));
        _isLoading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFF61D6C1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF102A43), size: 21),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nexa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text('Your shopping sidekick', style: TextStyle(fontSize: 11, color: Color(0xFFB8D8D3))),
          ]),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.circle, color: Color(0xFF61D6C1), size: 8),
                SizedBox(width: 6),
                Text('Online', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty ? _welcome() : _conversation()),
        if (_error != null) _errorBanner(),
        _composer(),
      ]),
    );
  }

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE4F6F1), Color(0xFFFFF1DF)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.wb_sunny_outlined, color: Color(0xFF0F766E), size: 28),
                SizedBox(width: 14),
                Expanded(child: Text('Thoughtful recommendations,\nwithout the guesswork.', style: TextStyle(color: Color(0xFF102A43), fontSize: 17, fontWeight: FontWeight.w700, height: 1.25))),
              ]),
            ),
            const SizedBox(height: 38),
            const Text('Hi, I\'m Nexa.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF102A43))),
            const SizedBox(height: 12),
            const Text('Tell me what you\'re looking for and I\'ll help you find the best option.', style: TextStyle(fontSize: 17, height: 1.45, color: Color(0xFF52606D))),
            const SizedBox(height: 30),
            const Text('TRY ASKING', style: TextStyle(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: suggestions.map((suggestion) => ActionChip(
                label: Text(suggestion),
                onPressed: () => _send(suggestion),
                labelStyle: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD8E4E0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              )).toList(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _conversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) => index == _messages.length
          ? const _TypingIndicator()
          : _MessageBubble(message: _messages[index], onPrompt: _send),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFFFE8E4), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFB42318), size: 18),
        const SizedBox(width: 9),
        Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF8A1C13), fontSize: 13))),
        IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close, size: 18)),
      ]),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Ask Nexa anything about your next device...'),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _isLoading ? null : _send,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 54,
                height: 54,
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(17), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onPrompt});

  final ChatMessage message;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    if (!message.isUser && message.type == 'product_results') {
      return _StructuredResults(message: message, onPrompt: onPrompt);
    }
    if (!message.isUser && message.type == 'product_comparison') {
      return _Comparison(message: message);
    }
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF102A43) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0C102A43), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Text(message.text, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF243B53), height: 1.45, fontSize: 15)),
      ),
    );
  }
}

class _StructuredResults extends StatelessWidget {
  const _StructuredResults({required this.message, required this.onPrompt});

  final ChatMessage message;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final rawProducts = message.data?['products'];
    final products = rawProducts is List
        ? rawProducts.whereType<Map<String, dynamic>>().map(ProductSummary.fromJson).toList()
        : <ProductSummary>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (message.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(message.text, style: const TextStyle(color: Color(0xFF243B53), height: 1.45, fontSize: 15))),
      ...products.map((product) => _ProductCard(product: product, onPrompt: onPrompt)),
    ]);
  }
}

class ProductSummary {
  const ProductSummary({required this.id, required this.name, required this.brand, required this.category, required this.price, required this.rating, required this.stock, required this.attributes});

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Product',
    brand: json['brand'] as String? ?? '',
    category: json['category'] as String? ?? '',
    price: (json['price'] as num?)?.toInt() ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    attributes: json['attributes'] is Map<String, dynamic> ? json['attributes'] as Map<String, dynamic> : {},
  );

  final String id;
  final String name;
  final String brand;
  final String category;
  final int price;
  final double rating;
  final int stock;
  final Map<String, dynamic> attributes;
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onPrompt});

  final ProductSummary product;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final specs = product.attributes.entries.take(3).map((entry) => '${_label(entry.key)}: ${entry.value}').join('  ·  ');
    return Container(
      width: 680,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0C102A43), blurRadius: 10, offset: Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF102A43), fontSize: 17))),
          Text('PKR ${_formatPrice(product.price)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E), fontSize: 15)),
        ]),
        const SizedBox(height: 5),
        Text('${product.brand}  ·  ${product.category}', style: const TextStyle(color: Color(0xFF7B8794), fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 4),
          Text(product.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 14),
          Icon(Icons.inventory_2_outlined, color: product.stock > 0 ? const Color(0xFF0F766E) : const Color(0xFFB42318), size: 17),
          const SizedBox(width: 4),
          Text(product.stock > 0 ? '${product.stock} in stock' : 'Out of stock', style: TextStyle(color: product.stock > 0 ? const Color(0xFF0F766E) : const Color(0xFFB42318), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(specs, style: const TextStyle(color: Color(0xFF52606D), fontSize: 12, height: 1.4)),
        ],
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => onPrompt('Tell me more about ${product.name}'), icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('Details'))),
      ]),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final rawProducts = message.data?['products'];
    final products = rawProducts is List
        ? rawProducts.whereType<Map<String, dynamic>>().map(ProductSummary.fromJson).toList()
        : <ProductSummary>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (message.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(message.text, style: const TextStyle(color: Color(0xFF243B53), height: 1.45, fontSize: 15))),
      Container(
        width: 680,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0C102A43), blurRadius: 10, offset: Offset(0, 3))]),
        child: Column(children: [
          for (var index = 0; index < products.length; index++) ...[
            if (index > 0) const Divider(height: 22),
            _ComparisonRow(product: products[index]),
          ],
        ]),
      ),
    ]);
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.product});

  final ProductSummary product;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF102A43))),
      const SizedBox(height: 5),
      Text('PKR ${_formatPrice(product.price)}  ·  ${product.rating.toStringAsFixed(1)} ★', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 5),
      Text(product.attributes.entries.take(3).map((entry) => '${_label(entry.key)}: ${entry.value}').join('  ·  '), style: const TextStyle(color: Color(0xFF52606D), fontSize: 12)),
    ])),
    Text(product.stock > 0 ? 'In stock' : 'Out of stock', style: TextStyle(color: product.stock > 0 ? const Color(0xFF0F766E) : const Color(0xFFB42318), fontSize: 11, fontWeight: FontWeight.w700)),
  ]);
}

String _formatPrice(int price) => price.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (match) => ',');

String _label(String value) => value.replaceAll('_', ' ');

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: const Text('Nexa is thinking  ·  ·  ·', style: TextStyle(color: Color(0xFF52606D), fontSize: 13)),
      ),
    );
  }
}
