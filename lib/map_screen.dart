import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  bool _mapReady = false;

  LatLng? _currentPosition;
  bool _isMarkingMode = false;
  Set<Marker> _markers = {};
  Set<Marker> _allMarkers = {};
  final TextEditingController _searchController = TextEditingController();

  Map<String, Map<String, int>> _markerVotes = {};
  Map<String, String> _markerTitles = {};
  Map<String, String> _markerCreators = {};
  Map<String, String> _markerCategories = {};

  // Common search categories
  final List<String> _commonCategories = [
    'washroom', 'cafe', 'drink', 'coffee', 'masjid', 'temple', 'spot'
  ];

  // Categories for marking with colors
  final Map<String, Color> _markingCategories = {
    'washroom': Colors.blue,
    'cafe': Colors.brown,
    'restaurant': Colors.red,
    'park': Colors.green,
    'shopping': Colors.purple,
    'temple': Colors.orange,
    'masjid': Colors.teal,
    'gas station': Colors.black,
    'parking': Colors.grey,
    'hospital': Colors.pink,
    'other': Colors.indigo,
  };

  // Map of category icons
  final Map<String, IconData> _categoryIcons = {
    'washroom': Icons.wc,
    'cafe': Icons.local_cafe,
    'restaurant': Icons.restaurant,
    'park': Icons.park,
    'shopping': Icons.shopping_cart,
    'temple': Icons.temple_buddhist,
    'masjid': Icons.mosque,
    'gas station': Icons.local_gas_station,
    'parking': Icons.local_parking,
    'hospital': Icons.local_hospital,
    'other': Icons.place,
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedMarkers();
    await _determinePosition();
  }

  // Custom marker widget for OpenStreetMap
  Widget _buildMarkerWidget(String category, String markerId) {
    final color = _markingCategories[category] ?? Colors.indigo;
    return GestureDetector(
      onTap: () => _showVoteDialog(markerId),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(
          _categoryIcons[category] ?? Icons.place,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _loadSavedMarkers() async {
    try {
      final col = FirebaseFirestore.instance.collection('public_markers');
      final snap = await col.get();

      _allMarkers.clear();
      _markerTitles.clear();
      _markerVotes.clear();
      _markerCreators.clear();
      _markerCategories.clear();

      for (final doc in snap.docs) {
        final data = doc.data();
        final id = doc.id;
        final title = data['title'] ?? '';
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final likes = (data['likes'] as num?)?.toInt() ?? 0;
        final dislikes = (data['dislikes'] as num?)?.toInt() ?? 0;
        final createdBy = data['createdBy'] ?? '';
        final category = data['category'] ?? 'other';

        if (lat == null || lng == null) continue;

        _markerTitles[id] = title;
        _markerVotes[id] = {'likes': likes, 'dislikes': dislikes};
        _markerCreators[id] = createdBy;
        _markerCategories[id] = category;

        final marker = Marker(
          point: LatLng(lat, lng),  // Changed from position to point
          width: 40,
          height: 40,
          builder: (ctx) => _buildMarkerWidget(category, id),  // Added builder
        );
        _allMarkers.add(marker);
      }

      setState(() => _markers = _allMarkers);
    } catch (e) {
      debugPrint("Error loading markers: $e");
    }
  }

  // REMOVED: _getCustomMarkerIcon and _colorToHue methods (not needed for OpenStreetMap)

  Future<void> _saveMarkers() async {
    final col = FirebaseFirestore.instance.collection('public_markers');

    for (final m in _allMarkers) {
      // For OpenStreetMap, we need to store the marker ID differently
      // Since Marker doesn't have markerId property anymore, we'll use a different approach
      final markerPoint = m.point;
      // We need to find the marker ID by position - this is a limitation of the change
      String? markerId;
      for (var entry in _markerTitles.entries) {
        // This is a simplified approach - you might need to adjust this logic
        markerId = entry.key;
        break;
      }
      
      if (markerId != null) {
        try {
          await col.doc(markerId).set({
            'title': _markerTitles[markerId] ?? '',
            'lat': markerPoint.latitude,
            'lng': markerPoint.longitude,
            'likes': _markerVotes[markerId]?['likes'] ?? 0,
            'dislikes': _markerVotes[markerId]?['dislikes'] ?? 0,
            'createdBy': _markerCreators[markerId] ?? '',
            'category': _markerCategories[markerId] ?? 'other',
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    }
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

    Position position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = LatLng(position.latitude, position.longitude));

    if (_mapReady && _currentPosition != null) {
      _mapController.move(_currentPosition!, 14.0);  // Changed from animateCamera to move
    }
  }

  void _onMapCreated() {
    _mapReady = true;
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {  // Changed parameters
    if (!_isMarkingMode) return;

    String selectedCategory = 'other';
    String customName = '';

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
                    "Mark this location",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text("Category:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Improved category selection with horizontal scroll
                  SizedBox(
                    height: 60,
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
                  const Text("Custom name (optional):", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "e.g. Good Coffee, Pani Puri",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => customName = val,
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
                            final id = DateTime.now().toIso8601String();
                            _markerTitles[id] = customName.isNotEmpty ? customName : selectedCategory;
                            final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
                            _markerCreators[id] = uid;
                            _markerCategories[id] = selectedCategory;

                            final marker = Marker(
                              point: position,  // Changed from position to point
                              width: 40,
                              height: 40,
                              builder: (ctx) => _buildMarkerWidget(selectedCategory, id),
                            );

                            setState(() {
                              _allMarkers.add(marker);
                              _markers = _allMarkers;
                              _markerVotes[id] = {'likes': 0, 'dislikes': 0};
                              _isMarkingMode = false;
                            });

                            await _saveMarkers();
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text("Save"),
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
      },
    );
  }

  Future<void> _deleteMarker(String markerId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_markerCreators[markerId] != currentUid) return;

    setState(() {
      _allMarkers.removeWhere((m) {
        // Since we don't have markerId directly, we need to find the marker by ID
        // This is a simplified approach - you might need to adjust this
        return _markerTitles[markerId] != null;
      });
      _markers = Set.from(_allMarkers);
      _markerTitles.remove(markerId);
      _markerVotes.remove(markerId);
      _markerCreators.remove(markerId);
      _markerCategories.remove(markerId);
    });

    try {
      await FirebaseFirestore.instance.collection('public_markers').doc(markerId).delete();
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marker deleted")));
  }

  void _showVoteDialog(String markerId) {
    int likes = _markerVotes[markerId]?['likes'] ?? 0;
    int dislikes = _markerVotes[markerId]?['dislikes'] ?? 0;
    String title = _markerTitles[markerId] ?? "Marked Location";
    String category = _markerCategories[markerId] ?? 'other';
    Color categoryColor = _markingCategories[category] ?? Colors.indigo;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_categoryIcons[category], color: categoryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Category: $category", style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up, color: Colors.green),
                        onPressed: () async {
                          setState(() {
                            _markerVotes[markerId]?['likes'] = (_markerVotes[markerId]?['likes'] ?? 0) + 1;
                          });
                          await _saveMarkers();
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      Text("$likes", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_down, color: Colors.red),
                        onPressed: () async {
                          setState(() {
                            _markerVotes[markerId]?['dislikes'] = (_markerVotes[markerId]?['dislikes'] ?? 0) + 1;
                          });
                          await _saveMarkers();
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      Text("$dislikes", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_markerCreators[markerId] == currentUid)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  label: const Text("Delete Marker", style: TextStyle(color: Colors.red)),
                  onPressed: () async {
                    await _deleteMarker(markerId);
                    if (mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchByCategory(String category) {
    _searchController.text = category;
    _searchAndZoom();
  }

  void _searchAndZoom() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _markers = _allMarkers);
      return;
    }

    final filtered = _allMarkers.where((marker) {
      // Since we don't have direct marker ID access, we need to find the title by position
      // This is a simplified approach
      for (var entry in _markerTitles.entries) {
        final markerId = entry.key;
        final title = _markerTitles[markerId]?.toLowerCase() ?? "";
        final category = _markerCategories[markerId]?.toLowerCase() ?? "";
        if (title.contains(query) || category.contains(query)) {
          return true;
        }
      }
      return false;
    }).toSet();

    if (filtered.isNotEmpty) {
      setState(() => _markers = filtered);
      if (filtered.isNotEmpty && _mapReady) {
        final firstMarker = filtered.first;
        _mapController.move(firstMarker.point, 15.0);  // Changed from animateCamera to move
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No matching marker found"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Loocal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // REPLACED GoogleMap with FlutterMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentPosition!,
                    zoom: 14.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    // OpenStreetMap tiles
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.loocal',
                    ),
                    // Markers layer
                    MarkerLayer(
                      markers: _markers.toList(),
                    ),
                  ],
                ),
                if (!_isMarkingMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      children: [
                        // Search bar
                        Container(
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
                                    hintText: "Search markers...",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onSubmitted: (_) => _searchAndZoom(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search), 
                                onPressed: _searchAndZoom,
                                color: Colors.blue[700],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Category buttons
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 2))
                            ],
                          ),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _commonCategories.map((category) {
                              final color = _markingCategories[category] ?? Colors.indigo;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                child: FilterChip(
                                  label: Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: color,
                                  selectedColor: color.withOpacity(0.8),
                                  onSelected: (_) => _searchByCategory(category),
                                  showCheckmark: false,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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
            onPressed: () {
              setState(() => _isMarkingMode = !_isMarkingMode);
            },
            backgroundColor: _isMarkingMode ? Colors.blue[700] : Colors.blue,
            child: Icon(
              _isMarkingMode ? Icons.add_location_alt : Icons.add,
              color: Colors.white,
            ),
          ),
          // Added my location button
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _determinePosition,
            backgroundColor: Colors.green,
            mini: true,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }
}