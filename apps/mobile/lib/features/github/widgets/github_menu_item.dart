import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'github_mark_icon.dart';

/// Value of [gitHubSessionMenuItem] in a chat's overflow menu.
const gitHubSessionMenuValue = 'github';

/// "Issues / PRs" entry of a chat's overflow menu.
///
/// Unlike the entry centered in an empty chat, it stays available after the
/// first message, so an Issue or a PR can be attached at any point. Open the
/// screen with `openGitHubScreenForSession` when it is selected.
PopupMenuItem<String> gitHubSessionMenuItem(BuildContext context) {
  return PopupMenuItem(
    key: const ValueKey('menu_github'),
    value: gitHubSessionMenuValue,
    child: ListTile(
      leading: const GitHubMarkIcon(size: 20),
      title: Text(AppLocalizations.of(context).githubIssuesAndPrs),
      dense: true,
      contentPadding: EdgeInsets.zero,
    ),
  );
}
