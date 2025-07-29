  import 'dart:io';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:flutter/material.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:permission_handler/permission_handler.dart';
  import 'package:device_info_plus/device_info_plus.dart';
  import 'package:carousel_slider/carousel_slider.dart';

  // Custom Curved Bottom Navigation Bar
  class CurvedBottomNavigationBar extends StatelessWidget {
    final int currentIndex;
    final Function(int) onTap;
    final List<IconData> icons;
    final Color backgroundColor;
    final Color selectedColor;
    final Color unselectedColor;

    const CurvedBottomNavigationBar({
      Key? key,
      required this.currentIndex,
      required this.onTap,
      required this.icons,
      this.backgroundColor = const Color(0xFF2E7D32), // Green[800]
      this.selectedColor = Colors.amber,
      this.unselectedColor = Colors.white,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        height: 80,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 80),
              painter: BottomNavPainter(
                backgroundColor: backgroundColor,
                currentIndex: currentIndex,
                itemCount: icons.length,
              ),
            ),
            Container(
              height: 80,
              child: Row(
                children: icons.asMap().entries.map((entry) {
                  int index = entry.key;
                  IconData icon = entry.value;
                  bool isSelected = index == currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              transform: Matrix4.translationValues(
                                  0,
                                  isSelected ? -20 : 0,
                                  0
                              ),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected ? selectedColor : Colors.transparent,
                                  shape: BoxShape.circle,
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: selectedColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ] : null,
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected ? backgroundColor : unselectedColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }
  }

  class BottomNavPainter extends CustomPainter {
    final Color backgroundColor;
    final int currentIndex;
    final int itemCount;

    BottomNavPainter({
      required this.backgroundColor,
      required this.currentIndex,
      required this.itemCount,
    });

    @override
    void paint(Canvas canvas, Size size) {
      Paint paint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;

      Path path = Path();

      double itemWidth = size.width / itemCount;
      double selectedItemCenter = (currentIndex + 0.5) * itemWidth;

      // Start from bottom left
      path.moveTo(0, size.height);

      // Top left corner with radius
      path.lineTo(0, 24);
      path.quadraticBezierTo(0, 0, 24, 0);

      // Create the curve for the selected item
      double curveStart = selectedItemCenter - 40;
      double curveEnd = selectedItemCenter + 40;

      // Ensure curve doesn't go out of bounds
      curveStart = curveStart.clamp(24.0, size.width - 80);
      curveEnd = curveEnd.clamp(80.0, size.width - 24);

      // Line to curve start
      path.lineTo(curveStart, 0);

      // Create the upward curve
      path.quadraticBezierTo(
        selectedItemCenter - 20, 0,
        selectedItemCenter - 20, 20,
      );

      path.quadraticBezierTo(
        selectedItemCenter, 30,
        selectedItemCenter + 20, 20,
      );

      path.quadraticBezierTo(
        selectedItemCenter + 20, 0,
        curveEnd, 0,
      );

      // Line to top right
      path.lineTo(size.width - 24, 0);

      // Top right corner with radius
      path.quadraticBezierTo(size.width, 0, size.width, 24);

      // Right side
      path.lineTo(size.width, size.height);

      // Close the path
      path.close();

      // Draw shadow
      canvas.drawShadow(path, Colors.black.withOpacity(0.2), 10, false);

      // Draw the main shape
      canvas.drawPath(path, paint);
    }

    @override
    bool shouldRepaint(covariant BottomNavPainter oldDelegate) {
      return oldDelegate.currentIndex != currentIndex ||
          oldDelegate.backgroundColor != backgroundColor;
    }
  }