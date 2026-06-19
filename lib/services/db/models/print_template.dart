enum PrintTemplate {
  chifa,
  eph,
}

extension PrintTemplateExtension on PrintTemplate {
  String get assetPath {
    switch (this) {
      case PrintTemplate.chifa:
        return 'assets/images/ordonnance.jpg';
      case PrintTemplate.eph:
        return 'assets/images/ORD_DEM.jpg';
    }
  }

  String get label {
    switch (this) {
      case PrintTemplate.chifa:
        return 'CHIFA';
      case PrintTemplate.eph:
        return 'EPH';
    }
  }
}
