import 'package:flutter/material.dart';
import '../data/dummy_properties.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import '../widgets/property_card.dart';
import '../widgets/property_detail.dart';
import '../widgets/property_map.dart';
import '../widgets/sidebar.dart';

const double _narrowBreakpoint = 900;
const double _stackedDetailBreakpoint = 1150;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Property> _properties = dummyProperties;

  Property? _popupProperty; // marker just tapped -> mini card
  Property? _detailProperty; // "View Details" pressed -> full panel

  String _query = '';
  String? _typeFilter;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Property> get _filteredProperties {
    return _properties.where((p) {
      final matchesQuery = _query.isEmpty ||
          p.name.toLowerCase().contains(_query.toLowerCase()) ||
          p.location.toLowerCase().contains(_query.toLowerCase());
      final matchesType = _typeFilter == null || p.type == _typeFilter;
      return matchesQuery && matchesType;
    }).toList();
  }

  void _onMarkerTap(Property property) {
    setState(() {
      _popupProperty = property;
    });
  }

  void _onViewDetails(Property property) {
    setState(() {
      _detailProperty = property;
      _popupProperty = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < _narrowBreakpoint;
        final bool stackDetail = constraints.maxWidth < _stackedDetailBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.surface,
          drawer: isNarrow
              ? Drawer(
                  child: Sidebar(onClose: () => Navigator.of(context).pop()),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (!isNarrow) const Sidebar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(isNarrow),
                        const SizedBox(height: 16),
                        Expanded(
                          child: stackDetail
                              ? _buildStackedLayout()
                              : _buildSideBySideLayout(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Layout variants -----------------------------------------------

  Widget _buildSideBySideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildMapWithPopup()),
        if (_detailProperty != null) const SizedBox(width: 20),
        if (_detailProperty != null)
          SizedBox(
            width: 380,
            height: double.infinity,
            child: SingleChildScrollView(
              child: PropertyDetail(
                property: _detailProperty!,
                horizontal: false,
                onClose: () => setState(() => _detailProperty = null),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStackedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildMapWithPopup()),
        if (_detailProperty != null) const SizedBox(height: 20),
        if (_detailProperty != null)
          SizedBox(
            height: 260,
            child: SingleChildScrollView(
              child: PropertyDetail(
                property: _detailProperty!,
                horizontal: true,
                onClose: () => setState(() => _detailProperty = null),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapWithPopup() {
    return Stack(
      children: [
        Positioned.fill(
          child: PropertyMap(
            properties: _filteredProperties,
            selectedProperty: _popupProperty ?? _detailProperty,
            onMarkerTap: _onMarkerTap,
          ),
        ),
        if (_popupProperty != null)
          Positioned(
            left: 24,
            top: 24,
            child: PropertyCard(
              property: _popupProperty!,
              onViewDetails: () => _onViewDetails(_popupProperty!),
              onClose: () => setState(() => _popupProperty = null),
            ),
          ),
      ],
    );
  }

  // ---- Top bar: search + filters -------------------------------------

  Widget _buildTopBar(bool isNarrow) {
    final types = _properties.map((p) => p.type).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isNarrow)
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              ),
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 19, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search properties or venues...',
                          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildIconAction(Icons.tune_rounded),
            const SizedBox(width: 8),
            _buildIconAction(Icons.notifications_none_rounded),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All Types',
                selected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              for (final type in types)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChip(
                    label: type,
                    selected: _typeFilter == type,
                    onTap: () => setState(() => _typeFilter = type),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconAction(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Icon(icon, size: 19, color: AppColors.textSecondary),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
