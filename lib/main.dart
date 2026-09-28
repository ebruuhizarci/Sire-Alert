import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_service.dart';
import 'firestore_service.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase başlatılamadı: $e');
  }
  runApp(const SireAlertApp());
}

class SireAlertApp extends StatefulWidget {
  const SireAlertApp({super.key});

  @override
  State<SireAlertApp> createState() => _SireAlertAppState();
}

class _SireAlertAppState extends State<SireAlertApp> {
  bool _isDarkMode = false;

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sire Alert',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: AuthScreen(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

// 🔐 GİRİŞ YAP & KAYIT OL EKRANI
class AuthScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const AuthScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta ve şifre alanlarını doldurun.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (!isFirebaseInitialized) {
        throw Exception("Firebase başlatılamamış! google-services.json eksik veya hatalı olabilir.");
      }

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (_nameController.text.isNotEmpty) {
          await userCredential.user?.updateDisplayName(_nameController.text.trim());
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(
              isDarkMode: widget.isDarkMode,
              onToggleDarkMode: widget.onToggleDarkMode,
              userEmail: email,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Firebase Auth Hatası: ${e.code}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint('SİSTEM HATASI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sire Alert',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Acil Durum Bildirim ve Takip Sistemi',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),

              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      if (!isLogin) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta Adresi',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre (Min. 6 karakter)',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                        child: Text(
                          isLogin ? 'Hesabınız yok mu? Kayıt Olun' : 'Zaten hesabınız var mı? Giriş Yapın',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🧭 NAVİGASYON & ANA EKRAN
class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final String userEmail;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.userEmail,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _localAlerts = [];

  void _addLocalAlert(Map<String, dynamic> alert) {
    setState(() {
      _localAlerts.add(alert);
    });
  }

  void _removeLocalAlert(int index) {
    setState(() {
      _localAlerts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MapScreen(
        isDarkMode: widget.isDarkMode,
        onToggleDarkMode: widget.onToggleDarkMode,
        localAlerts: _localAlerts,
        onAddAlert: _addLocalAlert,
      ),
      DashboardScreen(
        localAlerts: _localAlerts,
        isDarkMode: widget.isDarkMode,
        userEmail: widget.userEmail,
        onToggleDarkMode: widget.onToggleDarkMode,
        onRemoveAlert: _removeLocalAlert,
      ),
      EmergencyGuideScreen(isDarkMode: widget.isDarkMode),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Colors.redAccent),
            label: 'Harita',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.redAccent),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon: Icon(Icons.phone_in_talk, color: Colors.redAccent),
            label: 'Rehber',
          ),
        ],
      ),
    );
  }
}

// 🗺️ HARİTA EKRANI
class MapScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final List<Map<String, dynamic>> localAlerts;
  final Function(Map<String, dynamic>) onAddAlert;

  const MapScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.localAlerts,
    required this.onAddAlert,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  final FirestoreService _firestoreService = FirestoreService();

  LatLng _currentPosition = const LatLng(41.4511, 31.7930);
  bool _isMapReady = false;
  bool _isSirenActive = false;
  String _selectedCategoryFilter = 'Tümü';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  Future<void> _determinePosition({bool moveCamera = true}) async {
    try {
      Position position = await LocationService.getCurrentLocation();
      LatLng newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = newPos;
        });
      }
      if (moveCamera && _isMapReady) {
        _mapController.move(newPos, 15.0);
      }
    } catch (e) {
      debugPrint('--> Konum hatası: $e');
    }
  }

  void _triggerEmergencySiren() async {
    setState(() {
      _isSirenActive = !_isSirenActive;
    });

    if (_isSirenActive) {
      String emergencyText = '🚨 ACİL SİREN ÇALINDI! Yardım Çağrısı!';
      String category = 'Siren';

      if (isFirebaseInitialized) {
        await _firestoreService.addAlert(_currentPosition, emergencyText);
      }
      
      widget.onAddAlert({
        'point': _currentPosition,
        'description': emergencyText,
        'category': category,
        'time': DateTime.now(),
      });
    }
  }

  void _showAddAlertDialog(LatLng point) {
    final TextEditingController descriptionController = TextEditingController();
    String selectedCategory = 'Genel Acil';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yeni Uyarı Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Uyarı Türü:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Genel Acil', child: Text('⚠️ Genel Acil')),
                  DropdownMenuItem(value: 'Sağlık', child: Text('🚑 Sağlık / Medikal')),
                  DropdownMenuItem(value: 'Yangın', child: Text('🔥 Yangın / Gaz Leak')),
                  DropdownMenuItem(value: 'Deprem', child: Text('🏚️ Deprem / Enkaz')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedCategory = value);
                },
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Örn: Sağlık ekibi gerekiyor',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (descriptionController.text.isNotEmpty) {
                  if (isFirebaseInitialized) {
                    await _firestoreService.addAlert(
                      point,
                      '[$selectedCategory] ${descriptionController.text}',
                    );
                  }
                  
                  widget.onAddAlert({
                    'point': point,
                    'description': descriptionController.text,
                    'category': selectedCategory,
                    'time': DateTime.now(),
                  });

                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Sağlık')) return Icons.medical_services;
    if (category.contains('Yangın')) return Icons.local_fire_department;
    if (category.contains('Deprem')) return Icons.gavel;
    if (category.contains('Siren')) return Icons.campaign;
    return Icons.warning_amber_rounded;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Sağlık')) return Colors.blue;
    if (category.contains('Yangın')) return Colors.deepOrange;
    if (category.contains('Deprem')) return Colors.brown;
    if (category.contains('Siren')) return Colors.purple;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    List<Map<String, dynamic>> filteredLocalAlerts = widget.localAlerts.where((alert) {
      if (_selectedCategoryFilter == 'Tümü') return true;
      return (alert['category'] as String).contains(_selectedCategoryFilter);
    }).toList();

    final String tileUrl = isDark
        ? 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sire Alert', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.onToggleDarkMode,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _determinePosition(moveCamera: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 14.0,
              onMapReady: () {
                _isMapReady = true;
                _determinePosition(moveCamera: true);
              },
              onLongPress: (tapPosition, point) => _showAddAlertDialog(point),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.sire_alert',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 35),
                  ),
                  for (var item in filteredLocalAlerts)
                    Marker(
                      point: item['point'] as LatLng,
                      width: 50,
                      height: 50,
                      child: Icon(
                        _getCategoryIcon(item['category'] as String),
                        color: _getCategoryColor(item['category'] as String),
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggerEmergencySiren,
        backgroundColor: _isSirenActive ? Colors.black : Colors.red,
        icon: Icon(_isSirenActive ? Icons.volume_off : Icons.campaign, color: Colors.white),
        label: Text(_isSirenActive ? 'SİRENİ KAPAT' : 'SOS / SİREN', style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

// 📊 DASHBOARD EKRANI
class DashboardScreen extends StatelessWidget {
  final List<Map<String, dynamic>> localAlerts;
  final bool isDarkMode;
  final String userEmail;
  final VoidCallback onToggleDarkMode;
  final Function(int) onRemoveAlert;

  const DashboardScreen({
    super.key,
    required this.localAlerts,
    required this.isDarkMode,
    required this.userEmail,
    required this.onToggleDarkMode,
    required this.onRemoveAlert,
  });

  @override
  Widget build(BuildContext context) {
    int totalAlerts = localAlerts.length;
    int healthCount = localAlerts.where((a) => (a['category'] as String).contains('Sağlık')).length;
    int fireCount = localAlerts.where((a) => (a['category'] as String).contains('Yangın')).length;
    int quakeCount = localAlerts.where((a) => (a['category'] as String).contains('Deprem')).length;
    int sosCount = localAlerts.where((a) => (a['category'] as String).contains('Siren')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acil Durum Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              if (isFirebaseInitialized) {
                await FirebaseAuth.instance.signOut();
              }
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreen(
                      isDarkMode: isDarkMode,
                      onToggleDarkMode: onToggleDarkMode,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.redAccent.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kullanıcı Oturumu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            userEmail.isNotEmpty ? userEmail : 'kullanici@sirealert.com',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Aktif', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Genel İstatistikler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildStatCard('Toplam İhbar', '$totalAlerts', Colors.redAccent, Icons.notifications),
                const SizedBox(width: 10),
                _buildStatCard('SOS Çağrısı', '$sosCount', Colors.purple, Icons.campaign),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard('Sağlık', '$healthCount', Colors.blue, Icons.medical_services),
                const SizedBox(width: 10),
                _buildStatCard('Yangın', '$fireCount', Colors.deepOrange, Icons.local_fire_department),
                const SizedBox(width: 10),
                _buildStatCard('Deprem', '$quakeCount', Colors.brown, Icons.gavel),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Son Eklenen İhbarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (localAlerts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('Henüz aktif ihbar kaydı bulunmuyor.')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: localAlerts.length,
                itemBuilder: (context, index) {
                  final realIndex = localAlerts.length - 1 - index;
                  final item = localAlerts[realIndex];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.redAccent.withOpacity(0.2),
                        child: const Icon(Icons.warning, color: Colors.redAccent),
                      ),
                      title: Text(item['category'] ?? 'Acil Durum'),
                      subtitle: Text(item['description'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                        tooltip: 'Çözüldü Olarak İşaretle',
                        onPressed: () {
                          onRemoveAlert(realIndex);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('İhbar çözüldü olarak kaldırıldı.')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// 📞 ACİL DURUM REHBERİ EKRANI
class EmergencyGuideScreen extends StatelessWidget {
  final bool isDarkMode;

  const EmergencyGuideScreen({super.key, required this.isDarkMode});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendSMS(String number, String message) async {
    final Uri launchUri = Uri(scheme: 'sms', path: number, queryParameters: {'body': message});
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acil Durum Rehberi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Tek Tıkla Acil Arama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildCallTile('112 Tek Acil Çağrı', '112', Icons.local_hospital, Colors.redAccent),
          _buildCallTile('AFAD Afet İletişim', '122', Icons.nature_people, Colors.orange),
          _buildCallTile('Polis İmdat', '155', Icons.local_police, Colors.blue),
          _buildCallTile('İtfaiye', '110', Icons.local_fire_department, Colors.deepOrange),

          const SizedBox(height: 24),
          const Text('Yakınlarıma Hızlı SMS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.sms, color: Colors.white)),
              title: const Text('Güvendeyim Mesajı'),
              subtitle: const Text('Yakınlarınıza konum bilgisi ve güvende olduğunuzu iletin.'),
              trailing: const Icon(Icons.send, color: Colors.green),
              onTap: () => _sendSMS('', 'Güvendeyim! Sire Alert üzerinden konumumu iletiyorum.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallTile(String title, String number, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _makePhoneCall(number),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Numara: $number'),
        trailing: ElevatedButton.icon(
          onPressed: () => _makePhoneCall(number),
          icon: const Icon(Icons.call, size: 18, color: Colors.white),
          label: const Text('ARA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: color),
        ),
      ),
    );
  }
}