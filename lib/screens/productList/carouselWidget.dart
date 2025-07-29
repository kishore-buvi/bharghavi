import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class CarouselWidget extends StatelessWidget {
  final List<Map<String, dynamic>> carouselImages;

  CarouselWidget({required this.carouselImages});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      child: carouselImages.isNotEmpty
          ? CarouselSlider(
        options: CarouselOptions(
          height: 200,
          viewportFraction: 1.0,
          enlargeCenterPage: false,
          autoPlay: true,
          aspectRatio: 16 / 9,
          autoPlayCurve: Curves.fastOutSlowIn,
          enableInfiniteScroll: true,
          autoPlayAnimationDuration: Duration(milliseconds: 800),
        ),
        items: carouselImages.map((image) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.network(
                    image['imageUrl'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, size: 50),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      )
          : Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12.0)),
        child: Center(child: Text('No carousel images available', style: TextStyle(color: Colors.grey[600]))),
      ),
    );
  }
}