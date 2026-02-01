import 'package:flutter/painting.dart';

abstract class AppSpacing {
  static const double bubbleMarginH = 12;
  static const double bubbleMarginV = 4;
  static const double bubblePaddingH = 14;
  static const double bubblePaddingV = 10;
  static const double bubbleRadius = 16;
  static const double cardRadius = 12;
  static const double codeRadius = 8;
  static const double maxBubbleWidthFraction = 0.80;

  /// Asymmetric corners for premium chat feel.
  static const BorderRadius userBubbleBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(4),
  );
  static const BorderRadius assistantBubbleBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(18),
  );
}
