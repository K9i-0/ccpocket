import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/models/app_icon.dart';
import 'package:ccpocket/services/app_icon_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAppIconGateway implements AppIconGateway {
  FakeAppIconGateway({this.currentIcon});

  final appliedIcons = <String?>[];
  String? currentIcon;

  @override
  Future<bool> supportsAlternateIcons() async => true;

  @override
  Future<String?> getCurrentIcon() async => currentIcon;

  @override
  Future<void> setIcon(String? iconId) async {
    currentIcon = iconId;
    appliedIcons.add(iconId);
  }
}

class FakeRevenueCatService extends RevenueCatService {
  FakeRevenueCatService({
    SupporterState supporterState = const SupporterState.inactive(),
  }) : super(publicApiKey: '', platform: TargetPlatform.iOS) {
    this.supporterState.value = supporterState;
  }

  void setSupporterState(SupporterState state) {
    supporterState.value = state;
  }
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit app icon sync', () {
    test('does not auto-reset icon when supporter becomes inactive', () async {
      SharedPreferences.setMockInitialValues({
        'settings_selected_app_icon': 'light_outline',
      });
      final prefs = await SharedPreferences.getInstance();
      final appIconGateway = FakeAppIconGateway();
      final revenueCat = FakeRevenueCatService();
      final cubit = SettingsCubit(
        prefs,
        revenueCatService: revenueCat,
        appIconService: AppIconService(
          gateway: appIconGateway,
          platform: TargetPlatform.iOS,
        ),
      );

      await _flushAsync();
      expect(cubit.state.selectedAppIcon, AppIconVariant.lightOutline);
      expect(appIconGateway.appliedIcons, isEmpty);

      revenueCat.setSupporterState(const SupporterState.active());
      await _flushAsync();
      expect(appIconGateway.appliedIcons.last, 'light_outline');

      revenueCat.setSupporterState(const SupporterState.inactive());
      await _flushAsync();
      expect(appIconGateway.appliedIcons.last, 'light_outline');

      await cubit.close();
    });

    test('can still reset to default from explicit selection', () async {
      SharedPreferences.setMockInitialValues({
        'settings_selected_app_icon': 'light_outline',
      });
      final prefs = await SharedPreferences.getInstance();
      final appIconGateway = FakeAppIconGateway(currentIcon: 'light_outline');
      final revenueCat = FakeRevenueCatService(
        supporterState: const SupporterState.inactive(),
      );
      final cubit = SettingsCubit(
        prefs,
        revenueCatService: revenueCat,
        appIconService: AppIconService(
          gateway: appIconGateway,
          platform: TargetPlatform.iOS,
        ),
      );

      await _flushAsync();
      await cubit.setSelectedAppIcon(AppIconVariant.defaultIcon);

      expect(cubit.state.selectedAppIcon, AppIconVariant.defaultIcon);
      expect(appIconGateway.appliedIcons.last, isNull);

      await cubit.close();
    });

    test('applies selected icon immediately for active supporters', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final appIconGateway = FakeAppIconGateway();
      final revenueCat = FakeRevenueCatService(
        supporterState: const SupporterState.active(),
      );
      final cubit = SettingsCubit(
        prefs,
        revenueCatService: revenueCat,
        appIconService: AppIconService(
          gateway: appIconGateway,
          platform: TargetPlatform.android,
        ),
      );

      await _flushAsync();
      await cubit.setSelectedAppIcon(AppIconVariant.proCopperEmerald);

      expect(cubit.state.selectedAppIcon, AppIconVariant.proCopperEmerald);
      expect(appIconGateway.appliedIcons.last, 'pro_copper_emerald');

      await cubit.close();
    });

    test(
      'does not reset to default while supporter state is still loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings_selected_app_icon': 'light_outline',
        });
        final prefs = await SharedPreferences.getInstance();
        final appIconGateway = FakeAppIconGateway(currentIcon: 'light_outline');
        final revenueCat = FakeRevenueCatService(
          supporterState: const SupporterState.loading(),
        );
        final cubit = SettingsCubit(
          prefs,
          revenueCatService: revenueCat,
          appIconService: AppIconService(
            gateway: appIconGateway,
            platform: TargetPlatform.iOS,
          ),
        );

        await _flushAsync();
        expect(appIconGateway.appliedIcons, isEmpty);

        revenueCat.setSupporterState(const SupporterState.active());
        await _flushAsync();
        expect(appIconGateway.appliedIcons, isEmpty);

        await cubit.close();
      },
    );
  });
}
