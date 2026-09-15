import 'industry.dart';

/// A kind of asset that can be inspected within an [Industry].
///
/// For Home Inspection this represents the property type (High Rise or
/// Landed). Other industries will define their own asset types (e.g. a
/// vehicle model, a piece of equipment) without touching this class.
class AssetType {
  const AssetType({
    required this.id,
    required this.industry,
    required this.name,
  });

  final String id;
  final Industry industry;
  final String name;

  @override
  String toString() => 'AssetType($id, $name)';
}
