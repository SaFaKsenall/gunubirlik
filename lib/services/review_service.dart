import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:myapp/model/job_and_rivevws.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch reviews for a specific user
  Future<List<Review>?> fetchReviews(String userId) async {
    try {
      final reviewSnapshot = await _firestore
          .collection('reviews')
          .where('employerId', isEqualTo: userId)
          .get();

      return reviewSnapshot.docs
          .map((doc) => Review.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Değerlendirme verileri çekme hatası: $e');
      return null;
    }
  }

  // Calculate average rating
  double calculateAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) {
      return 0.0;
    }

    double totalRating = reviews.fold(0, (sum, review) => sum + review.rating);
    return totalRating / reviews.length;
  }

  // Add a review
  Future<void> addReview(BuildContext context, String employerId) async {
    if (FirebaseAuth.instance.currentUser!.uid == employerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kendi profilinize değerlendirme ekleyemezsiniz')),
      );
      return;
    }

    try {
      QuerySnapshot existingReviewSnapshot = await _firestore
          .collection('reviews')
          .where('employerId', isEqualTo: employerId)
          .where('reviewerId',
              isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (existingReviewSnapshot.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bu kullanıcıya zaten değerlendirme yaptınız')),
          );
        }
        return;
      }

      double rating = 0;
      final reviewController = TextEditingController();
      bool isSubmitting = false;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'İş Değerlendirmesi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      RatingBar.builder(
                        initialRating: rating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (newRating) {
                          setModalState(() {
                            rating = newRating;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: reviewController,
                        decoration: const InputDecoration(
                          labelText: 'Yorumunuz',
                          border: OutlineInputBorder(),
                          hintText: 'Deneyiminizi paylaşın...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (rating == 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Lütfen bir puan verin')),
                                    );
                                    return;
                                  }
                                  if (reviewController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Lütfen bir yorum yazın')),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  try {
                                    DocumentSnapshot currentUserDoc =
                                        await _firestore
                                            .collection('users')
                                            .doc(FirebaseAuth
                                                .instance.currentUser!.uid)
                                            .get();

                                    String reviewerUsername =
                                        (currentUserDoc.data() as Map<String,
                                                dynamic>)['username'] ??
                                            'Anonim Kullanıcı';

                                    await _firestore
                                        .collection('reviews')
                                        .add({
                                      'employerId': employerId,
                                      'reviewerId': FirebaseAuth
                                          .instance.currentUser!.uid,
                                      'reviewerUsername': reviewerUsername,
                                      'rating': rating,
                                      'comment': reviewController.text,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Değerlendirmeniz başarıyla eklendi')),
                                      );
                                    }
                                  } catch (e) {
                                    print('Değerlendirme ekleme hatası: $e');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Değerlendirme eklenirken hata oluştu: $e')),
                                      );
                                    }
                                  } finally {
                                    setModalState(() {
                                      isSubmitting = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.blue,
                          ),
                          child: Text(
                            isSubmitting
                                ? 'Gönderiliyor...'
                                : 'Değerlendirmeyi Gönder',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Değerlendirme dialog hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    }
  }
} 