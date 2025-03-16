
import 'package:flutter/material.dart';

class ConstructionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yapım Aşamasında'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.build,
              size: 100.0,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              'Bu özellik şu anda geliştirilme aşamasında.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Lütfen daha sonra tekrar deneyin.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}







/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:async/async.dart';

class ConnectedDevicesPage extends StatefulWidget {
  final User currentUser;

  const ConnectedDevicesPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<ConnectedDevicesPage> createState() => _ConnectedDevicesPageState();
}

class _ConnectedDevicesPageState extends State<ConnectedDevicesPage> {
  late Stream<QuerySnapshot> _sessionsStream;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initSessionsStream();
    
    // Sayfa açıldığında hemen verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSessions();
    });
    
    // Her 5 saniyede bir verileri yenile
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _refreshSessions();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initSessionsStream() {
    // Son 5 dakikanın timestamp'ini hesapla
    final DateTime fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    final Timestamp fiveMinutesAgoTimestamp = Timestamp.fromDate(fiveMinutesAgo);

    // Aktif oturumlar için sorgu
    final Stream<QuerySnapshot> activeSessionsStream = FirebaseFirestore.instance
        .collection('qr_sessions')
        .where('userId', isEqualTo: widget.currentUser.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots();
    
    // Son 5 dakika içinde kapatılmış oturumlar için sorgu
    final Stream<QuerySnapshot> recentlyDisconnectedSessionsStream = FirebaseFirestore.instance
        .collection('qr_sessions')
        .where('userId', isEqualTo: widget.currentUser.uid)
        .where('status', isEqualTo: 'disconnected')
        .where('disconnectedAt', isGreaterThan: fiveMinutesAgoTimestamp)
        .orderBy('disconnectedAt', descending: true)
        .snapshots();
    
    // İki stream'i birleştir
    _sessionsStream = StreamGroup.merge([
      activeSessionsStream,
      recentlyDisconnectedSessionsStream
    ]).asBroadcastStream();
    
    // Debug için
    print('Session stream yenilendi');
    print('5 dakika öncesi timestamp: ${fiveMinutesAgoTimestamp.seconds}');
  }

  void _refreshSessions() {
    print('Oturumlar yenileniyor...');
    
    // 5 dakika öncesinin timestamp'ini hesapla
    final DateTime fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    final Timestamp fiveMinutesAgoTimestamp = Timestamp.fromDate(fiveMinutesAgo);
    
    // Firestore'dan en son verileri al
    FirebaseFirestore.instance
        .collection('qr_sessions')
        .where('userId', isEqualTo: widget.currentUser.uid)
        .get()
        .then((snapshot) {
          // Verileri işle ve state'i güncelle
          if (mounted) {
            setState(() {
              // Yeniden stream oluştur
              _initSessionsStream();
            });
          }
          
          // Debug için
          print('Oturumlar yenilendi: ${snapshot.docs.length} oturum bulundu');
          
          // Aktif ve kapatılmış oturumları say
          int activeCount = 0;
          int recentlyDisconnectedCount = 0;
          int oldDisconnectedCount = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['status'] == 'completed') {
              activeCount++;
            } else if (data['status'] == 'disconnected') {
              final disconnectedAt = data['disconnectedAt'] as Timestamp?;
              if (disconnectedAt != null && disconnectedAt.compareTo(fiveMinutesAgoTimestamp) > 0) {
                recentlyDisconnectedCount++;
              } else {
                oldDisconnectedCount++;
              }
            }
          }
          
          print('Aktif oturum sayısı: $activeCount');
          print('Son 5 dakikada kapatılmış oturum sayısı: $recentlyDisconnectedCount');
          print('5 dakikadan eski kapatılmış oturum sayısı: $oldDisconnectedCount');
        })
        .catchError((error) {
          print('Oturumları yenileme hatası: $error');
        });
  }

  Future<void> _disconnectSession(String sessionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Doğrudan Firestore'u güncelle
      await FirebaseFirestore.instance
          .collection('qr_sessions')
          .doc(sessionId)
          .update({
        'status': 'disconnected',
        'disconnectedAt': FieldValue.serverTimestamp(),
        'disconnectedBy': 'mobile_app_logout',
        'disconnectedByUserId': widget.currentUser.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz bağlantısı kesildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectAllSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Aktif tüm oturumları al
      final QuerySnapshot sessions = await FirebaseFirestore.instance
          .collection('qr_sessions')
          .where('userId', isEqualTo: widget.currentUser.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      if (sessions.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kapatılacak aktif oturum bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Batch işlemi oluştur
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Tüm oturumları güncelle
      for (var doc in sessions.docs) {
        batch.update(doc.reference, {
          'status': 'disconnected',
          'disconnectedAt': FieldValue.serverTimestamp(),
          'disconnectedBy': 'mobile_app_logout',
          'disconnectedByUserId': widget.currentUser.uid,
        });
      }
      
      // Batch işlemini çalıştır
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sessions.docs.length} cihazın bağlantısı kesildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  IconData _getDeviceIcon(String? deviceInfo) {
    if (deviceInfo == null) return Icons.devices;
    
    final String deviceInfoLower = deviceInfo.toLowerCase();
    
    if (deviceInfoLower.contains('android')) return Icons.phone_android;
    if (deviceInfoLower.contains('iphone') || deviceInfoLower.contains('ios')) return Icons.phone_iphone;
    if (deviceInfoLower.contains('ipad')) return Icons.tablet_mac;
    if (deviceInfoLower.contains('mac')) return Icons.laptop_mac;
    if (deviceInfoLower.contains('windows')) return Icons.laptop_windows;
    if (deviceInfoLower.contains('linux')) return Icons.laptop;
    if (deviceInfoLower.contains('web') || 
        deviceInfoLower.contains('tarayıcı')) return Icons.web;
    if (deviceInfoLower.contains('chrome') || 
        deviceInfoLower.contains('firefox') || 
        deviceInfoLower.contains('safari') || 
        deviceInfoLower.contains('edge')) return Icons.web;
    
    return Icons.devices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlı Cihazlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSessions,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<QuerySnapshot>(
              // Sayfa açıldığında en güncel verileri al
              future: FirebaseFirestore.instance
                  .collection('qr_sessions')
                  .where('userId', isEqualTo: widget.currentUser.uid)
                  .get(),
              builder: (context, futureSnapshot) {
                // Future sonucu önemli değil, sadece tetiklemek için
                return StreamBuilder<QuerySnapshot>(
                  stream: _sessionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && 
                        !snapshot.hasData && 
                        !futureSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}'));
                    }

                    // Hem stream hem de future'dan gelen verileri birleştir
                    final List<DocumentSnapshot> allDocs = [];
                    
                    // Stream'den gelen veriler
                    if (snapshot.hasData) {
                      allDocs.addAll(snapshot.data!.docs);
                    }
                    
                    // Future'dan gelen veriler (eğer stream'de yoksa)
                    if (futureSnapshot.hasData) {
                      for (var doc in futureSnapshot.data!.docs) {
                        if (!allDocs.any((existingDoc) => existingDoc.id == doc.id)) {
                          allDocs.add(doc);
                        }
                      }
                    }

                    if (allDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.devices_other, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Bağlı cihaz bulunamadı',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QR kod ile giriş yaptığınız cihazlar burada görünecektir',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // Process documents to filter out duplicates
                    final List<DocumentSnapshot> processedDocs = [];
                    final Map<String, DocumentSnapshot> deviceMap = {};
                    
                    // 5 dakika öncesinin timestamp'ini hesapla
                    final DateTime fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
                    final Timestamp fiveMinutesAgoTimestamp = Timestamp.fromDate(fiveMinutesAgo);

                    // First, prioritize active sessions over disconnected ones
                    for (var doc in allDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final deviceInfo = data['deviceInfo'] as String? ?? '';
                      final browser = data['browser'] as String? ?? '';
                      final status = data['status'] as String? ?? 'completed';
                      final sessionId = doc.id;
                      
                      // Kapatılmış oturumlar için 5 dakika kontrolü yap
                      if (status == 'disconnected') {
                        final disconnectedAt = data['disconnectedAt'] as Timestamp?;
                        if (disconnectedAt == null || disconnectedAt.compareTo(fiveMinutesAgoTimestamp) <= 0) {
                          // 5 dakikadan eski kapatılmış oturumları atla
                          print('5 dakikadan eski oturum atlandı: $sessionId');
                          continue;
                        }
                      }
                      
                      // Create a unique key for each device
                      final deviceKey = '$deviceInfo-$browser-$sessionId';
                      
                      if (status == 'completed') {
                        // Always prefer active sessions
                        deviceMap[deviceKey] = doc;
                      } else if (!deviceMap.containsKey(deviceKey)) {
                        // Only add disconnected session if we don't have an active one
                        deviceMap[deviceKey] = doc;
                      }
                    }
                    
                    // Convert map back to list and sort by status (active first)
                    processedDocs.addAll(deviceMap.values);
                    processedDocs.sort((a, b) {
                      final statusA = (a.data() as Map<String, dynamic>)['status'] as String? ?? '';
                      final statusB = (b.data() as Map<String, dynamic>)['status'] as String? ?? '';
                      // 'completed' comes before 'disconnected'
                      return statusA.compareTo(statusB);
                    });
                    
                    // Debug için
                    print('İşlenen oturum sayısı: ${processedDocs.length}');

                    return ListView.builder(
                      itemCount: processedDocs.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final data = processedDocs[index].data() as Map<String, dynamic>;
                        final sessionId = processedDocs[index].id;
                        final deviceInfo = data['deviceInfo'] as String? ?? 'Bilinmeyen Cihaz';
                        final browser = data['browser'] as String? ?? 'Bilinmeyen Tarayıcı';
                        final ipAddress = data['ipAddress'] as String? ?? 'Bilinmeyen IP';
                        final location = data['location'] as String? ?? 'Bilinmeyen Konum';
                        final completedAt = data['completedAt'] as Timestamp?;
                        final lastActive = data['lastActive'] as Timestamp?;
                        final userAgent = data['userAgent'] as String? ?? 'Bilinmeyen User Agent';
                        final status = data['status'] as String? ?? 'completed';
                        final disconnectedAt = data['disconnectedAt'] as Timestamp?;
                        final disconnectedBy = data['disconnectedBy'] as String? ?? 'unknown';

                        final bool isDisconnected = status == 'disconnected';
                        final String disconnectInfo = isDisconnected 
                            ? disconnectedBy == 'web_manual_logout' 
                                ? 'Web sitesinden manuel olarak çıkış yapıldı' 
                                : ''
                            : '';

                        return Card(
                          key: ValueKey(sessionId),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Oturum kapatıldı uyarısı
                                if (isDisconnected)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.grey.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                disconnectedBy == 'web_manual_logout' 
                                                    ? 'Web Oturumu Kapatıldı'
                                                    : 'Oturum Kapatıldı',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              if (disconnectInfo.isNotEmpty)
                                                Text(
                                                  disconnectInfo,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              if (disconnectedAt != null && disconnectedBy == 'web_manual_logout')
                                                Text(
                                                  'Kapatılma zamanı: ${_formatTimestamp(disconnectedAt)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              if (disconnectedAt != null) 
                                                Text(
                                                  _getRemainingTimeText(disconnectedAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isDisconnected 
                                            ? Colors.grey.withOpacity(0.1) 
                                            : Theme.of(context).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getDeviceIcon(deviceInfo),
                                        color: isDisconnected 
                                            ? Colors.grey 
                                            : Theme.of(context).primaryColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deviceInfo,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDisconnected ? Colors.grey : Colors.black,
                                            ),
                                          ),
                                          Text(
                                            browser,
                                            style: TextStyle(
                                              color: isDisconnected ? Colors.grey[500] : Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(Icons.access_time, 'Giriş Zamanı', _formatTimestamp(completedAt)),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.update, 'Son Aktivite', _formatTimestamp(lastActive)),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.location_on, 'Konum', location),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.wifi, 'IP Adresi', ipAddress),
                                const SizedBox(height: 8),
                                ExpansionTile(
                                  title: Text(
                                    'Detaylı Cihaz Bilgileri',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'User Agent:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            userAgent,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[800],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (!isDisconnected)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _disconnectSession(sessionId),
                                      icon: const Icon(Icons.logout),
                                      label: const Text('Oturumu Kapat'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isDisconnected)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: null, // Devre dışı bırakıldı
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('Oturum Kapatıldı'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        side: BorderSide(color: Colors.grey.shade300),
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
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _disconnectAllSessions,
        icon: const Icon(Icons.logout),
        label: const Text('Tüm Cihazları Çıkış Yap'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value == 'Bilinmiyor' ? 'Bilgi alınamadı' : value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getRemainingTimeText(Timestamp disconnectedAt) {
    final DateTime disconnectedDateTime = disconnectedAt.toDate();
    final DateTime expiryTime = disconnectedDateTime.add(const Duration(minutes: 5));
    final DateTime now = DateTime.now();
    
    // Kalan süreyi hesapla
    final Duration remainingTime = expiryTime.difference(now);
    
    if (remainingTime.isNegative) {
      return 'Bu bilgi birazdan kaldırılacak';
    } else if (remainingTime.inMinutes >= 1) {
      return 'Bu bilgi ${remainingTime.inMinutes} dk ${remainingTime.inSeconds % 60} sn sonra kaldırılacak';
    } else {
      return 'Bu bilgi ${remainingTime.inSeconds} saniye sonra kaldırılacak';
    }
  }
} */