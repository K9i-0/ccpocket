import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';

Locale? _releaseErrorLocaleOverride;

@visibleForTesting
String releaseErrorMessageForLocale(Locale locale) {
  final languageCode =
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      )
      ? locale.languageCode
      : 'en';
  return lookupAppLocalizations(Locale(languageCode)).renderErrorFallback;
}

void updateReleaseErrorWidgetLocale(Locale? locale) {
  _releaseErrorLocaleOverride = locale;
}

@visibleForTesting
Widget buildReleaseErrorWidget(FlutterErrorDetails _) {
  final locale =
      _releaseErrorLocaleOverride ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return ReleaseErrorWidget(message: releaseErrorMessageForLocale(locale));
}

void installReleaseErrorWidget({bool isReleaseMode = kReleaseMode}) {
  if (!isReleaseMode) return;
  ErrorWidget.builder = buildReleaseErrorWidget;
}

class ReleaseErrorWidget extends LeafRenderObjectWidget {
  ReleaseErrorWidget({required this.message}) : super(key: UniqueKey());

  final String message;

  @override
  RenderBox createRenderObject(BuildContext context) {
    return _RenderReleaseErrorBox(message);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message));
  }
}

class _RenderReleaseErrorBox extends RenderErrorBox {
  _RenderReleaseErrorBox(super.message);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = message
      ..textDirection = TextDirection.ltr;
  }
}
