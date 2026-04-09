import 'package:flutter/material.dart';

class StatusArea extends StatelessWidget {
  final int totalCount;

  const StatusArea({super.key, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Mesh Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        leading: BlinkingDot(),
        subtitle: Text(
          '$totalCount devices in range',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5B403D),
          ),
        ),
        trailing: GestureDetector(
          child: Icon(Icons.refresh, size: 26, color: Color(0xFF5B403D)),
          onTap: () {
            
          },
        ),
      ),
    );
  }
}


class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});
  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  void _startBlinking() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 600));
      setState(() {
        _visible = !_visible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 600),
      opacity: _visible ? 1.0 : 0.4,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}


