import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  // 🔹 Replace with women safety–related images
  final List<String> sliderImages = [
    'https://tse4.mm.bing.net/th/id/OIP.KR_RWMvnzdgOTcGCJDJcbQHaFC?pid=Api&P=0&h=220', // women empowerment
    'https://images.unsplash.com/photo-1606836591695-4f9231d41c36?auto=format&fit=crop&w=800&q=60', // helping hand
    'https://images.unsplash.com/photo-1606760227091-2a19f7ca6a60?auto=format&fit=crop&w=800&q=60', // safe night
    'https://images.unsplash.com/photo-1535968882947-1b06c1f93de0?auto=format&fit=crop&w=800&q=60', // safety awareness
  ];

  final List<Map<String, dynamic>> buttons = [
    {'icon': Icons.person, 'label': 'Profile', 'route': '/profile'},
    {'icon': Icons.support_agent, 'label': 'Assistance', 'route': '/assistance'},
    {'icon': Icons.warning_amber, 'label': 'SOS Alert', 'route': '/sosNew'},
    {'icon': Icons.chat, 'label': 'Chatbot', 'route': '/chatbot'},
    {'icon': Icons.location_on, 'label': 'Track Me', 'route': '/trackme'},
    {'icon': Icons.mic, 'label': 'Record', 'route': '/record'},
    {'icon': Icons.block, 'label': 'Blacklist', 'route': '/blackbanana'},
    {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings'},
    {'icon': Icons.lock, 'label': 'Pin', 'route': '/pin'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🟢 White background
      appBar: AppBar(
        title: const Text("Nirbhaya"),
        centerTitle: true,
        backgroundColor: const Color(0xFF101D68), // Royal blue
        foregroundColor: Colors.white,
        elevation: 6,
        shadowColor: Colors.black45,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // 🖼 Image Slider
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: sliderImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      sliderImages[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // ⚪ Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              sliderImages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 12 : 8,
                height: _currentIndex == index ? 12 : 8,
                decoration: BoxDecoration(
                  color:
                      _currentIndex == index ? const Color(0xFF101D68) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 🔘 Feature Buttons Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: buttons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, buttons[index]['route']);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF101D68),
                          Color(0xFF3B82F6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          buttons[index]['icon'],
                          size: 40,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          buttons[index]['label'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
}
