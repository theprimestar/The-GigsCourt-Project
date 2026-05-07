import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/supabase_service.dart';
import '../services/imagekit_service.dart';
import '../services/firestore_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 1;
  final Map<String, dynamic> _data = {};
  final SupabaseService _supabaseService = SupabaseService();
  final ImageKitService _imageKitService = ImageKitService();
  final FirestoreService _firestoreService = FirestoreService();

  void _nextStep(Map<String, dynamic> stepData) {
    setState(() {
      _data.addAll(stepData);
      if (_currentStep < 4) {
        HapticFeedback.mediumImpact();
        _currentStep++;
      } else {
        HapticFeedback.heavyImpact();
        _finishOnboarding();
      }
    });
  }

  void _previousStep() {
    if (_currentStep > 1) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestoreService.saveProfile(
        userId: user.uid,
        fullName: _data['fullName'] ?? '',
        services: List<String>.from(_data['services'] ?? []),
        bio: _data['bio'] ?? '',
        phone: _data['phone'] ?? '',
        profilePicUrl: _data['profilePicUrl'],
        workPhotos: _data['workPhotos'] != null
            ? List<String>.from(_data['workPhotos'])
            : null,
      );

      await _supabaseService.saveProfileLocation(
        userId: user.uid,
        lat: _data['workspaceLat'] ?? 0.0,
        lng: _data['workspaceLng'] ?? 0.0,
        address: _data['workspaceAddress'] ?? '',
      );

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kDebugMode ? e.toString() : 'Something went wrong. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F6F4),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i + 1 <= _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF3B5FE3)
                          : (isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 1:
        return _StepNameServices(
          key: const ValueKey('step1'),
          initialData: _data,
          supabaseService: _supabaseService,
          onNext: _nextStep,
        );
      case 2:
        return _StepLocation(
          key: const ValueKey('step2'),
          initialData: _data,
          supabaseService: _supabaseService,
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 3:
        return _StepPhotoBio(
          key: const ValueKey('step3'),
          initialData: _data,
          imageKitService: _imageKitService,
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 4:
        return _StepWalkthrough(
          key: const ValueKey('step4'),
          initialData: _data,
          onNext: _nextStep,
          onBack: _previousStep,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────
// STEP 1: Name + Services
// ─────────────────────────────────────
class _StepNameServices extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final SupabaseService supabaseService;
  final Function(Map<String, dynamic>) onNext;

  const _StepNameServices({
    super.key,
    required this.initialData,
    required this.supabaseService,
    required this.onNext,
  });

  @override
  State<_StepNameServices> createState() => _StepNameServicesState();
}

class _StepNameServicesState extends State<_StepNameServices> {
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
        setState(() {
          _allServices = services;
          _loading = false;
        });
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
      if (_selectedSlugs.contains(slug)) {
        _selectedSlugs.remove(slug);
      } else {
        _selectedSlugs.add(slug);
      }
    });
  }

  Future<void> _requestCustomService() async {
    final name = _customController.text.trim();
    if (name.isEmpty) return;

    HapticFeedback.mediumImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await widget.supabaseService.requestCustomService(
        userId: user.uid,
        serviceName: name,
      );
      final slug = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      setState(() {
        _selectedSlugs.add(slug);
        _customController.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = kDebugMode ? e.toString() : 'Failed to add service.');
      }
    }
  }

  void _handleContinue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (_selectedSlugs.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Please select at least one service.');
      return;
    }
    widget.onNext({
      'fullName': name,
      'services': _selectedSlugs,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final searchQuery = _searchController.text.toLowerCase();
    final filtered = _allServices
        .where((s) => (s['name'] as String).toLowerCase().contains(searchQuery))
        .toList();

    // Group by category (sorted alphabetically)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in filtered) {
      final cat = s['category'] as String;
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(s);
    }
    final sortedCategories = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Back', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This helps clients find you',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 28),
                // Name input
                TextField(
                  controller: _nameController,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. John Doe or JD Barbing',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 28),
                // Services section
                if (_selectedSlugs.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedSlugs.map((slug) {
                      return GestureDetector(
                        onTap: () => _toggleService(slug),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B5FE3),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B5FE3).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slug.replaceAll('-', ' '),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.close, size: 14, color: Colors.white70),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                // Search
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                // Services by category
                if (_loading)
                  ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(4, (j) => Container(
                            width: [80.0, 100.0, 70.0, 90.0][j],
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black12,
                              borderRadius: BorderRadius.circular(17),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ))
                else if (sortedCategories.isEmpty && searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No services found',
                        style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 15),
                      ),
                    ),
                  )
                else
                  ...sortedCategories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: grouped[cat]!.map((s) {
                              final slug = s['slug'] as String;
                              final selected = _selectedSlugs.contains(slug);
                              return GestureDetector(
                                onTap: () => _toggleService(slug),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF3B5FE3)
                                        : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF3B5FE3)
                                          : (isDark ? Colors.white12 : const Color(0xFFE5E5EA)),
                                      width: selected ? 0 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF3B5FE3).withOpacity(0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    s['name'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? Colors.white
                                          : (isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                // Custom service
                const SizedBox(height: 4),
                Text(
                  "Can't find your service?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Type your service...',
                          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B5FE3).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _requestCustomService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B5FE3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your request will be reviewed by our team.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Error + Continue
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _handleContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B5FE3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────
// STEP 2: Workspace Location
// ─────────────────────────────────────
class _StepLocation extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final SupabaseService supabaseService;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const _StepLocation({
    super.key,
    required this.initialData,
    required this.supabaseService,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends State<_StepLocation> {
  final _addressController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _loadingLocation = true;
  bool _geoError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialData['workspaceAddress'] ?? '';
    _lat = widget.initialData['workspaceLat'];
    _lng = widget.initialData['workspaceLng'];
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() { _loadingLocation = true; _geoError = false; });

    try {
      // For MVP, we set a default location (Abuja) since location permissions
      // on unsigned apps can be tricky. Users can still edit the address manually.
      setState(() {
        _lat = 9.0765;
        _lng = 7.3986;
        _addressController.text = 'Abuja, Nigeria';
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _geoError = true;
        _loadingLocation = false;
      });
    }
  }

  void _handleContinue() {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter your workspace address.');
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _error = 'Please enable location access to continue.');
      return;
    }
    widget.onNext({
      'workspaceLat': _lat,
      'workspaceLng': _lng,
      'workspaceAddress': address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onBack();
                    },
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Back', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Where do you work?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set your workspace location so clients can find you.',
                  style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73)),
                ),
                const SizedBox(height: 24),
                // Map placeholder
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE8E8ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 48,
                            color: _loadingLocation
                                ? (isDark ? Colors.white24 : Colors.black26)
                                : const Color(0xFF3B5FE3),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingLocation)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B5FE3)),
                            )
                          else
                            Text(
                              _geoError ? 'Location unavailable' : 'Location set',
                              style: TextStyle(
                                fontSize: 13,
                                color: _geoError
                                    ? const Color(0xFFFF3B30)
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _getCurrentLocation();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.my_location, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                                const SizedBox(width: 6),
                                Text('Use My Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Address input
                TextField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Your workspace address',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You can edit this to your preferred address',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Error
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onBack();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFE5E5EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5FE3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────
// STEP 3: Profile Picture + Bio + Phone
// ─────────────────────────────────────
class _StepPhotoBio extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final ImageKitService imageKitService;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const _StepPhotoBio({
    super.key,
    required this.initialData,
    required this.imageKitService,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_StepPhotoBio> createState() => _StepPhotoBioState();
}

class _StepPhotoBioState extends State<_StepPhotoBio> {
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _profilePicUrl;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bioController.text = widget.initialData['bio'] ?? '';
    _phoneController.text = widget.initialData['phone'] ?? '';
    _profilePicUrl = widget.initialData['profilePicUrl'];
  }

  @override
  void dispose() {
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    HapticFeedback.mediumImpact();
    // For MVP, we skip actual image picking and just mark it as skipped.
    // Full implementation will use image_picker + image_cropper in Phase 3.
    setState(() => _uploading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload coming in Phase 3 — Image Picker integration')),
      );
    }
  }

  void _handleContinue() {
    if (_bioController.text.trim().isEmpty) {
      setState(() => _error = 'Please tell us about yourself.');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }
    widget.onNext({
      'bio': _bioController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profilePicUrl': _profilePicUrl,
    });
  }

  void _handleSkip() {
    widget.onNext({
      'bio': _bioController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profilePicUrl': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onBack();
                    },
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Back', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Let clients know who you are',
                  style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73)),
                ),
                const SizedBox(height: 28),
                // Profile picture
                Center(
                  child: GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE8E8ED),
                        border: Border.all(
                          color: _profilePicUrl != null ? const Color(0xFF3B5FE3) : (isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                          width: _profilePicUrl != null ? 3 : 2,
                        ),
                      ),
                      child: _uploading
                          ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B5FE3))))
                          : _profilePicUrl != null
                              ? ClipOval(child: Image.network(_profilePicUrl!, fit: BoxFit.cover))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 28, color: isDark ? Colors.white38 : Colors.black38),
                                    const SizedBox(height: 4),
                                    Text('Add Photo', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                                  ],
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _handleSkip,
                    child: Text('Skip for now', style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
                  ),
                ),
                const SizedBox(height: 24),
                // Bio
                TextField(
                  controller: _bioController,
                  minLines:                  3,
 maxLines: 5,
                  style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Describe your experience, skills, and what clients can expect...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 20),
                // Phone
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: '+234 800 000 0000',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B5FE3), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Error
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onBack();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFE5E5EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5FE3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────
// STEP 4: Walkthrough
// ─────────────────────────────────────
class _StepWalkthrough extends StatelessWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const _StepWalkthrough({
    super.key,
    required this.initialData,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    final cards = [
      {
        'icon': Icons.location_on_outlined,
        'title': 'Find Services Nearby',
        'description': 'Browse providers by distance. See their ratings, completed gigs, and active status before you reach out.',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Chat and Connect',
        'description': 'Message providers directly. Discuss your needs, ask questions, and agree on details before booking.',
      },
      {
        'icon': Icons.check_circle_outline,
        'title': 'Register Gigs, Build Trust',
        'description': 'After working with someone, register your gig. It builds your reputation and helps others find trusted providers.',
      },
      {
        'icon': Icons.star_outline,
        'title': 'Your Reputation Grows',
        'description': 'Every completed gig earns you a review. Reviews help you rank higher in search results.',
      },
    ];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onBack();
                    },
                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                    label: const Text('Back', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to GigsCourt',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your local service marketplace',
                  style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ...cards.map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B5FE3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(card['icon'] as IconData, color: const Color(0xFF3B5FE3), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card['title'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card['description'] as String,
                                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
                Text(
                  'You can update your profile anytime from Settings',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onBack();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFE5E5EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => onNext({}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5FE3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
