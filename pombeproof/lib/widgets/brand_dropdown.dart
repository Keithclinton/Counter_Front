import 'package:flutter/material.dart';

class BrandDropdown extends StatefulWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;

  const BrandDropdown({
    super.key,
    this.value,
    this.onChanged,
  });

  @override
  State<BrandDropdown> createState() => _BrandDropdownState();
}

class _BrandDropdownState extends State<BrandDropdown> {
  late String selectedBrand;

  final List<String> brands = [
    'County',
    'Best Gin',
    'Hunters Choice',
  ];

  @override
  void initState() {
    super.initState();
    selectedBrand = widget.value ?? brands.first;
  }

  @override
  void didUpdateWidget(covariant BrandDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != selectedBrand) {
      setState(() {
        selectedBrand = widget.value!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF42A5F5), width: 1.3),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBrand,
          dropdownColor: const Color(0xFF1F1F1F),
          style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF42A5F5)),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedBrand = value;
              });
              widget.onChanged?.call(value);
            }
          },
          items: brands.map((brand) {
            return DropdownMenuItem(
              value: brand,
              child: Text(brand),
            );
          }).toList(),
        ),
      ),
    );
  }
}
