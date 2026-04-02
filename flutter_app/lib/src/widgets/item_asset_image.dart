import 'package:flutter/material.dart';

import '../data/game_models.dart';

const Map<String, String> _canonicalItemAssets = {
  'musta': 'assets/art/items/equipment_icons/musta.png',
  'caki': 'assets/art/items/equipment_icons/caki.png',
  'sopa': 'assets/art/items/equipment_icons/sopa.png',
  'pala': 'assets/art/items/equipment_icons/pala.png',
  'tabanca_9mm': 'assets/art/items/equipment_icons/tabanca_9mm.png',
  'altin_deagle': 'assets/art/items/equipment_icons/altin_deagle.png',
  'altipatlar': 'assets/art/items/equipment_icons/altipatlar.png',
  'uzi': 'assets/art/items/equipment_icons/uzi.png',
  'el_bombasi': 'assets/art/items/equipment_icons/el_bombasi.png',
  'pompali': 'assets/art/items/equipment_icons/pompali.png',
  'ak47': 'assets/art/items/equipment_icons/ak47.png',
  'c4_patlayici': 'assets/art/items/equipment_icons/c4_patlayici.png',
  'keskin_nisanci': 'assets/art/items/equipment_icons/keskin_nisanci.png',
  'roketatar': 'assets/art/items/equipment_icons/roketatar.png',
  'deri_ceket': 'assets/art/items/equipment_icons/deri_ceket.png',
  'celik_yelek': 'assets/art/items/equipment_icons/celik_yelek.png',
  'juggernaut': 'assets/art/items/equipment_icons/juggernaut.png',
  'klasik_araba_sv1': 'assets/art/items/custom_profile/eq_car.png',
};

List<String> itemAssetCandidates(ItemDef item, {String? overrideAsset}) {
  return itemAssetCandidatesById(item.id, overrideAsset ?? item.iconAsset);
}

List<String> itemAssetCandidatesById(String itemId, String primaryAsset) {
  final out = <String>[];

  void add(String value) {
    final path = value.trim();
    if (path.isEmpty || out.contains(path)) return;
    out.add(path);
  }

  add(primaryAsset);
  add(primaryAsset.replaceAll('custom_profile', 'custom-profile'));
  add(primaryAsset.replaceAll('custom-profile', 'custom_profile'));
  add(_canonicalItemAssets[itemId] ?? '');

  final canonical = _canonicalItemAssets[itemId] ?? '';
  if (canonical.isNotEmpty) {
    add(canonical.replaceAll('custom_profile', 'custom-profile'));
    add(canonical.replaceAll('custom-profile', 'custom_profile'));
  }

  return out;
}

class ItemAssetImage extends StatefulWidget {
  final List<String> candidates;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;

  const ItemAssetImage({
    super.key,
    required this.candidates,
    required this.placeholder,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<ItemAssetImage> createState() => _ItemAssetImageState();
}

class _ItemAssetImageState extends State<ItemAssetImage> {
  int _candidateIndex = 0;

  @override
  void didUpdateWidget(covariant ItemAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameList(oldWidget.candidates, widget.candidates)) {
      _candidateIndex = 0;
    }
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _tryNextCandidate() {
    if (_candidateIndex >= widget.candidates.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _candidateIndex += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) return widget.placeholder;
    return Image.asset(
      widget.candidates[_candidateIndex],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        _tryNextCandidate();
        if (_candidateIndex < widget.candidates.length - 1) {
          return const SizedBox.shrink();
        }
        return widget.placeholder;
      },
    );
  }
}
