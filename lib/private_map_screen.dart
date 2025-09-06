import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMapScreen extends StatefulWidget {
  const PrivateMapScreen({super.key});

  @override
  State<PrivateMapScreen> createState() => _PrivateMapScreenState();
}

class _PrivateMapScreenState extends State<PrivateMapScreen> {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  bool _isMarkingMode = false;
  Set<Marker> _allMarkers = {};
  Set<Marker> _visibleMarkers = {};
  Map<String, List<String>> _markerNotes = {};
  Map<String, String> _markerTitles = {};
  Map<String, String> _markerCategories = {};
  final TextEditingController _searchController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String uid;

  // Categories for private markers with colors
  final Map<String, Color> _markingCategories = {
    'personal': Colors.purple,
    'work': Colors.blue,
    'travel': Colors.green,
    'shopping': Colors.orange,
    'food': Colors.red,
    'entertainment': Colors.pink,
    'other': Colors.grey,
  };

  // Map of category icons
  final Map<String, IconData> _categoryIcons = {
    'personal': Icons.person,
    'work': Icons.work,
    'travel': Icons.flight,
    'shopping': Icons.shopping_bag,
    'food': Icons.restaurant,
    'entertainment': Icons.movie,
    'other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    User? user = _auth.currentUser;
    if (user == null) {
      user = (await _auth.signInAnonymously()).user;
    }
    uid = user!.uid;
    await _determinePosition();
    await _loadMarkersFromFirestore();
  }

  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('markers').get();
    _allMarkers.clear();
    _markerTitles.clear();
    _markerNotes.clear();
    _markerCategories.clear();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final id = doc.id;
      final title = data['title'] ?? '';
      final notes = List<String>.from(data['notes'] ?? []);
      final category = data['category'] ?? 'other';

      _markerTitles[id] = title;
      _markerNotes[id] = notes;
      _markerCategories[id] = category;

      final marker = Marker(
        markerId: MarkerId(id),
        position: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
        icon: await _getCustomMarkerIcon(category),
        onTap: () => _openNotesDialog(id),
      );
      _allMarkers.add(marker);
    }

    setState(() {
      _visibleMarkers = _allMarkers;
    });
  }

  // Generate custom marker icon with category color
  Future<BitmapDescriptor> _getCustomMarkerIcon(String category) async {
    final color = _markingCategories[category] ?? Colors.grey;
    return BitmapDescriptor.defaultMarkerWithHue(
      _colorToHue(color),
    );
  }

  // Convert color to hue value for markers
  double _colorToHue(Color color) {
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    if (color == Colors.pink) return BitmapDescriptor.hueRose;
    return BitmapDescriptor.hueAzure; // Default
  }

  Future<void> _saveMarkerToFirestore(String id, LatLng pos) async {
    await _firestore.collection('users').doc(uid).collection('markers').doc(id).set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'title': _markerTitles[id] ?? '',
      'notes': _markerNotes[id] ?? [],
      'category': _markerCategories[id] ?? 'other',
    }, SetOptions(merge: true));
  }

  Future<void> _deleteMarkerFromFirestore(String id) async {
    await _firestore.collection('users').doc(uid).collection('markers').doc(id).delete();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }

  void _onMapTap(LatLng position) {
    if (!_isMarkingMode) return;
    
    String inputTitle = '';
    String selectedCategory = 'personal';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create a new marker",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text("Category:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Category selection
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _markingCategories.entries.map((entry) {
                        final category = entry.key;
                        final color = entry.value;
                        final isSelected = selectedCategory == category;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedCategory = category);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color : color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcons[category],
                                  color: isSelected ? Colors.white : color,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Marker title:", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "e.g. Favorite Coffee Shop",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => inputTitle = val,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context), 
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (inputTitle.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a title")),
                              );
                              return;
                            }
                            
                            final id = DateTime.now().millisecondsSinceEpoch.toString();
                            _markerTitles[id] = inputTitle;
                            _markerNotes[id] = [];
                            _markerCategories[id] = selectedCategory;

                            final marker = Marker(
                              markerId: MarkerId(id),
                              position: position,
                              icon: await _getCustomMarkerIcon(selectedCategory),
                              onTap: () => _openNotesDialog(id),
                            );

                            setState(() {
                              _allMarkers.add(marker);
                              _visibleMarkers = _allMarkers;
                              _isMarkingMode = false;
                            });

                            await _saveMarkerToFirestore(id, position);
                            Navigator.pop(context);
                          },
                          child: const Text("Save Marker"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteMarker(String markerId) async {
    setState(() {
      _allMarkers.removeWhere((m) => m.markerId.value == markerId);
      _visibleMarkers.removeWhere((m) => m.markerId.value == markerId);
      _markerTitles.remove(markerId);
      _markerNotes.remove(markerId);
      _markerCategories.remove(markerId);
    });

    await _deleteMarkerFromFirestore(markerId);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Marker deleted"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNotesDialog(String markerId) {
    final notes = _markerNotes[markerId] ?? [];
    final category = _markerCategories[markerId] ?? 'other';
    final categoryColor = _markingCategories[category] ?? Colors.grey;
    final controller = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _markerTitles[markerId] ?? "Untitled",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(_categoryIcons[category], color: categoryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color: categoryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteMarker(markerId),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (notes.isEmpty)
                const Center(
                  child: Text(
                    "No notes yet",
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(notes[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              _markerNotes[markerId]?.removeAt(index);
                              await _saveMarkerToFirestore(
                                markerId,
                                _allMarkers.firstWhere((m) => m.markerId.value == markerId).position,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: "Add a note...",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () async {
                            if (controller.text.trim().isNotEmpty) {
                              _markerNotes[markerId]?.add(controller.text.trim());
                              await _saveMarkerToFirestore(
                                markerId,
                                _allMarkers.firstWhere((m) => m.markerId.value == markerId).position,
                              );
                              controller.clear();
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _searchMarkers() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _visibleMarkers = _allMarkers);
      return;
    }
    final filtered = _allMarkers.where((marker) {
      final id = marker.markerId.value;
      final title = _markerTitles[id]?.toLowerCase() ?? '';
      final notes = (_markerNotes[id] ?? []).join(' ').toLowerCase();
      final category = _markerCategories[id]?.toLowerCase() ?? '';
      return title.contains(query) || notes.contains(query) || category.contains(query);
    }).toSet();

    setState(() {
      _visibleMarkers = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Loocal - Private Map", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
                  myLocationEnabled: true,
                  markers: _visibleMarkers,
                  onTap: _onMapTap,
                ),
                if (!_isMarkingMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Search markers, notes, or categories...",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onSubmitted: (_) => _searchMarkers(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchMarkers,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMarkingMode)
            FloatingActionButton(
              onPressed: () {
                setState(() => _isMarkingMode = false);
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.close, color: Colors.white),
              mini: true,
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => setState(() => _isMarkingMode = !_isMarkingMode),
            backgroundColor: _isMarkingMode ? Colors.deepPurple : Colors.purple,
            child: Icon(_isMarkingMode ? Icons.add_location_alt : Icons.note_add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}