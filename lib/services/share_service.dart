import 'package:share_plus/share_plus.dart';
import 'package:myapp/model/job_and_rivevws.dart';
import 'package:myapp/model/user_model.dart';

class ShareService {
  // Uygulama için deep link URL şeması
  static const String appScheme = "isapp://";
  
  // Share profile
  void shareProfile(UserModel user) {
    // Web URL - go_router ile uyumlu
    final String webProfileUrl = "https://isapp.com/profile/${user.uid}"; 
    
    // Deep link URL
    final String deepLinkUrl = "${appScheme}profile/${user.uid}";
    
    // Basit bir paylaşım metni oluştur
    final String shareText = "${user.username} adlı kullanıcının iş profilini incelemek için tıklayın:\n\n"
        "$deepLinkUrl\n\n"
        "veya\n\n"
        "$webProfileUrl\n\n"
        "Uygulama yüklüyse otomatik açılacaktır.";
    
    Share.share(shareText, subject: "${user.username} - İş Profili");
  }
  
  // Share job
  void shareJob(Job job, String username) {
    // Web URL - go_router ile uyumlu
    final String webJobUrl = "https://isapp.com/job/${job.id}";
    
    // Deep link URL
    final String deepLinkUrl = "${appScheme}job/${job.id}";
    
    // Basit bir paylaşım metni oluştur
    final String shareText = "Benim İşimi Yapmaya ne dersin?\n\n"
        "İş Adı: ${job.jobName}\n\n"
        "İş Açıklaması: ${job.jobDescription}\n\n"
        "Fiyat: ${job.jobPrice.toStringAsFixed(2)} ₺\n\n"
        "İş Veren: $username\n\n"
        "Detaylar için: $deepLinkUrl\n\n"
        "veya\n\n"
        "$webJobUrl\n\n"
        "Uygulama yüklüyse otomatik açılacaktır.";
    
    Share.share(shareText, subject: "${job.jobName} - İş İlanı");
  }
} 