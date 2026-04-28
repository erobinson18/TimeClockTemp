import 'package:flutter/material.dart';

class LogoHeader extends StatelessWidget {
  final double heightFactor;
  final EdgeInsets padding;
  final double maxHeight;
  final double minHeight;

  const LogoHeader({
    super.key,
    this.heightFactor = 0.24, // about 20% bigger than before
    this.padding = const EdgeInsets.only(top: 10, left: 12, right: 12),
    this.maxHeight = 290,
    this.minHeight = 96,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final desired = h * heightFactor;
    final logoHeight = desired.clamp(minHeight, maxHeight);

    return Padding(
      padding: padding,
      child: Center(
        child: Image.asset(
          'assets/images/the_systems_group_logo.png',
          height: logoHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}