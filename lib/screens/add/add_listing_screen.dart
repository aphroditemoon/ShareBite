import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AddListingScreen extends StatefulWidget {
  final String preselectedCategory;
  const AddListingScreen({super.key, this.preselectedCategory = 'free_food'});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');
  final _addressCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  late String _category;
  List<File> _images = [];
  List<String> _tags = [];
  List<String> _selectedDietary = [];
  List<String> _selectedAllergens = [];
  Position? _position;
  bool _loading = false;
  DateTime? _expiresAt;
  bool _locationLoading = true;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  final _dietaryOptions = ['Halal', 'Vegan', 'Vegetarian', 'Gluten-free', 'Dairy-free', 'Organic'];
  final _allergenOptions = ['Peanuts', 'Dairy', 'Eggs', 'Gluten', 'Seafood', 'Soy'];

  @override
  void initState() {
    super.initState();
    _category = widget.preselectedCategory;
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _getLocation();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    for (var c in [_titleCtrl, _descCtrl, _priceCtrl, _qtyCtrl, _addressCtrl, _tagCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.deniedForever) {
        _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    } catch (_) {}
    if (mounted) setState(() => _locationLoading = false);
  }

  Future<void> _pickImages() async {
    HapticFeedback.lightImpact();
    final files = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty && mounted) {
      setState(() => _images = files.take(5).map((f) => File(f.path)).toList());
    }
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      HapticFeedback.selectionClick();
      setState(() { _tags.add(t); _tagCtrl.clear(); });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final lat = _position?.latitude ?? -6.2088;
      final lng = _position?.longitude ?? 106.8456;
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'price': _priceCtrl.text,
        'quantity': _qtyCtrl.text,
        'lat': lat.toString(),
        'lng': lng.toString(),
        'address': _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : (_position == null ? 'Default demo location' : 'Current location'),
        'tags': '[${_tags.map((e) => '"$e"').join(',')}]',
        'dietaryInfo': '[${_selectedDietary.map((e) => '"$e"').join(',')}]',
        'allergens': '[${_selectedAllergens.map((e) => '"$e"').join(',')}]',
        if (_expiresAt != null) 'expiresAt': _expiresAt!.toIso8601String(),
      };
      final res = await ApiService.createListing(data, _images);
      if (res['success'] == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColors[_category] ?? AppTheme.primary;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text('New listing'),
        leading: _AnimatedCloseButton(onTap: () => Navigator.pop(context)),
        backgroundColor: AppTheme.surface(context),
        foregroundColor: AppTheme.txtPrimary(context),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: SlideTransition(
        position: _entrySlide,
        child: FadeTransition(
          opacity: _entryFade,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Category ──────────────────────────────────────────────
                  _sectionLabel('Category'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: AppTheme.categoryColors.keys.map((cat) {
                        final sel = _category == cat;
                        final color = AppTheme.categoryColors[cat]!;
                        return _CategorySelectChip(
                          label: AppTheme.categoryLabels[cat] ?? cat,
                          selected: sel,
                          color: color,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _category = cat);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Photos ────────────────────────────────────────────────
                  _sectionLabel('Photos (up to 5)'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 106,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _AddPhotoButton(color: catColor, onTap: _pickImages),
                        ..._images.asMap().entries.map((e) => _PhotoThumbnail(
                          file: e.value,
                          onRemove: () => setState(() => _images.removeAt(e.key)),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────────
                  _sectionLabel('Title *'),
                  const SizedBox(height: 8),
                  _textField(_titleCtrl, 'e.g. Homemade banana bread',
                      validator: (v) => v == null || v.isEmpty ? 'Title is required' : null),
                  const SizedBox(height: 16),

                  // ── Description ───────────────────────────────────────────
                  _sectionLabel('Description'),
                  const SizedBox(height: 8),
                  _textField(_descCtrl, 'Tell people more about this item...', maxLines: 4),
                  const SizedBox(height: 16),

                  // ── Price & Quantity ──────────────────────────────────────
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel(_category == 'free_food' || _category == 'free_nonfood'
                          ? 'Price (0 = Free)' : 'Price (Rp) *'),
                      const SizedBox(height: 8),
                      _textField(_priceCtrl, '0', type: TextInputType.number,
                          validator: (v) {
                            if (_category == 'for_sale' && (v == null || v == '0')) return 'Enter a price';
                            return null;
                          }),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Quantity'),
                      const SizedBox(height: 8),
                      _textField(_qtyCtrl, '1', type: TextInputType.number),
                    ])),
                  ]),
                  const SizedBox(height: 16),

                  // ── Address ───────────────────────────────────────────────
                  _sectionLabel('Pickup address'),
                  const SizedBox(height: 8),
                  _textField(_addressCtrl, 'Street name, area, city...'),
                  const SizedBox(height: 6),
                  _LocationStatusBadge(loading: _locationLoading, hasPosition: _position != null),

                  // ── Expiry Date ────────────────────────────────────────────
                  if (_category == 'free_food' || _category == 'for_sale') ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Best before (optional)'),
                    const SizedBox(height: 8),
                    _DatePickerButton(
                      date: _expiresAt,
                      onPicked: (d) => setState(() => _expiresAt = d),
                      onClear: () => setState(() => _expiresAt = null),
                    ),
                  ],

                  // ── Tags ──────────────────────────────────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('Tags'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _tagCtrl,
                        onSubmitted: (_) => _addTag(),
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppTheme.txtPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Add a tag, press Enter',
                          hintStyle: TextStyle(fontFamily: 'Nunito', color: AppTheme.txtSecondary(context).withOpacity(0.6), fontSize: 13),
                          filled: true, fillColor: AppTheme.inputFill(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddTagButton(color: catColor, onTap: _addTag),
                  ]),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _tags.map((t) => _RemovableTag(
                        tag: t,
                        color: catColor,
                        onRemove: () => setState(() => _tags.remove(t)),
                      )).toList(),
                    ),
                  ],

                  // ── Dietary & Allergens ───────────────────────────────────
                  if (_category == 'free_food' || _category == 'for_sale') ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Dietary info'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _dietaryOptions.map((d) {
                        final sel = _selectedDietary.contains(d);
                        return _ToggleChip(
                          label: d,
                          selected: sel,
                          color: AppTheme.teal,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            setState(() => sel ? _selectedDietary.remove(d) : _selectedDietary.add(d));
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('Allergens'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _allergenOptions.map((a) {
                        final sel = _selectedAllergens.contains(a);
                        return _ToggleChip(
                          label: a,
                          selected: sel,
                          color: AppTheme.secondary,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            setState(() => sel ? _selectedAllergens.remove(a) : _selectedAllergens.add(a));
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: _PublishButton(loading: _loading, color: catColor, onTap: _submit),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context)));

  Widget _textField(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType? type, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: type,
      validator: validator,
      style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Nunito', color: AppTheme.txtSecondary(context).withOpacity(0.6), fontSize: 14),
        filled: true, fillColor: AppTheme.inputFill(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.secondary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _AnimatedCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedCloseButton({required this.onTap});
  @override State<_AnimatedCloseButton> createState() => _AnimatedCloseButtonState();
}
class _AnimatedCloseButtonState extends State<_AnimatedCloseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale,
        child: Icon(Icons.close_rounded)),
    );
  }
}

class _CategorySelectChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CategorySelectChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override State<_CategorySelectChip> createState() => _CategorySelectChipState();
}
class _CategorySelectChipState extends State<_CategorySelectChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected ? widget.color : widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.selected ? widget.color : Colors.transparent, width: 1.5),
            boxShadow: widget.selected ? [
              BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
            ] : null,
          ),
          child: Text(widget.label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.selected ? Colors.white : widget.color)),
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.color, required this.onTap});
  @override State<_AddPhotoButton> createState() => _AddPhotoButtonState();
}
class _AddPhotoButtonState extends State<_AddPhotoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 106, height: 106,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_rounded, color: widget.color, size: 28),
            const SizedBox(height: 6),
            Text('Add photos', style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                fontWeight: FontWeight.w600, color: widget.color)),
          ]),
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatefulWidget {
  final File file;
  final VoidCallback onRemove;
  const _PhotoThumbnail({required this.file, required this.onRemove});
  @override State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}
class _PhotoThumbnailState extends State<_PhotoThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Stack(
        children: [
          Container(
            width: 106, height: 106, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(image: FileImage(widget.file), fit: BoxFit.cover),
            ),
          ),
          Positioned(top: 6, right: 16,
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); widget.onRemove(); },
              child: Container(width: 24, height: 24,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 14)),
            )),
        ],
      ),
    );
  }
}

class _AddTagButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  const _AddTagButton({required this.color, required this.onTap});
  @override State<_AddTagButton> createState() => _AddTagButtonState();
}
class _AddTagButtonState extends State<_AddTagButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(width: 44, height: 44,
          decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 22)),
      ),
    );
  }
}

class _RemovableTag extends StatefulWidget {
  final String tag;
  final Color color;
  final VoidCallback onRemove;
  const _RemovableTag({required this.tag, required this.color, required this.onRemove});
  @override State<_RemovableTag> createState() => _RemovableTagState();
}
class _RemovableTagState extends State<_RemovableTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _ctrl.forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      child: InputChip(
        label: Text('#${widget.tag}',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                fontWeight: FontWeight.w600, color: widget.color)),
        onDeleted: widget.onRemove,
        backgroundColor: widget.color.withOpacity(0.08),
        deleteIconColor: widget.color,
        side: BorderSide(color: widget.color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _ToggleChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onToggle;
  const _ToggleChip({required this.label, required this.selected, required this.color, required this.onToggle});
  @override State<_ToggleChip> createState() => _ToggleChipState();
}
class _ToggleChipState extends State<_ToggleChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onToggle(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected ? widget.color : widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.selected ? widget.color : widget.color.withOpacity(0.3)),
          ),
          child: Text(widget.label,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.selected ? Colors.white : widget.color)),
        ),
      ),
    );
  }
}

class _LocationStatusBadge extends StatelessWidget {
  final bool loading;
  final bool hasPosition;
  const _LocationStatusBadge({required this.loading, required this.hasPosition});
  @override Widget build(BuildContext context) {
    final color = loading ? Colors.orange : (hasPosition ? AppTheme.green : AppTheme.secondary);
    final icon = loading ? Icons.location_searching_rounded
        : (hasPosition ? Icons.check_circle_outline_rounded : Icons.location_off_outlined);
    final label = loading ? 'Getting your GPS location...'
        : (hasPosition ? 'GPS location detected' : 'GPS unavailable — location required');
    return Row(children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(icon, key: ValueKey(icon), size: 14, color: color),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}

class _DatePickerButton extends StatefulWidget {
  final DateTime? date;
  final void Function(DateTime) onPicked;
  final VoidCallback onClear;
  const _DatePickerButton({this.date, required this.onPicked, required this.onClear});
  @override State<_DatePickerButton> createState() => _DatePickerButtonState();
}
class _DatePickerButtonState extends State<_DatePickerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) widget.onPicked(picked);
  }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.selectionClick(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); _pick(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.date != null ? AppTheme.primary.withOpacity(0.06) : AppTheme.inputFill(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.date != null ? AppTheme.primary.withOpacity(0.4) : AppTheme.divider),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18,
                color: widget.date != null ? AppTheme.primary : AppTheme.txtSecondary(context)),
            const SizedBox(width: 10),
            Text(
              widget.date == null ? 'Select a date'
                  : '${widget.date!.day}/${widget.date!.month}/${widget.date!.year}',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w500,
                  color: widget.date == null ? AppTheme.txtSecondary(context) : AppTheme.txtPrimary(context)),
            ),
            const Spacer(),
            if (widget.date != null)
              GestureDetector(
                onTap: widget.onClear,
                child: Icon(Icons.close_rounded, size: 16, color: AppTheme.txtSecondary(context)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _PublishButton extends StatefulWidget {
  final bool loading;
  final Color color;
  final VoidCallback onTap;
  const _PublishButton({required this.loading, required this.color, required this.onTap});
  @override State<_PublishButton> createState() => _PublishButtonState();
}
class _PublishButtonState extends State<_PublishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110),
        reverseDuration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) { HapticFeedback.mediumImpact(); _ctrl.forward(); },
      onTapUp: widget.loading ? null : (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: widget.loading ? null : () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.loading ? null : AppTheme.gradientFor(widget.color),
            color: widget.loading ? widget.color.withOpacity(0.5) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.loading ? null : [
              BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Publish listing',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                        fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
