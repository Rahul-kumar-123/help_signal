import 'package:flutter/material.dart';

class SOSArea extends StatelessWidget {
  const SOSArea({required this.isSending, required this.onTrigger, super.key});

  final bool isSending;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        GestureDetector(
          onLongPress: isSending ? null : onTrigger,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 208,
            width: 208,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isSending
                    ? const [Color(0xFFF97316), Color(0xFFD92D20)]
                    : const [Color(0xFFFF6B57), Color(0xFFD92D20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD92D20).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 154,
                  width: 154,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 2.5,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SOS',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSending ? 'Sending...' : 'Hold',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isSending
              ? 'Your emergency signal is being stored and broadcast.'
              : 'Press and hold to send an emergency signal.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
