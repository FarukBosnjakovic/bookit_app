import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double desktop = 1024;
}

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.mobile;
  
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.desktop;
  
  static double pagePadding(BuildContext context) =>
      isDesktop(context) ? 40.0 : 20.0;
}