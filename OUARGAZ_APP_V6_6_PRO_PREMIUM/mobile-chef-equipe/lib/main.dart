import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.init();
  runApp(const OuargazApp());
}

// ─── CONSTANTS ────────────────────────────────────────────────────────────────
const kPrimary = Color(0xFFDA1A1A);
const kSuccess = Color(0xFF00D97E);
const kWarning = Color(0xFFFF6B00);
const kInfo = Color(0xFF00A8E8);
const k12kg = Color(0xFF0066CC);
const k6kg = Color(0xFF00A854);
const k3kg = Color(0xFFFF8C00);
const kBg = Color(0xFF0A0E1A);
const kCard = Color(0xFF111827);
const kBorder = Color(0xFF1E293B);
const kMuted = Color(0xFF64748B);

// ─── THEME CONTROLLER ─────────────────────────────────────────────────────────
class ThemeController {
  static final ValueNotifier<bool> isDark = ValueNotifier(true);
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool('isDark') ?? true;
  }
  
  static void toggle() {
    isDark.value = !isDark.value;
    _save();
  }
  
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark.value);
  }
}

// ─── APP ──────────────────────────────────────────────────────────────────────
class OuargazApp extends StatelessWidget {
  const OuargazApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDark,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'OUARGAZ Chef Équipe',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(isDark),
          home: const AuthWrapper(),
        );
      },
    );
  }

  ThemeData _buildTheme(bool isDark) {
    if (isDark) {
      return ThemeData(
        colorScheme: const ColorScheme.dark(primary: kPrimary, surface: kBg),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kCard,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        cardTheme: CardTheme(
          color: kCard,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E2A3A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        useMaterial3: true,
      );
    } else {
      return ThemeData(
        colorScheme: const ColorScheme.light(primary: kPrimary),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFAFAFA)),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        useMaterial3: true,
      );
    }
  }
}

// ─── API SERVICE ─────────────────────────────────────────────────────────────
class ApiService {
  static String baseUrl = '';
  static String? _cookie;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('base_url') ?? '';
    _cookie = prefs.getString('session_cookie');
  }

  static Future<void> saveConfig(String url, String username, String password, String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
    await prefs.setString('session_username', username);
    await prefs.setString('session_password', password);
    await prefs.setString('session_cookie', cookie);
    baseUrl = url;
    _cookie = cookie;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cookie != null) 'Cookie': _cookie!,
  };

  static Future<Map<String, dynamic>?> login(String url, String username, String password) async {
    try {
      final resp = await http.post(
        Uri.parse('$url/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final cookie = resp.headers['set-cookie'] ?? '';
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['user'] != null) {
          await saveConfig(url, username, password, cookie);
          return data['user'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getCamionsFile() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/mouvements-camions?statut=EN_ATTENTE'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['camions'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCamionsInternes() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/mouvements-camions?statut=TOUS'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final all = (data['camions'] as List).cast<Map<String, dynamic>>();
        return all.where((c) => ['EN_COURS_TRAITEMENT', 'DEMARRAGE_EMPLISSAGE'].contains(c['statut'])).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCamionsPrets() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/mouvements-camions?statut=PRET_A_SORTIR'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['camions'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getHistorique(String date) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/mouvements-camions?all=1&date=$date'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['camions'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/notifications'), headers: _headers).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['notifications'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> getStats(String date) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/mouvements-camions/stats?date=$date'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> demarrerEmplissage(int id) async {
    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/api/mouvements-camions'),
        headers: _headers,
        body: jsonEncode({'id': id, 'action': 'demarrer'}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> terminerChargement(int id, Map<String, dynamic> data) async {
    try {
      final resp = await http.put(
        Uri.parse('$baseUrl/api/mouvements-camions'),
        headers: _headers,
        body: jsonEncode({...data, 'id': id, 'action': 'terminer'}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─── AUTH WRAPPER ─────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await ApiService.loadConfig();
    if (ApiService.baseUrl.isNotEmpty && ApiService._cookie != null) {
      try {
        final resp = await http
            .get(Uri.parse('${ApiService.baseUrl}/api/auth/session'), headers: {'Cookie': ApiService._cookie!})
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['user'] != null && data['user']['role'] == 'CHEF_EQUIPE') {
            setState(() {
              _user = data['user'];
              _loading = false;
            });
            return;
          }
        }
      } catch (_) {}
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary)));
    }
    if (_user == null) {
      return LoginScreen(onLogin: (u) => setState(() => _user = u));
    }
    return HomeScreen(user: _user!, onLogout: () => setState(() => _user = null));
  }
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginScreen({Key? key, required this.onLogin}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _urlCtrl = TextEditingController(text: 'http://');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _remember = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('base_url') ?? '';
    final user = prefs.getString('session_username') ?? '';
    final pass = prefs.getString('session_password') ?? '';
    if (url.isNotEmpty && user.isNotEmpty) {
      setState(() {
        _urlCtrl.text = url;
        _userCtrl.text = user;
        _passCtrl.text = pass;
        _remember = true;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final user = await ApiService.login(url, _userCtrl.text.trim(), _passCtrl.text.trim());
    if (user != null) {
      if (user['role'] != 'CHEF_EQUIPE') {
        setState(() {
          _error = 'Accès réservé au Chef d\'équipe';
          _loading = false;
        });
      } else {
        if (_remember) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('base_url', url);
          await prefs.setString('session_username', _userCtrl.text.trim());
          await prefs.setString('session_password', _passCtrl.text.trim());
        }
        widget.onLogin(user);
      }
    } else {
      setState(() {
        _error = 'Identifiants incorrects ou serveur inaccessible';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kBg, kCard],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  builder: (ctx, val, _) => Transform.scale(
                    scale: val,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kPrimary.withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(Icons.local_fire_department, color: kPrimary, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('OUARGAZ', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const Text('Chef d\'équipe Mobile', style: TextStyle(color: kMuted, fontSize: 14, letterSpacing: 1)),
                const SizedBox(height: 40),
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'URL serveur',
                    prefixIcon: const Icon(Icons.link, color: kMuted),
                    hintText: 'http://192.168.1.100:3000',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(
                    labelText: 'Identifiant',
                    prefixIcon: const Icon(Icons.person, color: kMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock, color: kMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(value: _remember, activeColor: kPrimary, onChanged: (v) => setState(() => _remember = v ?? false)),
                    const Expanded(child: Text('Se souvenir de moi', style: TextStyle(color: kMuted, fontSize: 12))),
                    IconButton(onPressed: () => ThemeController.toggle(), icon: const Icon(Icons.dark_mode, color: kMuted, size: 20)),
                  ],
                ),
                if (_error.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error, style: const TextStyle(color: kPrimary, fontSize: 13)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Connexion', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}

// ─── HOME ─────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const HomeScreen({Key? key, required this.user, required this.onLogout}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> _fileAttente = [];
  List<Map<String, dynamic>> _internes = [];
  List<Map<String, dynamic>> _prets = [];
  List<Map<String, dynamic>> _notifs = [];
  Map<String, dynamic>? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final fa = await ApiService.getCamionsFile();
    final ci = await ApiService.getCamionsInternes();
    final cp = await ApiService.getCamionsPrets();
    final n = await ApiService.getNotifications();
    final s = await ApiService.getStats(DateFormat('yyyy-MM-dd').format(DateTime.now()));
    if (mounted) {
      setState(() {
        _fileAttente = fa;
        _internes = ci;
        _prets = cp;
        _notifs = n;
        _stats = s;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => n['read'] == false).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: kPrimary, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('OUARGAZ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('Chef équipe', style: TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.brightness_6_outlined), onPressed: ThemeController.toggle),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => setState(() => _tab = 4)),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await http.post(Uri.parse('${ApiService.baseUrl}/api/auth/logout'), headers: {'Cookie': ApiService._cookie ?? ''}).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('', 200));
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              widget.onLogout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildFileAttente(),
          _buildInternes(),
          _buildPrets(),
          _buildHistorique(),
          _buildNotifs(),
          if (_stats != null) _buildKpi(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kCard,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'File'),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.local_shipping_outlined),
                if (_internes.isNotEmpty) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kInfo, shape: BoxShape.circle))),
              ],
            ),
            label: 'Internes',
          ),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.check_circle_outline),
                if (_prets.isNotEmpty) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle))),
              ],
            ),
            label: 'Prêts',
          ),
          const NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (unread > 0) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle))),
              ],
            ),
            label: 'Notifs',
          ),
          const NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'KPI'),
        ],
      ),
    );
  }

  Widget _buildFileAttente() => RefreshIndicator(
    color: kPrimary,
    onRefresh: _load,
    child: _fileAttente.isEmpty
        ? const Center(child: Text('Aucun camion en attente', style: TextStyle(color: kMuted)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _fileAttente.length,
            itemBuilder: (ctx, i) => _camionTile(_fileAttente[i]),
          ),
  );

  Widget _buildInternes() => RefreshIndicator(
    color: kPrimary,
    onRefresh: _load,
    child: _internes.isEmpty
        ? const Center(child: Text('Aucun camion en traitement', style: TextStyle(color: kMuted)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _internes.length,
            itemBuilder: (ctx, i) => _detailTile(_internes[i]),
          ),
  );

  Widget _buildPrets() => RefreshIndicator(
    color: kPrimary,
    onRefresh: _load,
    child: _prets.isEmpty
        ? const Center(child: Text('Aucun camion prêt', style: TextStyle(color: kMuted)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _prets.length,
            itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(_prets[i]['matricule'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(_prets[i]['client'] ?? '', style: const TextStyle(color: kMuted, fontSize: 12)), trailing: const Icon(Icons.check_circle, color: kSuccess))),
          ),
  );

  Widget _buildHistorique() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService.getHistorique(date),
      builder: (ctx, snap) => snap.hasData
          ? snap.data!.isEmpty
              ? const Center(child: Text('Aucun camion', style: TextStyle(color: kMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: snap.data!.length,
                  itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(snap.data![i]['matricule'] ?? ''), subtitle: Text('${snap.data![i]['client']} • ${snap.data![i]['statut']}', style: const TextStyle(color: kMuted, fontSize: 11)))),
                )
          : const Center(child: CircularProgressIndicator(color: kPrimary)),
    );
  }

  Widget _buildNotifs() => RefreshIndicator(
    color: kPrimary,
    onRefresh: _load,
    child: _notifs.isEmpty
        ? const Center(child: Text('Aucune notification', style: TextStyle(color: kMuted)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _notifs.length,
            itemBuilder: (ctx, i) {
              final n = _notifs[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: (n['read'] == true) ? kCard : kPrimary.withOpacity(0.08),
                child: ListTile(
                  leading: Icon((n['read'] == true) ? Icons.notifications_outlined : Icons.notifications_active, color: (n['read'] == true) ? kMuted : kPrimary),
                  title: Text(n['title'] ?? '', style: TextStyle(fontWeight: (n['read'] == true) ? FontWeight.w600 : FontWeight.w800)),
                  subtitle: Text(n['message'] ?? '', style: const TextStyle(color: kMuted, fontSize: 12)),
                ),
              );
            },
          ),
  );

  Widget _buildKpi() {
    final day = _stats!['day'] ?? {};
    final counts = _stats!['dayCounts'] ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpiCard('Arrivés', counts['arrives'] ?? 0, kPrimary),
              _kpiCard('Internes', counts['internes'] ?? 0, kInfo),
              _kpiCard('Prêts', counts['prets'] ?? 0, kSuccess),
              _kpiCard('Sortis', counts['sortis'] ?? 0, kSuccess),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Bouteilles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpiCard('Entrées', day['entreesTotal'] ?? 0, kInfo),
              _kpiCard('Sorties', day['sortiesTotal'] ?? 0, kSuccess),
            ],
          ),
        ],
      ),
    );
  }

  Widget _camionTile(Map<String, dynamic> c) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['matricule'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text(c['client'] ?? '', style: const TextStyle(color: kMuted, fontSize: 12))])),
              Text(c['chauffeur'] ?? '', style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge('12 kg', '${c['saisie_12kg'] ?? 0}', k12kg),
              _badge('6 kg', '${c['saisie_6kg'] ?? 0}', k6kg),
              _badge('3 kg', '${c['saisie_3kg'] ?? 0}', k3kg),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _detailTile(Map<String, dynamic> c) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(c['matricule'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(c['client'] ?? '', style: const TextStyle(color: kMuted, fontSize: 12)),
    ),
  );

  Widget _badge(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)), Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800))]),
  );

  Widget _kpiCard(String label, dynamic value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800))],
    ),
  );
}
