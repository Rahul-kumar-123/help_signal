import 'package:flutter/material.dart';

class SOSArea extends StatelessWidget {
  const SOSArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: EdgeInsets.only(top: 34.0),
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Hold to send emergency signal',
          style: TextStyle(fontSize: 16, color: const Color.fromARGB(255, 138, 138, 138), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
