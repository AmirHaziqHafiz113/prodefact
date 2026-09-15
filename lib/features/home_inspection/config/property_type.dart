/// The two property types supported in Phase 1 of Home Inspection.
enum PropertyType {
  highRise,
  landed;

  String get label {
    switch (this) {
      case PropertyType.highRise:
        return 'High Rise';
      case PropertyType.landed:
        return 'Landed';
    }
  }
}
