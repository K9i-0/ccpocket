import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';

class DiffBinaryNotice extends StatelessWidget {
  const DiffBinaryNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Text(
        'Binary file — diff not available',
        style: TextStyle(color: appColors.subtleText),
      ),
    );
  }
}
