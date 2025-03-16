import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myapp/qrscanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:myapp/model/job_and_rivevws.dart';
import 'package:myapp/model/user_model.dart';
import 'package:myapp/screens/ispaylasmaprfili/drawer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

// Import services
import 'package:myapp/services/job_service.dart';
import 'package:myapp/services/review_service.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/services/share_service.dart';
import 'package:myapp/screens/ispaylasmaprfili/components/job_profile_components.dart';

class JobProfilePage extends StatefulWidget {
  final UserModel user;

  const JobProfilePage({super.key, required this.user});

  @override
  _JobProfilePageState createState() => _JobProfilePageState();
  
  // Static method to navigate to this page with preloaded data
  static Future<void> navigateWithPreloadedData(BuildContext context, UserModel user) async {
    // Start preloading data
    JobService.preloadData(user.uid);
    
    // Navigate to the page immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobProfilePage(user: user),
      ),
    );
  }
}

class _JobProfilePageState extends State<JobProfilePage> {
  final _jobNameController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _jobPriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final NetworkInfo _networkInfo = NetworkInfo();

  // Services
  final JobService _jobService = JobService();
  final ReviewService _reviewService = ReviewService();
  final LocationService _locationService = LocationService();
  final ShareService _shareService = ShareService();

  List<Job> _jobs = [];
  List<Review> _reviews = [];
  double _averageRating = 0.0;
  bool _shareLocation = false;
  bool _isLoading = true;
  List<String> _categories = [];
  List<String> _filteredCategories = [];
  bool _isCategoryListVisible = false;
  final FocusNode _categoryFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool isCurrentUser = false;
  late SharedPreferences _prefs;
  bool _hasLoadedCache = false;
  bool _showShimmer = false;

  @override
  void initState() {
    super.initState();
    isCurrentUser = FirebaseAuth.instance.currentUser?.uid == widget.user.uid;
    
    // Immediately try to load cached data
    _loadCachedDataFirst();
    
    // Only show shimmer if data isn't loaded quickly
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && !_hasLoadedCache) {
        setState(() {
          _showShimmer = true;
        });
      }
    });
  }
  
  Future<void> _loadCachedDataFirst() async {
    try {
      print("Önbellek kontrolü başladı - Kullanıcı ID: ${widget.user.uid}");
      _prefs = await SharedPreferences.getInstance();
      
      // Load cached data first
      final cachedJobs = _prefs.getString('cached_jobs_${widget.user.uid}');
      print("Önbellek kontrolü - Kullanıcı ID: ${widget.user.uid}");
      
      if (cachedJobs != null) {
        print("Önbellekte iş ilanları bulundu");
        try {
          final List<dynamic> jobsList = json.decode(cachedJobs);
          print("Önbellekteki iş ilanı sayısı: ${jobsList.length}");
          
          if (mounted) {
            setState(() {
              _jobs = jobsList.map((job) => Job.fromJson(job)).toList();
              _hasLoadedCache = true;
              _showShimmer = false;
            });
            
            // Debug bilgisi
            for (var job in _jobs) {
              print("Önbellekten yüklenen iş - ID: ${job.id}, İş Adı: ${job.jobName}");
            }
          }
        } catch (e) {
          print("Önbellekten iş ilanları yüklenirken hata: $e");
        }
      } else {
        print("Önbellekte iş ilanı bulunamadı");
      }

      final cachedReviews = _prefs.getString('cached_reviews_${widget.user.uid}');
      if (cachedReviews != null) {
        try {
          final List<dynamic> reviewsList = json.decode(cachedReviews);
          print("Önbellekteki değerlendirme sayısı: ${reviewsList.length}");
          
          if (mounted) {
            setState(() {
              _reviews = reviewsList.map((review) => Review.fromJson(review)).toList();
              _calculateAverageRating();
            });
          }
        } catch (e) {
          print("Önbellekten değerlendirmeler yüklenirken hata: $e");
        }
      } else {
        print("Önbellekte değerlendirme bulunamadı");
      }
      
      // Then fetch fresh data from Firebase in the background
      _fetchData();
    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Hata durumunda da Firebase'den veri çekmeyi dene
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    try {
      print("Veriler yükleniyor... Kullanıcı ID: ${widget.user.uid}");
      final jobs = await _jobService.fetchJobs(widget.user.uid);
      final reviews = await _reviewService.fetchReviews(widget.user.uid);

      if (!mounted) return;

      // Debug bilgisi
      if (jobs != null) {
        print("Yüklenen iş ilanı sayısı: ${jobs.length}");
        for (var job in jobs) {
          print("İş ID: ${job.id}, İş Adı: ${job.jobName}");
        }
      } else {
        print("Yüklenen iş ilanı yok veya null");
      }

      setState(() {
        if (jobs != null) {
          _jobs = jobs;
          // Cache the jobs
          _prefs.setString('cached_jobs_${widget.user.uid}', 
              json.encode(_jobs.map((job) => job.toJson()).toList()));
        }
        
        if (reviews != null) {
          _reviews = reviews;
          _calculateAverageRating();
          // Cache the reviews
          _prefs.setString('cached_reviews_${widget.user.uid}', 
              json.encode(_reviews.map((review) => review.toJson()).toList()));
        }
        
        _hasLoadedCache = true;
        _isLoading = false;
        _showShimmer = false;
      });
    } catch (e) {
      print('Veri çekme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showShimmer = false;
        });
      }
    }
  }

  void _filterCategories(String query) {
    setState(() {
      _filteredCategories = _categories
          .where((category) =>
              category.toLowerCase().contains(query.toLowerCase()))
          .take(3)
          .toList();
      _isCategoryListVisible = query.isNotEmpty;
    });
  }

  void _addJob() async {
    if (_jobNameController.text.isEmpty ||
        _jobDescriptionController.text.isEmpty ||
        _jobPriceController.text.isEmpty ||
        _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    // İşlem başladığında loading durumunu güncelle
      setState(() {
        _isLoading = true;
      });

    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      String username = userSnapshot['username'] ?? 'Bilinmeyen Kullanıcı';

      Map<String, dynamic>? locationData;
      if (_shareLocation) {
        try {
          // Location permission should already be granted at this point
          locationData = await _locationService.getLocationForJob();
        } catch (e) {
          print('Konum alma hatası: $e');
          // Show an error message but continue without location
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Konum alınamadı: $e')),
            );
          }
        }
      }

      // Parse job price
      double jobPrice = double.parse(_jobPriceController.text);

      // Call the job service to add the job
      Map<String, dynamic> result = await _jobService.addJob(
        jobName: _jobNameController.text,
        jobDescription: _jobDescriptionController.text,
        jobPrice: jobPrice,
        employerId: widget.user.uid,
        username: username,
        category: _categoryController.text,
        hasLocation: _shareLocation && locationData != null,
        locationData: locationData,
      );

      // İşlem tamamlandığında loading durumunu güncelle
      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Job added successfully
        _jobNameController.clear();
        _jobDescriptionController.clear();
        _jobPriceController.clear();
        _categoryController.clear();
        setState(() {
          _shareLocation = false;
        });

        await _fetchData();
        
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      } else {
        // Failed to add job
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('İş ekleme hatası: $e');
      
      // Hata durumunda loading durumunu güncelle
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İş eklenirken hata oluştu: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteJob(Job job) async {
    try {
      bool success = await _jobService.deleteJob(job);

      if (success) {
      List<Job> cachedJobs = _jobs.where((j) => j.id != job.id).toList();
      await _prefs.setString('cached_jobs_${widget.user.uid}',
          json.encode(cachedJobs.map((job) => job.toJson()).toList()));

      setState(() {
        _jobs = cachedJobs;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İş ilanı başarıyla silindi')),
        );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İş ilanı silinirken bir hata oluştu')),
          );
        }
      }
    } catch (e) {
      print('İş silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İş ilanı silinirken bir hata oluştu')),
        );
      }
    }
  }

  void _addReview() async {
    await _reviewService.addReview(context, widget.user.uid);
    // Refresh data after adding review
    _fetchData();
  }

  void _calculateAverageRating() {
    setState(() {
      _averageRating = _reviewService.calculateAverageRating(_reviews);
    });
  }

  void _showAddJobBottomSheet() {
    _jobService.showAddJobBottomSheet(
      context,
      jobNameController: _jobNameController,
      jobDescriptionController: _jobDescriptionController,
      jobPriceController: _jobPriceController,
      categoryController: _categoryController,
      categoryFocusNode: _categoryFocusNode,
      scrollController: _scrollController,
      filteredCategories: _filteredCategories,
      isCategoryListVisible: _isCategoryListVisible,
      shareLocation: _shareLocation,
      isLoading: _isLoading,
      filterCategories: _filterCategories,
      addJob: _addJob,
      onShareLocationChanged: (bool? newValue) async {
        // Checkbox'ın durumunu hemen güncelle
        bool newState = newValue ?? false;
        
        // Eğer checkbox işaretlendiyse konum izni kontrolü yap
        if (newState) {
          bool hasPermission = await _locationService.checkLocationPermission();
          
          if (!hasPermission) {
            // Konum izni yoksa, kullanıcıya sor
            if (context.mounted) {
              bool? dialogResult = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konum İzni Gerekli'),
                  content: const Text(
                    'İşinizi yakındaki kullanıcılara göstermek için konum izni gereklidir. '
                    'Konum izni vermek istiyor musunuz?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Hayır'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Evet'),
                    ),
                  ],
                ),
              );
              
              if (dialogResult == true) {
                try {
                  await _locationService.getLocationForJob();
                  setState(() {
                    _shareLocation = true;
                  });
                  return true;
                } catch (e) {
                  print('Konum izni hatası: $e');
                  setState(() {
                    _shareLocation = false;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Konum izni alınamadı: $e')),
                    );
                  }
                  return false;
                }
              } else {
                setState(() {
                  _shareLocation = false;
                });
                return false;
              }
            }
            return false;
          } else {
            setState(() {
              _shareLocation = true;
            });
            return true;
          }
        } else {
          setState(() {
            _shareLocation = false;
          });
          return false;
        }
      },
    );
  }

  void _showJobDetails(Job job) {
    _jobService.showJobDetails(
      context, 
      job, 
      _deleteJob, 
      (Job job) => _shareService.shareJob(job, widget.user.username),
      isCurrentUser
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'İş Platformu',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        leading: isCurrentUser
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (isCurrentUser) // Sadece kendi profilinde QR okuyucu göster
            IconButton(
              icon: const Icon(Icons.share),
              color: Colors.blue,
              onPressed: () => _shareService.shareProfile(widget.user),
            ),
         IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConstructionPage(
                    //currentUser: FirebaseAuth.instance.currentUser!,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: isCurrentUser ? MyDrawer(user: widget.user) : null,
      body: _showShimmer
          ? ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => JobProfileComponents.buildSkeletonCard(),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'profile-${widget.user.uid}',
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: widget.user.profileImageUrl != null
                              ? NetworkImage(widget.user.profileImageUrl!)
                              : null,
                          child: widget.user.profileImageUrl == null
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.user.username,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 5),
                            Text(
                              _averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' (${_reviews.length} Değerlendirme)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.work, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text(
                                        'İş İlanları',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (FirebaseAuth.instance.currentUser?.uid ==
                                      widget.user.uid)
                                    ElevatedButton.icon(
                                      onPressed: _showAddJobBottomSheet,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Yeni İş Ekle'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  IconButton(
                                      onPressed: () {
                                        print("Paylaş butonuna tıklandı. İş listesi uzunluğu: ${_jobs.length}");
                                        if (_jobs.isNotEmpty) {
                                          // Debug bilgisi ekleyelim
                                          print("Paylaşılacak iş: ${_jobs.first.jobName}, ID: ${_jobs.first.id}");
                                          _shareService.shareJob(_jobs.first, widget.user.username);
                                        } else {
                                          print("Paylaşılacak iş bulunamadı. Jobs listesi boş.");
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Paylaşılacak iş ilanı bulunamadı')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.share),
                                      color: Colors.blue,
                                      tooltip: 'İş İlanını Paylaş',
                                    )
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Debug bilgisi ekleyelim
                              Text(
                                "Toplam iş ilanı: ${_jobs.length}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _jobs.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Text(
                                          'Henüz iş ilanı yok',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 120,
                                      child: PageView.builder(
                                        controller: PageController(
                                            viewportFraction: 0.9),
                                        itemCount: _jobs.length,
                                        itemBuilder: (context, index) {
                                          Job job = _jobs[index];
                                          return JobProfileComponents.buildJobCard(
                                            job, 
                                            index, 
                                            _showJobDetails
                                          );
                                        },
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.rate_review,
                                          color: Colors.amber),
                                      SizedBox(width: 8),
                                      Text(
                                        'Değerlendirmeler',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (FirebaseAuth.instance.currentUser?.uid !=
                                      widget.user.uid)
                                    ElevatedButton.icon(
                                      onPressed: _addReview,
                                      icon: const Icon(Icons.star, size: 18),
                                      label: const Text('Değerlendir'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _reviews.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Text(
                                          'Henüz değerlendirme yok',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 120,
                                      child: PageView.builder(
                                        controller: PageController(
                                            viewportFraction: 0.9),
                                        itemCount: _reviews.length,
                                        itemBuilder: (context, index) {
                                          Review review = _reviews[index];
                                          return JobProfileComponents.buildReviewCard(review, index);
                                        },
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton:
          FirebaseAuth.instance.currentUser?.uid == widget.user.uid
              ? FloatingActionButton(
                  onPressed: _showAddJobBottomSheet,
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}
