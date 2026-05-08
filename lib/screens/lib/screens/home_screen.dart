import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import '../services/firestore_service.dart';
import '../services/imagekit_service.dart';
import '../widgets/provider_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImageKitService _imageKitService = ImageKitService();

  List<Map<String, dynamic>> _topProviders = [];
  List<Map<String, dynamic>> _allProviders = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  double? _viewerLat, _viewerLng;
  String? _error;
  bool _scrolled = false;
  bool _showScrollTop = false;
  int _discoverScrollIndex = 0;

  double? _topCursorDistance;
  String? _topCursorId;
  double? _allCursorDistance;
  String? _allCursorId;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initLocation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _viewerLat = position.latitude;
      _viewerLng = position.longitude;
    } catch (_) {
      _viewerLat = 9.0765;
      _viewerLng = 7.3986;
    }
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (_viewerLat == null || _viewerLng == null) return;

    setState(() => _loading = true);

    try {
      final topResults = await _supabaseService.getTopNearbyProviders(
        viewerLat: _viewerLat!,
        viewerLng: _viewerLng!,
      );

      final allResults = await _supabaseService.getNearbyProfiles(
        viewerLat: _viewerLat!,
        viewerLng: _viewerLng!,
      );

      final topIds = topResults.map((r) => r['id'] as String).toList();
      final allIds = allResults.map((r) => r['id'] as String).toList();
      final allUniqueIds = {...topIds, ...allIds}.toList();

      final profiles = await _firestoreService.getProfilesByIds(allUniqueIds);
      final profileMap = {for (final p in profiles) p['id'] as String: p};

      final enrichedTop = topResults.map((r) {
        final profile = profileMap[r['id']] ?? {};
        return {
          ...profile,
          'distance_meters': r['distance_meters'],
          'workspace_address': r['workspace_address'] ?? profile['workspace_address'] ?? '',
        };
      }).toList();

      final enrichedAll = allResults.map((r) {
        final profile = profileMap[r['id']] ?? {};
        return {
          ...profile,
          'distance_meters': r['distance_meters'],
          'workspace_address': r['workspace_address'] ?? profile['workspace_address'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _topProviders = enrichedTop;
          _allProviders = enrichedAll;
          _loading = false;
          if (allResults.isNotEmpty) {
            final last = allResults.last;
            _allCursorDistance = last['distance_meters'];
            _allCursorId = last['id'];
          }
          _hasMore = allResults.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _viewerLat == null || _viewerLng == null) return;

    setState(() => _loadingMore = true);

    try {
      final results = await _supabaseService.getNearbyProfiles(
        viewerLat: _viewerLat!,
        viewerLng: _viewerLng!,
        cursorDistance: _allCursorDistance,
        cursorId: _allCursorId,
      );

      if (results.isEmpty) {
        _hasMore = false;
      } else {
        final ids = results.map((r) => r['id'] as String).toList();
        final profiles = await _firestoreService.getProfilesByIds(ids);
        final profileMap = {for (final p in profiles) p['id'] as String: p};

        final enriched = results.map((r) {
          final profile = profileMap[r['id']] ?? {};
          return {
            ...profile,
            'distance_meters': r['distance_meters'],
            'workspace_address': r['workspace_address'] ?? profile['workspace_address'] ?? '',
          };
        }).toList();

        final last = results.last;
        _allCursorDistance = last['distance_meters'];
        _allCursorId = last['id'];
        _hasMore = results.length >= 20;

        setState(() => _allProviders.addAll(enriched));
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingMore = false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    setState(() {
      _scrolled = offset > 20;
      _showScrollTop = offset > 500;
    });

    if (offset >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _formatDistance(dynamic meters) {
    if (meters == null) return '';
    final m = meters is double ? meters : meters.toDouble();
    if (m < 1000) return '${m.round()}m away';
    return '${(m / 1000).toStringAsFixed(1)}km away';
  }

  void _showProviderSheet(Map<String, dynamic> provider) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderDetailSheet(
        provider: provider,
        imageKitService: _imageKitService,
        onMessage: () {
          Navigator.pop(context);
          // Navigate to chat — Phase 5
        },
        onViewProfile: () {
          Navigator.pop(context);
          // Navigate to profile — Phase 7
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    if (_loading) {
      return _buildSkeleton(isDark);
    }

    if (_allProviders.isEmpty && _topProviders.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F6F4),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(isDark),
              ),
              // Top Providers
              if (_topProviders.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildDiscoverSection(isDark),
                ),
              // All Providers
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('All Providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A))),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildProviderCard(_allProviders[index], isDark),
                    childCount: _allProviders.length,
                  ),
                ),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B5FE3)))),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          // Scroll to top
          if (_showScrollTop)
            Positioned(
              bottom: 80,
              right: 16,
              child: GestureDetector(
                onTap: _scrollToTop,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E5EA)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF3B5FE3)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset('assets/logo.svg', width: 32, height: 32, colorFilter: ColorFilter.mode(isDark ? Colors.white : const Color(0xFF1A1A1A), BlendMode.srcIn)),
              const SizedBox(height: 2),
              SvgPicture.asset('assets/gigscourt-text.svg', width: 80, height: 14, colorFilter: ColorFilter.mode(isDark ? Colors.white : const Color(0xFF1A1A1A), BlendMode.srcIn)),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Top Providers Near You', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('Active and trusted providers close to you', style: TextStyle(fontSize: 14, color: Color(0xFF6E6E73))),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _topProviders.length,
            itemBuilder: (context, index) => _buildDiscoverCard(_topProviders[index], isDark),
          ),
        ),
        if (_topProviders.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_topProviders.length, (i) => Container(
                width: i == _discoverScrollIndex ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == _discoverScrollIndex ? const Color(0xFF3B5FE3) : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoverCard(Map<String, dynamic> provider, bool isDark) {
    return GestureDetector(
      onTap: () => _showProviderSheet(provider),
      child: Container(
        width: 264,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: provider['profile_pic_url'] != null
                  ? Image.network(_imageKitService.getOptimizedUrl(provider['profile_pic_url'], width: 600), width: 264, height: 160, fit: BoxFit.cover)
                  : Container(width: 264, height: 160, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED), child: Icon(Icons.person, size: 48, color: isDark ? Colors.white24 : Colors.black26)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (provider['is_active'] == true) ...[
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(child: Text(provider['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_formatDistance(provider['distance_meters']), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, bool isDark) {
    return GestureDetector(
      onTap: () => _showProviderSheet(provider),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: provider['profile_pic_url'] != null
                  ? Image.network(_imageKitService.getOptimizedUrl(provider['profile_pic_url'], width: 600), width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                  : Container(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED), child: Icon(Icons.person, size: 40, color: isDark ? Colors.white24 : Colors.black26)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (provider['is_active'] == true) ...[
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(child: Text(provider['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_formatDistance(provider['distance_meters']), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (provider['services'] != null && (provider['services'] as List).isNotEmpty)
                      Text(
                        (provider['services'] as List).take(2).map((s) => s.toString().replaceAll('-', ' ')).join(', '),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F6F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonHeader(isDark),
              const SizedBox(height: 24),
              _buildSkeletonDiscover(isDark),
              const SizedBox(height: 24),
              _buildSkeletonGrid(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 6),
            Container(width: 80, height: 14, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(7))),
          ],
        ),
        Container(width: 36, height: 36, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle)),
      ],
    );
  }

  Widget _buildSkeletonDiscover(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 180, height: 20, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (_, __) => Container(width: 264, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 140, height: 20, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.75),
          itemCount: 6,
          itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(16))),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F6F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/logo.svg', width: 48, height: 48, colorFilter: ColorFilter.mode(isDark ? Colors.white38 : Colors.black38, BlendMode.srcIn)),
              const SizedBox(height: 24),
              Text('No providers nearby yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A)), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('You can be the first to offer your service in this area', style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73)), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
