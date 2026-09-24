import 'package:flutter/material.dart';
import '../data/dummy_properties.dart';
import '../models/property.dart';
import '../theme/app_theme.dart';
import '../widgets/property_card.dart';
import '../widgets/property_detail.dart';
import '../widgets/property_map.dart';
import '../widgets/sidebar.dart';
import 'admin_dashboard_screen.dart';

const double _narrowBreakpoint = 900;
const double _stackedDetailBreakpoint = 1150;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Copied (not aliased) so CRUD edits don't mutate the shared
  // `dummyProperties` list itself.
  final List<Property> _properties = List<Property>.from(dummyProperties);

  Property? _popupProperty; // marker just tapped -> mini card
  Property? _detailProperty; // "View Details" pressed -> full panel

  String _query = '';
  String? _typeFilter;

  // Which sidebar menu is active. 0 = Dashboard (Eventaris only),
  // 1 = Peta Properti (map + search, the old default body).
  int _selectedMenu = 0;

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

  // ---- CRUD (in-memory for now, no backend) ---------------------------

  void _addProperty(Property property) {
    setState(() => _properties.add(property));
  }

  void _updateProperty(Property updated) {
    setState(() {
      final index = _properties.indexWhere((p) => p.id == updated.id);
      if (index != -1) _properties[index] = updated;
      if (_popupProperty?.id == updated.id) _popupProperty = updated;
      if (_detailProperty?.id == updated.id) _detailProperty = updated;
    });
  }

  void _deleteProperty(String id) {
    setState(() {
      _properties.removeWhere((p) => p.id == id);
      if (_popupProperty?.id == id) _popupProperty = null;
      if (_detailProperty?.id == id) _detailProperty = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < _narrowBreakpoint;
        final bool stackDetail = constraints.maxWidth < _stackedDetailBreakpoint;

        void selectMenu(int index) => setState(() => _selectedMenu = index);

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.surface,
          drawer: isNarrow
              ? Drawer(
                  child: Sidebar(
                    selectedIndex: _selectedMenu,
                    onSelect: selectMenu,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (!isNarrow)
                  Sidebar(selectedIndex: _selectedMenu, onSelect: selectMenu),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildMainContent(isNarrow, stackDetail),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Main content: switches based on the selected sidebar menu ------

  Widget _buildMainContent(bool isNarrow, bool stackDetail) {
    switch (_selectedMenu) {
      case 0: // Dashboard -> Eventaris only, no map.
        return AdminDashboardScreen(
          properties: _properties,
          onAdd: _addProperty,
          onUpdate: _updateProperty,
          onDelete: _deleteProperty,
        );
      case 1: // Peta Properti -> the map + search/filter UI.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(isNarrow),
            const SizedBox(height: 16),
            Expanded(
              child: stackDetail ? _buildStackedLayout() : _buildSideBySideLayout(),
            ),
          ],
        );
      default: // Events / Settings -> not built yet in this prototype.
        return const Center(
          child: Text('Menu ini belum tersedia di prototype.', style: TextStyle(color: AppColors.textSecondary)),
        );
    }
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
