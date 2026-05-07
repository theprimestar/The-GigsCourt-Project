import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

// ────────────────────────────────────────
// STEP 1: Name + Services
// ────────────────────────────────────────
class StepNameServices extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final SupabaseService supabaseService;
  final Function(Map<String, dynamic>) onNext;

  const StepNameServices({
    super.key,
    required this.initialData,
    required this.supabaseService,
    required this.onNext,
  });

  @override
  State<StepNameServices> createState() => _StepNameServicesState();
}

class _StepNameServicesState extends State<StepNameServices> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _customController = TextEditingController();

  List<Map<String, dynamic>> _allServices = [];
  List<String> _selectedSlugs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialData['fullName'] ?? '';
    _selectedSlugs = List<String>.from(widget.initialData['services'] ?? []);
    _loadServices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final services = await widget.supabaseService.getServices();
      if (mounted) {
        setState(() { _allServices = services; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = kDebugMode ? e.toString() : 'Failed to load services.';
          _loading = false;
        });
      }
    }
  }

  void _toggleService(String slug) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSlugs.contains(slug)
          ? _selectedSlugs.remove(slug)
          : _selectedSlugs.add(slug);
    });
  }

  Future<void> _requestCustomService() async {
    final name = _customController.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.mediumImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await widget.supabaseService.requestCustomService(userId: user.uid, serviceName: name);
      final slug = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      setState(() { _selectedSlugs.add(slug); _customController.clear(); });
    } catch (e) {
      if (mounted) setState(() => _error = kDebugMode ? e.toString() : 'Failed to add service.');
    }
  }

  void _handleContinue() {
    if (_nameController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (_selectedSlugs.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Please select at least one service.');
      return;
    }
    widget.onNext({'fullName': _nameController.text.trim(), 'services': _selectedSlugs});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final query = _searchController.text.toLowerCase();
    final filtered = _allServices.where((s) => (s['name'] as String).toLowerCase().contains(query)).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in filtered) { grouped.putIfAbsent(s['category'] as String, () => []).add(s); }
    final sortedCategories = grouped.keys.toList()..sort();

    return Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: const Text('Back', style: TextStyle(fontSize: 14)),
          style: TextButton.styleFrom(foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73), padding: EdgeInsets.zero),
        )),
        const SizedBox(height: 16),
        Text('Tell us about yourself', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A), letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('This helps clients find you', style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73))),
        const SizedBox(height: 28),
        TextField(
          controller: _nameController,
          style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'e.g. John Doe or JD Barbing', hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
            filled: true, fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 28),
        if (_selectedSlugs.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: _selectedSlugs.map((slug) => GestureDetector(
            onTap: () => _toggleService(slug),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF3B5FE3), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF3B5FE3).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(slug.replaceAll('-', ' '), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6), const Icon(Icons.close, size: 14, color: Colors.white70),
              ]),
            ),
          )).toList()),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'Search services...', hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
            prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white30 : Colors.black26),
            filled: true, fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          ...List.generate(3, (i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 80, height: 12, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(4, (j) => Container(width: [80.0, 100.0, 70.0, 90.0][j], height: 34, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(17))))),
          ])))
        else if (sortedCategories.isEmpty && query.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No services found', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 15))))
        else
          ...sortedCategories.map((cat) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73), letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: grouped[cat]!.map((s) {
              final slug = s['slug'] as String;
              final selected = _selectedSlugs.contains(slug);
              return GestureDetector(onTap: () => _toggleService(slug), child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF3B5FE3) : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? const Color(0xFF3B5FE3) : (isDark ? Colors.white12 : const Color(0xFFE5E5EA)), width: selected ? 0 : 1),
                  boxShadow: selected ? [BoxShadow(color: const Color(0xFF3B5FE3).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(s['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? Colors.white : (isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)))),
              ));
            }).toList()),
          ]))),
        const SizedBox(height: 4),
        Text("Can't find your service?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _customController, style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)), decoration: InputDecoration(
            hintText: 'Type your service...', hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
            filled: true, fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ))),
          const SizedBox(width: 10),
          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF3B5FE3).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]), child: ElevatedButton(
            onPressed: _requestCustomService,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B5FE3), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ]),
        const SizedBox(height: 6),
        Text('Your request will be reviewed by our team.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26)),
        const SizedBox(height: 24),
      ]))),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFF3B30).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)))]))),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 20), child: SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _handleContinue, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B5FE3), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))), child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2))))),
    ]);
  }
}

// ────────────────────────────────────────
// STEP 2: Workspace Location (Real Map)
// ────────────────────────────────────────
class StepLocation extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final SupabaseService supabaseService;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const StepLocation({super.key, required this.initialData, required this.supabaseService, required this.onNext, required this.onBack});

  @override
  State<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends State<StepLocation> {
  final _addressController = TextEditingController();
  LatLng? _currentPosition;
  double? _lat, _lng;
  bool _loadingLocation = true;
  bool _geoError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialData['workspaceAddress'] ?? '';
    final prevLat = widget.initialData['workspaceLat'];
    final prevLng = widget.initialData['workspaceLng'];
    if (prevLat != null && prevLng != null) {
      _lat = prevLat;
      _lng = prevLng;
      _currentPosition = LatLng(prevLat, prevLng);
      _loadingLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() { _addressController.dispose(); super.dispose(); }

  Future<void> _getCurrentLocation() async {
    setState(() { _loadingLocation = true; _geoError = false; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _geoError = true; _loadingLocation = false; });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() { _geoError = true; _loadingLocation = false; });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _lat = position.latitude;
        _lng = position.longitude;
        _loadingLocation = false;
      });
      _reverseGeocode(LatLng(position.latitude, position.longitude));
    } catch (e) {
      if (mounted) setState(() { _geoError = true; _loadingLocation = false; });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}';
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'GigsCourt/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['display_name'] != null) _addressController.text = data['display_name'];
      }
    } catch (_) {}
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    HapticFeedback.selectionClick();
    setState(() { _currentPosition = point; _lat = point.latitude; _lng = point.longitude; });
    _reverseGeocode(point);
  }

  void _handleContinue() {
    final address = _addressController.text.trim();
    if (address.isEmpty) { setState(() => _error = 'Please enter your workspace address.'); return; }
    if (_lat == null || _lng == null) { setState(() => _error = 'Please set your workspace location.'); return; }
    widget.onNext({'workspaceLat': _lat, 'workspaceLng': _lng, 'workspaceAddress': address});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () { HapticFeedback.lightImpact(); widget.onBack(); },
          icon: const Icon(Icons.arrow_back_ios, size: 14), label: const Text('Back', style: TextStyle(fontSize: 14)),
          style: TextButton.styleFrom(foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73), padding: EdgeInsets.zero),
        )),
        const SizedBox(height: 16),
        Text('Where do you work?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A), letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('Set your workspace location so clients can find you.', style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73))),
        const SizedBox(height: 24),
        // Real map
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
          child: _loadingLocation
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B5FE3))), const SizedBox(height: 12), Text('Getting your location...', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38))]))
              : _geoError
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_off, size: 36, color: Color(0xFFFF3B30)), const SizedBox(height: 8), const Text('Location unavailable', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 13)), const SizedBox(height: 12), ElevatedButton(onPressed: _getCurrentLocation, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B5FE3), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Try Again'))]))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _currentPosition ?? const LatLng(9.0765, 7.3986),
                          initialZoom: 15.0,
                          onTap: _onMapTapped,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.gigscourt.app',
                          ),
                          if (_currentPosition != null)
                            MarkerLayer(markers: [
                              Marker(
                                point: _currentPosition!,
                                width: 50, height: 50,
                                child: const Icon(Icons.location_pin, color: Color(0xFF3B5FE3), size: 42),
                              ),
                            ]),
                        ],
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Center(child: TextButton.icon(
          onPressed: _getCurrentLocation,
          icon: const Icon(Icons.my_location, size: 16),
          label: const Text('Use My Location'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B5FE3)),
        )),
        const SizedBox(height: 20),
        TextField(
          controller: _addressController, minLines: 2, maxLines: 3,
          style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'Your workspace address', hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
            filled: true, fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 6),
        Text('You can edit this to your preferred address', style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26)),
        const SizedBox(height: 24),
      ]))),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFF3B30).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)))]))),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 20), child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () { HapticFeedback.lightImpact(); widget.onBack(); }, style: OutlinedButton.styleFrom(foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A), side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFE5E5EA)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: _handleContinue, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B5FE3), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
      ])),
    ]);
  }
}
