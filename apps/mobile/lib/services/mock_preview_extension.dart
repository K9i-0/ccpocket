import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../mock/mock_scenarios.dart';
import '../screens/mock_preview_screen.dart';
import 'store_screenshot_extension.dart';

void registerMockPreviewExtensions() {
  if (!kDebugMode) return;

  registerMarionetteExtension(
    name: 'ccpocket.mock.openScenario',
    description: 'Open a mock preview scenario by exact scenario name.',
    callback: (params) async {
      final scenarioName = params['scenario'];
      if (scenarioName == null || scenarioName.isEmpty) {
        return MarionetteExtensionResult.invalidParams(
          'Missing required parameter: scenario',
        );
      }

      MockScenario? scenario;
      for (final candidate in mockScenarios) {
        if (candidate.name == scenarioName) {
          scenario = candidate;
          break;
        }
      }
      if (scenario == null) {
        return MarionetteExtensionResult.error(
          1,
          'Unknown mock scenario: $scenarioName',
        );
      }

      final navState = StoreScreenshotState.navigatorKey?.currentState;
      final context = StoreScreenshotState.navigatorKey?.currentContext;
      if (navState == null || context == null) {
        return MarionetteExtensionResult.error(2, 'Navigator not available.');
      }

      final route = buildMockScenarioRoute(context, scenario);
      if (route == null) {
        return MarionetteExtensionResult.error(
          3,
          'Scenario cannot be opened through automation: $scenarioName',
        );
      }
      navState.push(route);
      return MarionetteExtensionResult.success({
        'scenario': scenarioName,
        'status': 'navigated',
      });
    },
  );
}
