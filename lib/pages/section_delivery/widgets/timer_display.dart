import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final bool started;
  final String formattedTime;

  const TimerDisplay({
    Key? key,
    required this.started,
    required this.formattedTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return started
        ? Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
