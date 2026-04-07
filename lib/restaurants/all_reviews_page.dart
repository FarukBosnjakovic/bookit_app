import 'package:bookit/restaurants/restaurants_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllReviewsPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const AllReviewsPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  List<ReviewModel> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .get();
    if (mounted) {
      setState(() {
        _reviews = snap.docs.map((d) => ReviewModel.fromFirestore(d)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recenzije - ${widget.restaurantName}')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B7C45)))
          : _reviews.isEmpty
              ? const Center(child: Text('Nema recenzija.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReviewCard(review: _reviews[index]),
                    );
                  },
                ),
    );
  }
}