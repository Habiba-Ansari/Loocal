import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_screen.dart';
import 'private_map_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;
  final List<Map<String, dynamic>> _sliderItems = [
    {
      'image': 'home1.jpg',
      'type': 'private'
    },
    {
      'image': 'home2.jpg',
      'type': 'private'
    },
    {
      'image': 'home3.jpg',
      'type': 'public'
    },
    {
      'image': 'home4.jpg',
      'type': 'public'
    },
    {
      'image': 'home5.jpg',
      'type': 'public'
    },
  ];

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Handle error
      print('Logout error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-slide the images
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= _sliderItems.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoSlide();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateBasedOnImage(int index) {
    if (_sliderItems[index]['type'] == 'public') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivateMapScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F0FA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/loocal.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.location_on,
                  color: Colors.white,
                );
              },
            ),
            const SizedBox(width: 10),
            const Text("Loocal - Home"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image Slider Section - optimized for square images
            SizedBox(
              height: 350, // Increased height to accommodate square images
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _sliderItems.length,
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (_, index) {
                        return GestureDetector(
                          onTap: () => _navigateBasedOnImage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.all(_currentPage == index ? 5 : 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/${_sliderItems[index]['image']}',
                                fit: BoxFit.fitHeight, // Changed to fitHeight for square images
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 50,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _sliderItems.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.blueAccent
                              : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Welcome Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Welcome to Loocal",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Mark, vote, and remember your favorite places — publicly and privately.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 32),
                        ),
                        child: const Text("Public Map"),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivateMapScreen()),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 32),
                          side: const BorderSide(color: Colors.blueAccent),
                        ),
                        child: const Text("Private Map"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}