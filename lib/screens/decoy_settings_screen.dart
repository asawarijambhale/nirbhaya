
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class DecoySettingsScreen extends StatefulWidget {
  const DecoySettingsScreen({super.key});

  @override
  State<DecoySettingsScreen> createState() => _DecoySettingsScreenState();
}

class _DecoySettingsScreenState extends State<DecoySettingsScreen> {
  String? _selectedPackage;
  String? _selectedAppName;
  String _currentIdentity = 'MainDefault';
  List<Application> _apps = [];
  bool _isLoading = true;

  final List<Map<String, String>> _identities = [
    {'name': 'MainDefault', 'label': 'Nirbhaya (Default)'},
    {'name': 'Calculator', 'label': 'Calculator'},
    {'name': 'Notes', 'label': 'Notes'},
    {'name': 'Calendar', 'label': 'Calendar'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadApps();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPackage = prefs.getString('decoy_package');
      _selectedAppName = prefs.getString('decoy_app_name');
      _currentIdentity = prefs.getString('decoy_identity') ?? 'MainDefault';
    });
  }

  Future<void> _loadApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
    );
    
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    setState(() {
      _apps = apps;
      _isLoading = false;
    });
  }

  Future<void> _saveDecoyApp(Application app) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('decoy_package', app.packageName);
    await prefs.setString('decoy_app_name', app.appName);
    setState(() {
      _selectedPackage = app.packageName;
      _selectedAppName = app.appName;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected ${app.appName} as decoy app')),
    );
  }

  Future<void> _changeIdentity(String identityName) async {
    try {
      // FlutterDynamicIconPlus works similarly by enabling/disabling activity-alias components
      await FlutterDynamicIconPlus.setAlternateIconName(iconName: identityName);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('decoy_identity', identityName);
      setState(() {
        _currentIdentity = identityName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('App identity changed to $identityName. The app may close or restart.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing identity: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decoy Settings'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'App Appearance (Decoy Mode)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Column(
                        children: _identities.map((identity) {
                          bool isSelected = _currentIdentity == identity['name'];
                          return RadioListTile<String>(
                            title: Text(identity['label']!),
                            value: identity['name']!,
                            groupValue: _currentIdentity,
                            onChanged: (value) {
                              if (value != null) _changeIdentity(value);
                            },
                            secondary: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Decoy Launch App',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: ListTile(
                        title: const Text('Current Decoy App'),
                        subtitle: Text(_selectedAppName ?? 'Gallery (Default)'),
                        trailing: _selectedPackage != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('decoy_package');
                                  await prefs.remove('decoy_app_name');
                                  setState(() {
                                    _selectedPackage = null;
                                    _selectedAppName = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Select an app to open on wrong PIN entry:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _apps.length,
                    itemBuilder: (context, index) {
                      Application app = _apps[index];
                      bool isSelected = _selectedPackage == app.packageName;

                      return ListTile(
                        leading: app is ApplicationWithIcon
                            ? Image.memory(app.icon, width: 40)
                            : const Icon(Icons.android),
                        title: Text(app.appName),
                        subtitle: Text(app.packageName),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () => _saveDecoyApp(app),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
