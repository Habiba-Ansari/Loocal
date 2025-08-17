import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  bool _mapReady = false;

  LatLng? _currentPosition;
  bool _isMarkingMode = false;
  Set<Marker> _markers = {};
  Set<Marker> _allMarkers = {};
  final TextEditingController _searchController = TextEditingController();

  Map<String, Map<String, int>> _markerVotes = {};
  Map<String, String> _markerTitles = {};
  Map<String, String> _markerCreators = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSavedMarkers();
    await _determinePosition();
  }

  Future<void> _loadSavedMarkers() async {
    try {
      final col = FirebaseFirestore.instance.collection('public_markers');
      final snap = await col.get();

      _allMarkers.clear();
      _markerTitles.clear();
      _markerVotes.clear();
      _markerCreators.clear();

      for (final doc in snap.docs) {
        final data = doc.data();
        final id = doc.id;
        final title = data['title'] ?? '';
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final likes = (data['likes'] as num?)?.toInt() ?? 0;
        final dislikes = (data['dislikes'] as num?)?.toInt() ?? 0;
        final createdBy = data['createdBy'] ?? '';

        if (lat == null || lng == null) continue;

        _markerTitles[id] = title;
        _markerVotes[id] = {'likes': likes, 'dislikes': dislikes};
        _markerCreators[id] = createdBy;

        final marker = Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          onTap: () => _showVoteDialog(id),
        );
        _allMarkers.add(marker);
      }

      setState(() => _markers = _allMarkers);
    } catch (e) {
      debugPrint("Error loading markers: $e");
    }
  }

  Future<void> _saveMarkers() async {
    final col = FirebaseFirestore.instance.collection('public_markers');

    for (final m in _allMarkers) {
      final id = m.markerId.value;
      try {
        await col.doc(id).set({
          'title': _markerTitles[id] ?? '',
          'lat': m.position.latitude,
          'lng': m.position.longitude,
          'likes': _markerVotes[id]?['likes'] ?? 0,
          'dislikes': _markerVotes[id]?['dislikes'] ?? 0,
          'createdBy': _markerCreators[id] ?? '',
        }, SetOptions(merge: true));
      } catch (_) {}
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
      _mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;
  }

  void _onMapTap(LatLng position) {
    if (!_isMarkingMode) return;

    showDialog(
      context: context,
      builder: (context) {
        String inputText = '';
        return AlertDialog(
          title: const Text("Name this place"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "e.g. Good Coffee, Pani Puri"),
            onChanged: (val) => inputText = val,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final id = DateTime.now().toIso8601String();
                _markerTitles[id] = inputText;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
                _markerCreators[id] = uid;

                final marker = Marker(
                  markerId: MarkerId(id),
                  position: position,
                  onTap: () => _showVoteDialog(id),
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
          ],
        );
      },
    );
  }

  Future<void> _deleteMarker(String markerId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_markerCreators[markerId] != currentUid) return;

    setState(() {
      _allMarkers.removeWhere((m) => m.markerId.value == markerId);
      _markers.removeWhere((m) => m.markerId.value == markerId);
      _markerTitles.remove(markerId);
      _markerVotes.remove(markerId);
      _markerCreators.remove(markerId);
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

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("👍 $likes   👎 $dislikes", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.thumb_up),
                  label: const Text("Like"),
                  onPressed: () async {
                    setState(() {
                      _markerVotes[markerId]?['likes'] = (_markerVotes[markerId]?['likes'] ?? 0) + 1;
                    });
                    await _saveMarkers();
                    if (mounted) Navigator.pop(context);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.thumb_down),
                  label: const Text("Dislike"),
                  onPressed: () async {
                    setState(() {
                      _markerVotes[markerId]?['dislikes'] = (_markerVotes[markerId]?['dislikes'] ?? 0) + 1;
                    });
                    await _saveMarkers();
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_markerCreators[markerId] == currentUid)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: "Delete Marker",
                onPressed: () async {
                  await _deleteMarker(markerId);
                  if (mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _searchAndZoom() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _markers = _allMarkers);
      return;
    }

    final filtered = _allMarkers.where((marker) {
      final title = _markerTitles[marker.markerId.value]?.toLowerCase() ?? "";
      return title.contains(query);
    }).toSet();

    if (filtered.isNotEmpty) {
      setState(() => _markers = filtered);
      if (_currentPosition != null && _mapReady) {
        _mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No matching marker found")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Loocal")),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  markers: _markers,
                  onTap: _onMapTap,
                ),
                if (!_isMarkingMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black12)],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Search markers...",
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _searchAndZoom(),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.search), onPressed: _searchAndZoom),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: FloatingActionButton(
          onPressed: () {
            setState(() => _isMarkingMode = !_isMarkingMode);
          },
          backgroundColor: Colors.blue,
          child: Icon(_isMarkingMode ? Icons.close : Icons.add_location_alt),
          tooltip: _isMarkingMode ? "Cancel Marking" : "Mark a Location",
        ),
      ),
    );
  }
}
