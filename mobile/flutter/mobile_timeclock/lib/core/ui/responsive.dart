import 'package:flutter/material.dart';

class Responsive {
  static bool isPhone(BuildContext context){
    return MediaQuery.of(context).size.width < 700;
  }

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 700 && w < 1100;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  static double scale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) return 0.75;
    if (width < 900) return 0.85;
    if (width < 1100) return 1.0;

    return 1.15;
  }

  static double maxContentWidth(BuildContext context) {
    if(isDesktop(context)) return 1200;
    if(isTablet(context)) return 900;
    return double.infinity;
  }
}