import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../features/auth/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _controller = PageController();
  String _userName = '';
  String _userPhone = '';
  String? _photoUrl;

  final List<String> sliderImages = [
     'assets/images/OIP1.jpg',
  'assets/images/OIP2.jpg',
  'assets/images/OIP.jpg',
  ];

  final List<Map<String, dynamic>> buttons = [
    {'icon': Icons.person,        'label': 'Profile',    'route': '/profile',     'color': Color(0xFF7B1FA2)},
    //{'icon': Icons.support_agent, 'label': 'Assistance', 'route': '/assistance',  'color': Color(0xFF1565C0)},
    {'icon': Icons.warning_amber, 'label': 'SOS Alert',  'route': '/sosNew',      'color': Color(0xFFB71C1C)},
    {'icon': Icons.chat,          'label': 'Chatbot',    'route': '/chatbot',     'color': Color(0xFF00695C)},
    {'icon': Icons.location_on,   'label': 'Track Me',   'route': '/trackme',     'color': Color(0xFF4527A0)},
    {'icon': Icons.mic,           'label': 'Record',     'route': '/record',      'color': Color(0xFFAD1457)},
    //{'icon': Icons.block,         'label': 'Blacklist',  'route': '/blackbanana', 'color': Color(0xFF37474F)},
    {'icon': Icons.settings,      'label': 'Settings',   'route': '/settings',    'color': Color(0xFF558B2F)},
    //{'icon': Icons.lock,          'label': 'Pin',        'route': '/pin',         'color': Color(0xFF6A1B9A)},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final phone = await AuthService.getPhone();
    if (phone == null) return;
    setState(() => _userPhone = phone);
    try {
      final docId = phone.replaceAll(RegExp(r'[^\w]'), '_');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? '';
          _photoUrl = doc.data()?['photoUrl'];
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppLogo(size: 32),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName.isNotEmpty ? 'Hello, $_userName 👋' : 'Hello 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Stay safe. We\'re with you.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Image slider
                SizedBox(
                  height: 160,
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemCount: sliderImages.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                            sliderImages[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 40)),
                          ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    sliderImages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentIndex == i ? 14 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _currentIndex == i ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Feature grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: buttons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final btn = buttons[index];
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, btn['route']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (btn['color'] as Color).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (btn['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(btn['icon'] as IconData,
                              size: 28, color: btn['color'] as Color),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          btn['label'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
              child: _photoUrl == null
                  ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                  : null,
            ),
            accountName: Text(
              _userName.isNotEmpty ? _userName : 'User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              _userPhone.isNotEmpty ? _userPhone : '',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _drawerItem(Icons.home_outlined,    'Home',               '/home'),
          _drawerItem(Icons.person_outline,   'Profile',            '/profile'),
          _drawerItem(Icons.contacts_outlined,'Emergency Contacts', '/sosSettings'),
          _drawerItem(Icons.settings_outlined,'Settings',           '/settings'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Logout',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
