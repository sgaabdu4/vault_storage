import 'package:material_ui/material_ui.dart';

class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.failure});

  final Color success;
  final Color failure;

  @override
  StatusColors copyWith({Color? success, Color? failure}) => StatusColors(
    success: switch (success) {
      final Color color => color,
      null => this.success,
    },
    failure: switch (failure) {
      final Color color => color,
      null => this.failure,
    },
  );

  @override
  StatusColors lerp(StatusColors? other, double t) => other == null || t < 1 ? this : other;
}
