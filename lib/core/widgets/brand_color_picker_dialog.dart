import 'package:flutter/material.dart';

class BrandColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const BrandColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'Select Brand Theme Color',
  });

  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    String title = 'Select Brand Theme Color',
  }) {
    return showDialog<Color>(
      context: context,
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
  late TextEditingController _hexController;

  static const List<Map<String, dynamic>> _presetPalettes = [
    {'name': 'Crimson', 'color': Color(0xFF881337)},
    {'name': 'Royal Navy', 'color': Color(0xFF1E3A8A)},
    {'name': 'Emerald', 'color': Color(0xFF065F46)},
    {'name': 'Dark Slate', 'color': Color(0xFF1E293B)},
    {'name': 'Warm Amber', 'color': Color(0xFF78350F)},
    {'name': 'Deep Violet', 'color': Color(0xFF4C1D95)},
    {'name': 'Ruby Red', 'color': Color(0xFF991B1B)},
    {'name': 'Ocean Teal', 'color': Color(0xFF0F766E)},
    {'name': 'Bronze Gold', 'color': Color(0xFFB45309)},
    {'name': 'Classic Blue', 'color': Color(0xFF1565C0)},
    {'name': 'Midnight', 'color': Color(0xFF312E81)},
    {'name': 'Espresso', 'color': Color(0xFF3E2723)},
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  void _onHexSubmitted(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) {
        setState(() {
          _selectedColor = Color(parsed);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.palette_rounded, color: _selectedColor),
          const SizedBox(width: 10),
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Swatch
            Container(
              height: 56,
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
              alignment: Alignment.center,
              child: Text(
                '#${_colorToHex(_selectedColor)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Hex Input Field
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: 'Custom Hex Code',
                prefixText: '# ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_rounded),
                  color: _selectedColor,
                  onPressed: () => _onHexSubmitted(_hexController.text),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: _onHexSubmitted,
            ),
            const SizedBox(height: 18),

            // Palette Swatches
            Text(
              'Curated Brand Palettes',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetPalettes.map((item) {
                final color = item['color'] as Color;
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _hexController.text = _colorToHex(color);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.black12,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          icon: const Icon(Icons.colorize_rounded, size: 18),
          label: const Text('Apply Color'),
        ),
      ],
    );
  }
}
