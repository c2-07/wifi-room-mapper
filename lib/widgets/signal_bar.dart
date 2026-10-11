import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedRssiBar extends StatelessWidget {
  final int rssi;

  const AnimatedRssiBar({super.key, required this.rssi});

  @override
  Widget build(BuildContext context) {
    final normalized = ((rssi + 100) / 65.0).clamp(0.05, 1.0);
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.lightSignalColors;
    final color = signalColors.colorForRssi(rssi);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: normalized),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 6,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }
}

class WifiBarsIcon extends StatelessWidget {
  final int rssi;

  const WifiBarsIcon({super.key, required this.rssi});

  @override
  Widget build(BuildContext context) {
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.lightSignalColors;
    final activeColor = signalColors.colorForRssi(rssi);

    final int activeBars;
    if (rssi >= -60) {
      activeBars = 4;
    } else if (rssi >= -70) {
      activeBars = 3;
    } else if (rssi >= -80) {
      activeBars = 2;
    } else {
      activeBars = 1;
    }

    final heights = [6.0, 10.0, 14.0, 18.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final isActive = index < activeBars;
        return Container(
          margin: EdgeInsets.only(right: index < 3 ? 2.0 : 0.0),
          width: 3.5,
          height: heights[index],
          decoration: BoxDecoration(
            color: isActive ? activeColor : activeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
