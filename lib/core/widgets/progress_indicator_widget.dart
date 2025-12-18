import 'package:flutter/material.dart';

class CustomProgressIndicatorWidget extends StatelessWidget {
  const CustomProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const Color tealGreen = Color(0xFF4db1b3); // Match login screen color
    
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
        child: Center(
          child: Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: tealGreen.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
                strokeWidth: 3.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

