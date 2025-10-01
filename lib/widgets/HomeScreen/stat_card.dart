import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title, value;
  final Color color;
  final IconData icon;

  const StatCard({super.key, required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.35,
      padding: EdgeInsets.all(screenWidth * 0.04),
      margin: EdgeInsets.only(right: screenWidth * 0.03),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.9), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(screenWidth * 0.03),
            ),
            child: Icon(icon, color: Colors.white, size: screenWidth*0.08),
          ),
          SizedBox(height: screenWidth*0.03),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: screenWidth*0.035), maxLines: 1, overflow: TextOverflow.ellipsis))),
              SizedBox(width: screenWidth*0.02),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Text(value, key: ValueKey(value), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: screenWidth*0.045)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
