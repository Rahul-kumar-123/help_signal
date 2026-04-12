import 'dart:async';

import 'package:flutter/material.dart';

class StatusArea extends StatelessWidget {
  const StatusArea({
    required this.totalCount,
    required this.queueCount,
    required this.statusMessage,
    required this.isScanning,
    required this.onRefresh,
    super.key,
  });

  final int totalCount;
  final int queueCount;
  final String statusMessage;
  final bool isScanning;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          BlinkingDot(isActive: totalCount > 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mesh Status',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalCount nearby node${totalCount == 1 ? '' : 's'} • '
                  '$queueCount queued alert${queueCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B403D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh mesh',
            onPressed: isScanning ? null : onRefresh,
            icon: isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 26, color: Color(0xFF5B403D)),
          ),
        ],
      ),
    );
  }
}

class BlinkingDot extends StatefulWidget {
  const BlinkingDot({required this.isActive, super.key});

  final bool isActive;

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = !_visible;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 650),
      opacity: _visible ? 1.0 : 0.35,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.isActive
              ? const Color(0xFF10B981)
              : const Color(0xFFF97316),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
