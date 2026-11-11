import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Professional Color Studio Dialog providing both an interactive 2D Color Spectrum
/// with Hue Rainbow Slider (Option 1) and a curated Academic Swatch Matrix (Option 3).
class BrandColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const BrandColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'Brand Color Studio',
  });

  /// Opens the Color Studio dialog and returns the selected [Color], or null if cancelled.
  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    String title = 'Brand Color Studio',
  }) {
    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BrandColorPickerDialog(
        initialColor: initialColor,
        title: title,
      ),
    );
  }

  @override
  State<BrandColorPickerDialog> createState() => _BrandColorPickerDialogState();
}

class _BrandColorPickerDialogState extends State<BrandColorPickerDialog> {
  late Color _selectedColor;
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  int _activeTab = 0; // 0 = Spectrum Canvas, 1 = Swatches Matrix

  // -------------------------------------------------------------
  // Curated Academic & Executive Swatches (Option 3)
  // -------------------------------------------------------------
  static const Map<String, List<Map<String, dynamic>>> _swatchCategories = {
    'Executive & Academic Blues': [
      {'name': 'Royal Navy', 'hex': '#1E3A8A', 'color': Color(0xFF1E3A8A)},
      {'name': 'Cobalt Study', 'hex': '#1D4ED8', 'color': Color(0xFF1D4ED8)},
      {'name': 'Classic Blue', 'hex': '#1565C0', 'color': Color(0xFF1565C0)},
      {'name': 'Deep Sapphire', 'hex': '#1E40AF', 'color': Color(0xFF1E40AF)},
      {'name': 'Steel Azure', 'hex': '#0284C7', 'color': Color(0xFF0284C7)},
      {'name': 'Midnight Indigo', 'hex': '#312E81', 'color': Color(0xFF312E81)},
      {'name': 'Oxford Blue', 'hex': '#0F172A', 'color': Color(0xFF0F172A)},
      {'name': 'Slate Indigo', 'hex': '#4338CA', 'color': Color(0xFF4338CA)},
    ],
    'Focus Greens & Teals': [
      {'name': 'Academic Emerald', 'hex': '#065F46', 'color': Color(0xFF065F46)},
      {'name': 'Deep Forest', 'hex': '#047857', 'color': Color(0xFF047857)},
      {'name': 'Oceanic Teal', 'hex': '#0F766E', 'color': Color(0xFF0F766E)},
      {'name': 'Rich Pine', 'hex': '#14532D', 'color': Color(0xFF14532D)},
      {'name': 'Modern Mint', 'hex': '#059669', 'color': Color(0xFF059669)},
      {'name': 'Nordic Spruce', 'hex': '#115E59', 'color': Color(0xFF115E59)},
      {'name': 'Sage Focus', 'hex': '#15803D', 'color': Color(0xFF15803D)},
      {'name': 'Dark Jade', 'hex': '#064E3B', 'color': Color(0xFF064E3B)},
    ],
    'Warm Earth & Terracotta': [
      {'name': 'Warm Terracotta', 'hex': '#C2410C', 'color': Color(0xFFC2410C)},
      {'name': 'Burnt Sienna', 'hex': '#EA580C', 'color': Color(0xFFEA580C)},
      {'name': 'Rustic Amber', 'hex': '#B45309', 'color': Color(0xFFB45309)},
      {'name': 'Cozy Chocolate', 'hex': '#5D4037', 'color': Color(0xFF5D4037)},
      {'name': 'Warm Espresso', 'hex': '#3E2723', 'color': Color(0xFF3E2723)},
      {'name': 'Leather Brown', 'hex': '#78350F', 'color': Color(0xFF78350F)},
      {'name': 'Ochre Gold', 'hex': '#D97706', 'color': Color(0xFFD97706)},
      {'name': 'Copper Clay', 'hex': '#9A3412', 'color': Color(0xFF9A3412)},
    ],
    'Regal Burgundies & Violets': [
      {'name': 'Heritage Burgundy', 'hex': '#881337', 'color': Color(0xFF881337)},
      {'name': 'University Crimson', 'hex': '#991B1B', 'color': Color(0xFF991B1B)},
      {'name': 'Royal Violet', 'hex': '#581C87', 'color': Color(0xFF581C87)},
      {'name': 'Deep Plum', 'hex': '#701A75', 'color': Color(0xFF701A75)},
      {'name': 'Electric Violet', 'hex': '#7C3AED', 'color': Color(0xFF7C3AED)},
      {'name': 'Wine Mulberry', 'hex': '#831843', 'color': Color(0xFF831843)},
      {'name': 'Ruby Red', 'hex': '#B91C1C', 'color': Color(0xFFB91C1C)},
      {'name': 'Imperial Purple', 'hex': '#4C1D95', 'color': Color(0xFF4C1D95)},
    ],
    'Modern Slate & Monochromes': [
      {'name': 'Obsidian Noir', 'hex': '#0B0F19', 'color': Color(0xFF0B0F19)},
      {'name': 'Charcoal Slate', 'hex': '#1E293B', 'color': Color(0xFF1E293B)},
      {'name': 'Cool Graphite', 'hex': '#334155', 'color': Color(0xFF334155)},
      {'name': 'Modern Neutral', 'hex': '#475569', 'color': Color(0xFF475569)},
      {'name': 'Ash Pewter', 'hex': '#64748B', 'color': Color(0xFF64748B)},
      {'name': 'Deep Onyx', 'hex': '#18181B', 'color': Color(0xFF18181B)},
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hsvColor = HSVColor.fromColor(_selectedColor);
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _updateFromHsv(HSVColor newHsv) {
    setState(() {
      _hsvColor = newHsv;
      _selectedColor = newHsv.toColor();
      _hexController.text = _colorToHex(_selectedColor);
    });
  }

  void _updateFromColor(Color newColor) {
    setState(() {
      _selectedColor = newColor;
      _hsvColor = HSVColor.fromColor(newColor);
      _hexController.text = _colorToHex(newColor);
    });
  }

  void _onHexSubmitted(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) {
        _updateFromColor(Color(parsed));
      }
    }
  }

  void _copyHexToClipboard() {
    Clipboard.setData(ClipboardData(text: _colorToHex(_selectedColor)));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_colorToHex(_selectedColor)} to clipboard!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isColorDark = ThemeData.estimateBrightnessForColor(_selectedColor) == Brightness.dark;
    final onColorTextColor = isColorDark ? Colors.white : Colors.black87;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Title & Close Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette_rounded, color: _selectedColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Drag spectrum or select from curated swatches',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. High-Fidelity Real-Time Color Preview Banner
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                _colorToHex(_selectedColor),
                                style: TextStyle(
                                  color: onColorTextColor,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _copyHexToClipboard,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: onColorTextColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'RGB(${_selectedColor.r.toInt()}, ${_selectedColor.g.toInt()}, ${_selectedColor.b.toInt()}) • Brand Accent',
                            style: TextStyle(
                              color: onColorTextColor.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: onColorTextColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: onColorTextColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Live Preview',
                        style: TextStyle(
                          color: onColorTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Segmented Navigation (Spectrum vs Swatches)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeTab = 0);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 0
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gradient_rounded,
                                size: 16,
                                color: _activeTab == 0 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Spectrum Canvas',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 0 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeTab = 1);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 1
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 16,
                                color: _activeTab == 1 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Swatch Matrix',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 1 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Tab Content: Spectrum Canvas vs Swatch Matrix
              if (_activeTab == 0) ...[
                _buildSpectrumTab(theme, isDark),
              ] else ...[
                _buildSwatchesTab(theme, isDark),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // 5. Direct Hex Code Sync Field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        labelText: 'Brand Hex Code',
                        hintText: '#C2410C',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_rounded, size: 18),
                          tooltip: 'Apply Typed Hex',
                          onPressed: () => _onHexSubmitted(_hexController.text),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _onHexSubmitted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6. Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedColor,
                      foregroundColor: onColorTextColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selectedColor),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Select Color', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: 2D SPECTRUM CANVAS & RAINBOW HUE SLIDER (Option 1)
  // -------------------------------------------------------------
  Widget _buildSpectrumTab(ThemeData theme, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        const double canvasHeight = 160.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2D Saturation / Value Canvas
            GestureDetector(
              onPanDown: (details) => _handleSpectrumTouch(details.localPosition, canvasWidth, canvasHeight),
              onPanUpdate: (details) => _handleSpectrumTouch(details.localPosition, canvasWidth, canvasHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: Stack(
                    children: [
                      // Base Hue
                      Positioned.fill(
                        child: Container(
                          color: HSVColor.fromAHSV(1.0, _hsvColor.hue, 1.0, 1.0).toColor(),
                        ),
                      ),
                      // Saturation (White to Transparent from left to right)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.white, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Value / Brightness (Transparent to Black from top to bottom)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                      ),
                      // Draggable Target Ring / Thumb
                      Positioned(
                        left: (_hsvColor.saturation * canvasWidth - 12).clamp(0.0, canvasWidth - 24),
                        top: ((1.0 - _hsvColor.value) * canvasHeight - 12).clamp(0.0, canvasHeight - 24),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedColor,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Rainbow Hue Slider (0° to 360°)
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, hueConstraints) {
                      final sliderWidth = hueConstraints.maxWidth;
                      const sliderHeight = 22.0;

                      return GestureDetector(
                        onPanDown: (details) => _handleHueTouch(details.localPosition.dx, sliderWidth),
                        onPanUpdate: (details) => _handleHueTouch(details.localPosition.dx, sliderWidth),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              width: sliderWidth,
                              height: sliderHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF0000), // Red (0°)
                                    Color(0xFFFFFF00), // Yellow (60°)
                                    Color(0xFF00FF00), // Green (120°)
                                    Color(0xFF00FFFF), // Cyan (180°)
                                    Color(0xFF0000FF), // Blue (240°)
                                    Color(0xFFFF00FF), // Magenta (300°)
                                    Color(0xFFFF0000), // Red (360°)
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                            Positioned(
                              left: ((_hsvColor.hue / 360.0) * sliderWidth - 11).clamp(0.0, sliderWidth - 22),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HSVColor.fromAHSV(1.0, _hsvColor.hue, 1.0, 1.0).toColor(),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1.5)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Tone Intensity Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToneChip('Vibrant', 1.0, 0.95),
                  const SizedBox(width: 6),
                  _buildToneChip('Executive', 0.85, 0.75),
                  const SizedBox(width: 6),
                  _buildToneChip('Deep Tone', 0.95, 0.45),
                  const SizedBox(width: 6),
                  _buildToneChip('Muted Study', 0.50, 0.65),
                  const SizedBox(width: 6),
                  _buildToneChip('Pastel Soft', 0.35, 0.90),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToneChip(String label, double sat, double val) {
    final preview = _hsvColor.withSaturation(sat).withValue(val).toColor();
    final isSelected = (_hsvColor.saturation - sat).abs() < 0.08 && (_hsvColor.value - val).abs() < 0.08;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _updateFromHsv(_hsvColor.withSaturation(sat).withValue(val));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: preview.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _selectedColor : preview.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: preview, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: preview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSpectrumTouch(Offset pos, double width, double height) {
    final sat = (pos.dx / width).clamp(0.0, 1.0);
    final val = (1.0 - (pos.dy / height)).clamp(0.0, 1.0);
    _updateFromHsv(_hsvColor.withSaturation(sat).withValue(val));
  }

  void _handleHueTouch(double dx, double width) {
    final hue = (dx / width).clamp(0.0, 1.0) * 360.0;
    _updateFromHsv(_hsvColor.withHue(hue));
  }

  // -------------------------------------------------------------
  // TAB 2: CURATED SWATCH MATRIX (Option 3)
  // -------------------------------------------------------------
  Widget _buildSwatchesTab(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _swatchCategories.entries.map((entry) {
        final categoryTitle = entry.key;
        final swatches = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
              child: Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: swatches.map((item) {
                final color = item['color'] as Color;
                final name = item['name'] as String;
                final hex = item['hex'] as String;
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();

                return Tooltip(
                  message: '$name ($hex)',
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _updateFromColor(color);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black12,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
          ],
        );
      }).toList(),
    );
  }
}
