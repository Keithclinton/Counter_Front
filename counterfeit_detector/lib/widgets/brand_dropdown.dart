import 'package:flutter/material.dart';

class BrandDropdown extends StatefulWidget {
  const BrandDropdown({super.key});

  @override
  State<BrandDropdown> createState() => _BrandDropdownState();
}

class _BrandDropdownState extends State<BrandDropdown> {
  String selectedBrand = 'Black Eagle';

  final List<String> brands = ['Black Eagle', 'Tusker', 'Eagle Extra', 'Brewmaster'];

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
            }
          },
          items: brands
              .map((brand) => DropdownMenuItem(
                    value: brand,
                    child: Text(brand),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
