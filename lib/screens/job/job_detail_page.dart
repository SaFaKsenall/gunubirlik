import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/model/job_and_rivevws.dart';
import 'package:myapp/model/user_model.dart';
import 'package:myapp/services/share_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobDetailPage extends StatefulWidget {
  final String jobId;
  final String? employerId;

  const JobDetailPage({
    Key? key,
    required this.jobId,
    this.employerId,
  }) : super(key: key);

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool _isLoading = true;
  Job? _job;
  UserModel? _employer;
  String _errorMessage = '';
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _loadJobData();
  }

  Future<void> _loadJobData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // İş bilgilerini yükle
      final jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .get();

      if (!jobDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'İş ilanı bulunamadı';
        });
        return;
      }

      final jobData = jobDoc.data() as Map<String, dynamic>;
      final job = Job.fromMap({
        'id': widget.jobId,
        ...jobData,
      });

      // İşveren bilgilerini yükle
      final employerId = widget.employerId ?? jobData['employerId'];
      if (employerId != null) {
        final employerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(employerId)
            .get();

        if (employerDoc.exists) {
          final employerData = employerDoc.data() as Map<String, dynamic>;
          _employer = UserModel.fromMap({
            'uid': employerId,
            ...employerData,
          });
        }
      }

      setState(() {
        _job = job;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'İş bilgileri yüklenirken bir hata oluştu: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_job?.jobName ?? 'İş Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _job != null && _employer != null
                ? () => _shareService.shareJob(_job!, _employer!.username)
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadJobData,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _buildJobDetail(),
      bottomNavigationBar: _job != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildJobDetail() {
    if (_job == null) {
      return const Center(child: Text('İş bilgileri bulunamadı'));
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İş başlığı ve fiyat
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _job!.jobName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currencyFormat.format(_job!.jobPrice),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _job!.category,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'İş Açıklaması',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _job!.jobDescription,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // İşveren bilgileri
          if (_employer != null) _buildEmployerCard(),
          const SizedBox(height: 16),
          // Konum bilgileri
          if (_job!.hasLocation && _job!.location != null) _buildLocationCard(),
        ],
      ),
    );
  }

  Widget _buildEmployerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İşveren',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.go('/profile/${_employer!.uid}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _employer?.profileImageUrl != null
                        ? NetworkImage(_employer!.profileImageUrl!)
                        : null,
                    child: _employer?.profileImageUrl == null
                        ? Text(
                            _employer!.username.isNotEmpty
                                ? _employer!.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _employer!.username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_employer!.role != null)
                          Text(
                            _employer!.role!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konum',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _job!.neighborhood ?? 'Konum bilgisi',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            // Burada harita gösterimi eklenebilir
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isEmployer = currentUser != null && _job!.employerId == currentUser.uid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: isEmployer
          ? ElevatedButton.icon(
              onPressed: () {
                // İş ilanını düzenleme işlemi
              },
              icon: const Icon(Icons.edit),
              label: const Text('İlanı Düzenle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () {
                // İşe başvurma işlemi
              },
              icon: const Icon(Icons.work),
              label: const Text('İşe Başvur'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
    );
  }
} 