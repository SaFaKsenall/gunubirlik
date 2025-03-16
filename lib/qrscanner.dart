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
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class QRScannerapp extends StatefulWidget {
  final User currentUser;

  const QRScannerapp({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<QRScannerapp> createState() => _QRScannerappState();
}

class _QRScannerappState extends State<QRScannerapp> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;
  bool isTorchOn = false;
  bool isFrontCamera = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // QR Scanner
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          
          // Overlay with blur effect
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Scanning animation
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Positioned(
                                top: _animation.value * (MediaQuery.of(context).size.width * 0.7 - 2),
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Colors.blue.shade400, Colors.transparent],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Corner decorations
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _buildCorner(Alignment.topLeft),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _buildCorner(Alignment.topRight),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: _buildCorner(Alignment.bottomLeft),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: _buildCorner(Alignment.bottomRight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Top bar with back button and title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'QR Kod ile Giriş',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Instruction text
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'QR kodu kare içerisine yerleştirin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                  ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Camera controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      icon: isTorchOn ? Icons.flash_off : Icons.flash_on,
                      label: isTorchOn ? 'Flaş Kapat' : 'Flaş Aç',
                      onPressed: () {
                        controller.toggleTorch();
                        setState(() {
                          isTorchOn = !isTorchOn;
                        });
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildControlButton(
                      icon: isFrontCamera ? Icons.camera_rear : Icons.camera_front,
                      label: isFrontCamera ? 'Arka Kamera' : 'Ön Kamera',
                      onPressed: () {
                        controller.switchCamera();
                        setState(() {
                          isFrontCamera = !isFrontCamera;
                        });
            },
          ),
                  ],
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 16),
            Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'QR Kod İşleniyor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: alignment == Alignment.topLeft || alignment == Alignment.topRight ? Colors.blue : Colors.transparent,
            width: 4,
          ),
          bottom: BorderSide(
            color: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? Colors.blue : Colors.transparent,
            width: 4,
          ),
          left: BorderSide(
            color: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? Colors.blue : Colors.transparent,
            width: 4,
          ),
          right: BorderSide(
            color: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? Colors.blue : Colors.transparent,
            width: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.blue, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      isProcessing = true;
    });
    
    // QR kodu okutulduğunda kamerayı durdur
    controller.stop();

    try {
      final sessionId = code;
      print('QR Code tarandı: $sessionId');

      // QR session kontrolü
      final sessionDoc = await FirebaseFirestore.instance
          .collection('qr_sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Geçersiz QR kod');
      }

      // Mevcut session bilgilerini al
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      
      // Cihaz bilgilerini koru
      final deviceInfo = sessionData['deviceInfo'] ?? 'Web Tarayıcı';
      final browser = sessionData['browser'] ?? 'Bilinmeyen Tarayıcı';
      final ipAddress = sessionData['ipAddress'] ?? 'Bilinmeyen IP';
      final location = sessionData['location'] ?? 'Bilinmeyen Konum';
      final userAgent = sessionData['userAgent'] ?? 'Bilinmeyen User Agent';

      print('Mevcut kullanıcı bilgileri: ${widget.currentUser.email}');

      // Session'ı güncelle
      final updateData = {
        'status': 'completed',
        'userId': widget.currentUser.uid,
        'userData': {
          'email': widget.currentUser.email,
          'username': widget.currentUser.displayName,
          // diğer kullanıcı bilgileri
        },
        'completedAt': FieldValue.serverTimestamp(),
        // Web tarafından alınan bilgileri koru
        'deviceInfo': deviceInfo,
        'browser': browser,
        'ipAddress': ipAddress,
        'location': location,
        'userAgent': userAgent,
        'lastActive': FieldValue.serverTimestamp(),
      };
      
      print('Firestore\'a gönderilen veriler: $updateData');

      await FirebaseFirestore.instance
          .collection('qr_sessions')
          .doc(sessionId)
          .update(updateData);

      print('QR session güncellendi');

      if (!mounted) return;

      // Başarılı işlem sonrası animasyonlu bildirim
      _showSuccessDialog();
    } catch (e) {
      print('QR Login Hatası: $e');
      if (!mounted) return;

      // Hata durumunda bildirim
      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Text('Başarılı'),
          ],
        ),
        content: const Text('Web oturumu başarıyla açıldı!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // QR sayfasından çık
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    setState(() {
      isProcessing = false;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Text('Hata'),
          ],
        ),
        content: Text('QR kod işlenirken bir hata oluştu: $errorMessage'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // QR sayfasından çık
            },
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              // Kamerayı yeniden başlat
              controller.start();
            },
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}*/
