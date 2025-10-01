import 'package:flutter/material.dart';

class ResourceCard extends StatelessWidget {
  final int index;
  const ResourceCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final cardTitle = 'Resource ${index + 1}';
    final cardIcon = Icons.menu_book;

    return Container(
      width: screenWidth * 0.42,
      margin: EdgeInsets.only(right: screenWidth*0.03),
      padding: EdgeInsets.all(screenWidth*0.035),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth*0.04),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: screenWidth*0.18,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueAccent.shade100.withOpacity(0.7),
              borderRadius: BorderRadius.circular(screenWidth*0.03),
            ),
            child: Center(child: Icon(cardIcon, size: screenWidth*0.12, color: Colors.white)),
          ),
          SizedBox(height: screenWidth*0.03),
          Text(cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: screenWidth*0.045, fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: screenWidth*0.015),
          Text('This is a short description or details about the resource.', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: screenWidth*0.033, color: Colors.grey[600])),
          SizedBox(height: screenWidth*0.02),
          Row(
            children: [
              Icon(Icons.bookmark_border, size: screenWidth*0.05, color: Colors.grey),
              Spacer(),
              Icon(Icons.arrow_forward, size: screenWidth*0.05, color: Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }
}
