import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

/// English fallback also supports isolated widgets and the screenshot harness.
abstract final class MobileStrings {
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizationsEn();
}
