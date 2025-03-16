import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:myapp/model/job_and_rivevws.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/screens/qr_payment/parayatirma.dart';
import 'package:flutter/services.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Fetch jobs for a specific user
  Future<List<Job>?> fetchJobs(String userId) async {
    try {
      print('fetchJobs çağrıldı - Kullanıcı ID: $userId');
      
      final jobSnapshot = await _firestore
          .collection('jobs')
          .where('employerId', isEqualTo: userId)
          .get();

      print('Firestore sorgusu tamamlandı - Bulunan belge sayısı: ${jobSnapshot.docs.length}');
      
      if (jobSnapshot.docs.isEmpty) {
        print('Kullanıcı için iş ilanı bulunamadı: $userId');
        return [];
      }
      
      final jobs = jobSnapshot.docs.map((doc) {
        print('İş belgesi işleniyor - ID: ${doc.id}');
        try {
          final job = Job.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
          print('İş başarıyla işlendi - İş adı: ${job.jobName}');
          return job;
        } catch (e) {
          print('İş belgesi işleme hatası - ID: ${doc.id}, Hata: $e');
          return null;
        }
      }).where((job) => job != null).cast<Job>().toList();
      
      print('Toplam işlenen iş ilanı sayısı: ${jobs.length}');
      return jobs;
    } catch (e) {
      print('İş verileri çekme hatası: $e');
      return null;
    }
  }

  // Check if user has sufficient balance for posting a job
  Future<Map<String, dynamic>> checkUserBalance(String userId, double jobPrice) async {
    try {
      // Get user balance from Firestore
      DocumentSnapshot balanceDoc = await _firestore.collection('balances').doc(userId).get();
      
      // If balance document doesn't exist, return false with 0 balance
      if (!balanceDoc.exists) {
        return {
          'hasBalance': false,
          'currentBalance': 0.0,
          'requiredBalance': jobPrice,
          'message': 'Hesabınızda yeterli bakiye bulunmamaktadır. Lütfen para yatırın.'
        };
      }
      
      // Get current balance
      double currentBalance = (balanceDoc.data() as Map<String, dynamic>)['amount'] as double? ?? 0.0;
      
      // Check if balance is sufficient
      bool hasBalance = currentBalance >= jobPrice;
      
      return {
        'hasBalance': hasBalance,
        'currentBalance': currentBalance,
        'requiredBalance': jobPrice,
        'message': hasBalance 
            ? 'Yeterli bakiye mevcut.' 
            : 'Hesabınızda yeterli bakiye bulunmamaktadır. İş ilanı paylaşmak için en az ${jobPrice.toStringAsFixed(2)} TL bakiyeniz olmalıdır.'
      };
    } catch (e) {
      print('Bakiye kontrol hatası: $e');
      return {
        'hasBalance': false,
        'currentBalance': 0.0,
        'requiredBalance': jobPrice,
        'message': 'Bakiye kontrolü sırasında bir hata oluştu: $e'
      };
    }
  }

  // Add a new job
  Future<Map<String, dynamic>> addJob({
    required String jobName,
    required String jobDescription,
    required double jobPrice,
    required String employerId,
    required String username,
    required String category,
    required bool hasLocation,
    Map<String, dynamic>? locationData,
  }) async {
    try {
      // First check if user has sufficient balance
      Map<String, dynamic> balanceCheck = await checkUserBalance(employerId, jobPrice);
      
      if (!balanceCheck['hasBalance']) {
        return {
          'success': false,
          'message': balanceCheck['message']
        };
      }
      
      // If user has sufficient balance, proceed with adding the job
      DocumentReference jobRef = _firestore.collection('jobs').doc();
      String jobId = jobRef.id;

      Map<String, dynamic> jobData = Job(
        id: jobId,
        jobName: jobName,
        jobDescription: jobDescription,
        jobPrice: jobPrice,
        employerId: employerId,
        username: username,
        category: category,
        hasLocation: hasLocation,
      ).toMap();

      if (hasLocation && locationData != null) {
        try {
          await _database.child('job_locations').child(jobId).set({
            'latitude': locationData['latitude'],
            'longitude': locationData['longitude'],
            'timestamp': ServerValue.timestamp,
            'neighborhood': locationData['neighborhood'],
            'accuracy': locationData['accuracy'],
            'accuracyMeters': locationData['accuracyMeters']
          });

          // Ensure neighborhood is saved as a string
          if (locationData['neighborhood'] != null) {
            jobData['neighborhood'] = locationData['neighborhood'].toString();
          }
          jobData['hasLocation'] = true;
        } catch (e) {
          print('Konum kaydetme hatası: $e');
          jobData['hasLocation'] = false;
        }
      }

      // Add the job to Firestore
      await jobRef.set(jobData);
      
      // Deduct the job price from user's balance
      await _firestore.collection('balances').doc(employerId).set({
        'uid': employerId,
        'amount': FieldValue.increment(-jobPrice),
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      
      // Log the transaction
      await _firestore.collection('transaction_logs').add({
        'uid': employerId,
        'type': 'job_posting',
        'amount': -jobPrice,
        'jobId': jobId,
        'jobName': jobName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'İş ilanı başarıyla eklendi ve hesabınızdan ${jobPrice.toStringAsFixed(2)} TL düşüldü.',
        'jobId': jobId
      };
    } catch (e) {
      print('İş ekleme hatası: $e');
      return {
        'success': false,
        'message': 'İş ilanı eklenirken bir hata oluştu: $e'
      };
    }
  }

  // Delete a job
  Future<bool> deleteJob(Job job) async {
    try {
      await _firestore.collection('jobs').doc(job.id).delete();
      return true;
    } catch (e) {
      print('İş silme hatası: $e');
      return false;
    }
  }

  // Preload data for a user
  static Future<void> preloadData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Fetch jobs
      final jobSnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('employerId', isEqualTo: userId)
          .get();
      
      final jobs = jobSnapshot.docs
          .map((doc) => Job.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      
      // Cache jobs
      await prefs.setString('cached_jobs_$userId', 
          json.encode(jobs.map((job) => job.toJson()).toList()));
      
      // Fetch reviews
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('employerId', isEqualTo: userId)
          .get();
      
      final reviews = reviewSnapshot.docs
          .map((doc) => Review.fromMap(doc.data()))
          .toList();
      
      // Cache reviews
      await prefs.setString('cached_reviews_$userId', 
          json.encode(reviews.map((review) => review.toJson()).toList()));
      
    } catch (e) {
      print('Veri ön yükleme hatası: $e');
    }
  }

  // Show job details dialog
  void showJobDetails(BuildContext context, Job job, Function deleteJob, Function shareJob, bool isCurrentUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.jobName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.category, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.green),
                      Text(
                        '${job.jobPrice.toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'İş Açıklaması:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.jobDescription,
                    style: const TextStyle(height: 1.4),
                  ),
                  if (job.hasLocation) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.neighborhood ?? 'Konum bilgisi yok',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isCurrentUser)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            shareJob(job);
                          },
                          icon: const Icon(Icons.share, color: Colors.blue),
                          label: const Text(
                            'İlanı Paylaş',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            deleteJob(job);
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            'İlanı Sil',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  if (!isCurrentUser)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            shareJob(job);
                          },
                          icon: const Icon(Icons.share, color: Colors.blue),
                          label: const Text(
                            'İlanı Paylaş',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Show add job bottom sheet
  void showAddJobBottomSheet(
    BuildContext context, {
    required TextEditingController jobNameController,
    required TextEditingController jobDescriptionController,
    required TextEditingController jobPriceController,
    required TextEditingController categoryController,
    required FocusNode categoryFocusNode,
    required ScrollController scrollController,
    required List<String> filteredCategories,
    required bool isCategoryListVisible,
    required bool shareLocation,
    required bool isLoading,
    required Function(String) filterCategories,
    required Function() addJob,
    required Future<bool> Function(bool?) onShareLocationChanged,
  }) {
    // Get the current user's ID
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    double currentBalance = 0.0;
    
    // Fetch the user's balance
    if (userId != null) {
      _firestore.collection('balances').doc(userId).get().then((doc) {
        if (doc.exists) {
          currentBalance = (doc.data() as Map<String, dynamic>)['amount'] as double? ?? 0.0;
        }
      }).catchError((e) {
        print('Bakiye çekme hatası: $e');
      });
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (BuildContext context) {
        // Burada ValueNotifier kullanarak durumu yöneteceğiz
        final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(isLoading);
        final ValueNotifier<bool> shareLocationNotifier = ValueNotifier<bool>(shareLocation);
        final ValueNotifier<double> balanceNotifier = ValueNotifier<double>(currentBalance);
        
        // Function to fetch and update balance
        void updateBalance() {
          if (userId != null) {
            _firestore.collection('balances').doc(userId).get().then((doc) {
              if (doc.exists) {
                double newBalance = (doc.data() as Map<String, dynamic>)['amount'] as double? ?? 0.0;
                balanceNotifier.value = newBalance;
              }
            }).catchError((e) {
              print('Bakiye güncelleme hatası: $e');
            });
          }
        }
        
        // Fetch balance when the bottom sheet is shown
        updateBalance();
        
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kaydırma çubuğu göstergesi
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.only(bottom: 15),
                  ),
                  const Text(
                    'Yeni İş İlanı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Bakiye gösterimi
                  ValueListenableBuilder<double>(
                    valueListenable: balanceNotifier,
                    builder: (context, localBalance, child) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mevcut Bakiye:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${localBalance.toStringAsFixed(2)} TL',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Not: İş ilanı paylaşmak için, ilan ücretiniz kadar bakiyeniz olmalıdır.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: jobNameController,
                    decoration: const InputDecoration(
                      labelText: 'İş Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    maxLength: 20,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: categoryController,
                    focusNode: categoryFocusNode,
                    decoration: const InputDecoration(
                        labelText: 'İş Katagorisi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category)),
                    onChanged: (query) {
                      filterCategories(query);
                    },
                    maxLength: 20,
                  ),
                  if (isCategoryListVisible)
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          String category = filteredCategories[index];
                          return GestureDetector(
                            onTap: () {
                              categoryController.text = category;
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Chip(
                                label: Text(category),
                                backgroundColor: Colors.blue[100],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: jobDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'İş Açıklaması',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    maxLength: 150,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: jobPriceController,
                    decoration: const InputDecoration(
                      labelText: 'İş Ücreti',
                      border: OutlineInputBorder(),
                      prefixText: '₺ ',
                      counterText: '', // Hide the counter
                    ),
                    maxLength: 6,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: shareLocationNotifier,
                        builder: (context, localShareLocation, child) {
                          return Checkbox(
                            value: localShareLocation,
                            onChanged: (bool? newValue) {
                              // Checkbox'ın durumunu hemen güncelle
                              shareLocationNotifier.value = newValue ?? false;
                              
                              // Callback'i çağır
                              onShareLocationChanged(newValue);
                            },
                            activeColor: Colors.blue,
                            checkColor: Colors.white,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                          );
                        }
                      ),
                      const Expanded(
                        child: Text(
                          'Yakındaki kullanıcılara göster (Konumunuz paylaşılacak)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<bool>(
                    valueListenable: isLoadingNotifier,
                    builder: (context, localIsLoading, child) {
                      return ElevatedButton(
                        onPressed: localIsLoading 
                          ? null 
                          : () async {
                              // Butona basıldığında hemen loading durumunu güncelle
                              isLoadingNotifier.value = true;
                              
                              try {
                                // Check if job price is valid
                                double? jobPrice = double.tryParse(jobPriceController.text);
                                if (jobPrice == null || jobPrice <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lütfen geçerli bir iş ücreti girin')),
                                  );
                                  // Hata durumunda loading durumunu geri al
                                  isLoadingNotifier.value = false;
                                  return;
                                }
                                
                                // Check if user has sufficient balance
                                if (userId != null) {
                                  Map<String, dynamic> balanceCheck = await checkUserBalance(userId, jobPrice);
                                  
                                  if (!balanceCheck['hasBalance']) {
                                    // Show insufficient balance dialog
                                    if (context.mounted) {
                                      await showInsufficientBalanceDialog(
                                        context,
                                        balanceCheck['currentBalance'],
                                        balanceCheck['requiredBalance'],
                                      );
                                    }
                                    // Yetersiz bakiye durumunda loading durumunu geri al
                                    isLoadingNotifier.value = false;
                                    return;
                                  }
                                }
                                
                                // İşi ekle
                                addJob();
                              } catch (e) {
                                print('Hata: $e');
                                // Herhangi bir hata durumunda loading durumunu geri al
                                isLoadingNotifier.value = false;
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 50),
                          disabledBackgroundColor: Colors.green.withOpacity(0.7),
                          disabledForegroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (localIsLoading)
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 10),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.add, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              localIsLoading ? 'Kaydediliyor...' : 'İşi Kaydet',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Navigate to deposit screen
  void navigateToDepositScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DepositScreen(),
      ),
    );
  }

  // Show insufficient balance dialog
  Future<void> showInsufficientBalanceDialog(
    BuildContext context,
    double currentBalance,
    double requiredBalance,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yetersiz Bakiye'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Mevcut bakiyeniz: ${currentBalance.toStringAsFixed(2)} TL'),
                Text('Gerekli bakiye: ${requiredBalance.toStringAsFixed(2)} TL'),
                const SizedBox(height: 10),
                const Text(
                  'İş ilanı paylaşmak için yeterli bakiyeniz bulunmamaktadır. '
                  'Para yatırma ekranına gitmek ister misiniz?',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Para Yatır'),
              onPressed: () {
                Navigator.of(context).pop();
                navigateToDepositScreen(context);
              },
            ),
          ],
        );
      },
    );
  }
} 