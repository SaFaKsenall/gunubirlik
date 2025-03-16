const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const cors = require('cors');
const fetch = require('node-fetch');

// Firebase yapılandırma bilgilerini firebaseconfig.js dosyasından al
const firebaseConfig = require('./firebaseconfig');

// Firebase Admin SDK yapılandırması
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      type: firebaseConfig.type,
      project_id: firebaseConfig.projectId,
      private_key_id: firebaseConfig.private_key_id,
      private_key: firebaseConfig.private_key,
      client_email: firebaseConfig.client_email,
      client_id: firebaseConfig.client_id,
      auth_uri: firebaseConfig.auth_uri,
      token_uri: firebaseConfig.token_uri,
      auth_provider_x509_cert_url: firebaseConfig.auth_provider_x509_cert_url,
      client_x509_cert_url: firebaseConfig.client_x509_cert_url
    }),
    databaseURL: firebaseConfig.databaseURL
  });
}

const db = admin.firestore();
const auth = admin.auth();

// CORS yapılandırması
router.use(cors({ origin: true }));
router.use(express.json());

// Rastgele 6 haneli kod oluşturma fonksiyonu
function generateRandomCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// E-posta gönderme yapılandırması
const transporter = nodemailer.createTransport({
  service: 'gmail', // veya başka bir e-posta servisi
  auth: {
    user: process.env.EMAIL_USER || 'gunubirlik.destek@gmail.com', // E-posta adresiniz
    pass: process.env.EMAIL_PASS || 'smyd uzoy psyt fsvd' // E-posta şifreniz veya uygulama şifresi
  },
  tls: {
    rejectUnauthorized: false // Geliştirme ortamında SSL sorunlarını önlemek için
  }
});

// Hesap silme kodu gönderme endpoint'i
router.post('/send-delete-code', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ success: false, message: 'E-posta adresi gereklidir' });
    }
    
    // Firebase'de kullanıcının varlığını kontrol et
    try {
      const userRecord = await auth.getUserByEmail(email);
      const userId = userRecord.uid;
      
      // Rastgele kod oluştur
      const deleteCode = generateRandomCode();
      const deleteCodeExpiry = Date.now() + 3600000; // 1 saat geçerli
      
      // Silme kodunu Firestore'a kaydet
      await db.collection('deleteCodes').doc(userId).set({
        code: deleteCode,
        email: email,
        expiry: deleteCodeExpiry,
        used: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // E-posta gönderme
      try {
        // E-posta HTML içeriğini oluştur
        let emailHtml = `
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hesap Silme İşlemi</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f9f9f9;
    }
    .container {
      max-width: 600px;
      margin: 40px auto;
      padding: 20px;
      background: #ffffff;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
      border-radius: 8px;
    }
    .header {
      text-align: center;
      padding: 20px 0;
      background-color: #dc3545;
      color: white;
      border-radius: 8px 8px 0 0;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
    }
    .content {
      padding: 20px;
      text-align: center;
    }
    .content p {
      font-size: 16px;
      color: #333;
      margin-bottom: 20px;
    }
    .code-box {
      background-color: #f5f5f5;
      padding: 15px;
      border-radius: 5px;
      text-align: center;
      font-size: 24px;
      letter-spacing: 5px;
      font-weight: bold;
      margin: 20px 0;
    }
    .warning {
      color: #dc3545;
      font-weight: bold;
    }
    .footer {
      padding: 20px;
      text-align: center;
      color: #888;
      font-size: 14px;
    }
    .footer a {
      color: #dc3545;
      text-decoration: none;
    }
    .divider {
      border-top: 1px solid #eee;
      margin: 30px 0;
    }
    .note {
      font-size: 14px;
      color: #666;
      font-style: italic;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Günübirlik - Hesap Silme İşlemi</h1>
    </div>
    <div class="content">
      <p>Merhaba,</p>
      <p>Hesap silme talebiniz için 6 haneli doğrulama kodunuz:</p>
      <div class="code-box">${deleteCode}</div>
      <p>Bu kod 1 saat boyunca geçerlidir.</p>
      
      <div class="divider"></div>
      
      <p class="warning">DİKKAT: Bu işlem geri alınamaz!</p>
      <p>Hesabınızı sildiğinizde, tüm kişisel verileriniz ve hesap bilgileriniz kalıcı olarak silinecektir.</p>
      <p>Eğer bu talebi siz yapmadıysanız, lütfen bu e-postayı dikkate almayın ve hesabınızın güvenliği için şifrenizi değiştirin.</p>
    </div>
    <div class="footer">
      <p>Teşekkürler, <br> Günübirlik Ekibi</p>
      <p><a href="https://gunubirlik.com">Web sitemizi ziyaret edin</a></p>
    </div>
  </div>
</body>
</html>`;
        
        const mailOptions = {
          from: `"Günübirlik Ekibi" <${process.env.EMAIL_USER || 'gunubirlik.destek@gmail.com'}>`,
          to: email,
          subject: 'Günübirlik - Hesap Silme Doğrulama Kodu',
          html: emailHtml
        };
        
        await transporter.sendMail(mailOptions);
        console.log(`Hesap silme kodu e-postası gönderildi: ${email}`);
      } catch (emailError) {
        console.error('E-posta gönderme hatası:', emailError);
        // E-posta gönderimi başarısız olsa bile işleme devam et
      }
      
      // Geliştirme amaçlı olarak kodu konsola yazdır
      console.log(`E-posta: ${email} için hesap silme kodu: ${deleteCode}`);
      
      res.status(200).json({ 
        success: true, 
        message: 'Hesap silme doğrulama kodu e-posta adresinize gönderildi',
        // Sadece geliştirme ortamında kodu doğrudan döndür
        deleteCode: process.env.NODE_ENV === 'development' ? deleteCode : undefined
      });
      
    } catch (authError) {
      console.error('Firebase Auth hatası:', authError);
      
      // Kullanıcı Firebase'de bulunamadı
      return res.status(404).json({ 
        success: false, 
        message: 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı. Lütfen kayıtlı e-posta adresinizi girin.' 
      });
    }
    
  } catch (error) {
    console.error('Hesap silme kodu gönderme hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Hesap silme kodu gönderilirken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Hesap silme kodunu doğrulama endpoint'i
router.post('/verify-delete-code', async (req, res) => {
  try {
    const { email, code } = req.body;
    
    if (!email || !code) {
      return res.status(400).json({ 
        success: false, 
        message: 'E-posta ve kod gereklidir' 
      });
    }
    
    try {
      // Firebase'den kullanıcıyı al
      const userRecord = await auth.getUserByEmail(email);
      const userId = userRecord.uid;
      
      // Firestore'dan silme kodunu al
      const deleteCodeDoc = await db.collection('deleteCodes').doc(userId).get();
      
      if (!deleteCodeDoc.exists) {
        return res.status(404).json({ 
          success: false, 
          message: 'Geçerli bir silme kodu bulunamadı. Lütfen önce hesap silme kodu talep edin.' 
        });
      }
      
      const deleteCodeData = deleteCodeDoc.data();
      
      // Kodun geçerliliğini kontrol et
      if (deleteCodeData.used) {
        return res.status(400).json({ 
          success: false, 
          message: 'Bu silme talebi daha önce kullanılmış. Lütfen yeni bir silme talebi oluşturun.' 
        });
      }
      
      if (Date.now() > deleteCodeData.expiry) {
        return res.status(400).json({ 
          success: false, 
          message: 'Kod süresi dolmuş. Lütfen yeni bir kod talep edin.' 
        });
      }
      
      if (deleteCodeData.code !== code) {
        return res.status(400).json({ 
          success: false, 
          message: 'Geçersiz kod. Lütfen doğru kodu girin.' 
        });
      }
      
      // Kodu doğrula ve token oluştur
      const deleteToken = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
      
      // Token'ı Firestore'a kaydet
      await db.collection('deleteCodes').doc(userId).update({
        deleteToken: deleteToken,
        tokenExpiry: Date.now() + 3600000, // 1 saat geçerli
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Hesap silme kodu doğrulandı. Kullanıcı: ${email}, Token: ${deleteToken}`);
      
      res.status(200).json({ 
        success: true, 
        message: 'Kod doğrulandı', 
        deleteToken: deleteToken,
        userId: userId
      });
      
    } catch (authError) {
      console.error('Firebase Auth hatası:', authError);
      return res.status(404).json({ 
        success: false, 
        message: 'Kullanıcı bulunamadı' 
      });
    }
    
  } catch (error) {
    console.error('Kod doğrulama hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Kod doğrulanırken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Hesap silme endpoint'i
router.post('/delete-account', async (req, res) => {
  try {
    const { userId, deleteToken, password } = req.body;
    
    if (!userId || !deleteToken) {
      return res.status(400).json({ 
        success: false, 
        message: 'Kullanıcı ID ve token gereklidir' 
      });
    }
    
    // Firestore'dan token'ı kontrol et
    const deleteCodeDoc = await db.collection('deleteCodes').doc(userId).get();
    
    if (!deleteCodeDoc.exists) {
      return res.status(404).json({ 
        success: false, 
        message: 'Geçerli bir silme talebi bulunamadı' 
      });
    }
    
    const deleteCodeData = deleteCodeDoc.data();
    
    // Token'ın geçerliliğini kontrol et
    if (deleteCodeData.used) {
      return res.status(400).json({ 
        success: false, 
        message: 'Bu silme talebi daha önce kullanılmış' 
      });
    }
    
    if (Date.now() > deleteCodeData.tokenExpiry) {
      return res.status(400).json({ 
        success: false, 
        message: 'Silme talebinin süresi dolmuş. Lütfen yeni bir kod talep edin.' 
      });
    }
    
    if (deleteCodeData.deleteToken !== deleteToken) {
      return res.status(400).json({ 
        success: false, 
        message: 'Geçersiz token. Lütfen tekrar deneyin.' 
      });
    }
    
    try {
      // Kullanıcının tüm verilerini sil
      await deleteUserData(userId);
      
      // Silme kodunu kullanıldı olarak işaretle
      await db.collection('deleteCodes').doc(userId).update({
        used: true,
        deletedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Kullanıcı ${userId} hesabı ve tüm verileri silindi`);
      
      // Hesap silindi e-postası gönder
      try {
        const mailOptions = {
          from: `"Günübirlik Ekibi" <${process.env.EMAIL_USER || 'gunubirlik.destek@gmail.com'}>`,
          to: deleteCodeData.email,
          subject: 'Günübirlik - Hesabınız Silindi',
          html: `
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hesap Silindi</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f9f9f9;
    }
    .container {
      max-width: 600px;
      margin: 40px auto;
      padding: 20px;
      background: #ffffff;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
      border-radius: 8px;
    }
    .header {
      text-align: center;
      padding: 20px 0;
      background-color: #dc3545;
      color: white;
      border-radius: 8px 8px 0 0;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
    }
    .content {
      padding: 20px;
      text-align: center;
    }
    .content p {
      font-size: 16px;
      color: #333;
      margin-bottom: 20px;
    }
    .success-icon {
      color: #dc3545;
      font-size: 48px;
      margin: 20px 0;
    }
    .footer {
      padding: 20px;
      text-align: center;
      color: #888;
      font-size: 14px;
    }
    .footer a {
      color: #dc3545;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Günübirlik</h1>
    </div>
    <div class="content">
      <div class="success-icon">✓</div>
      <p>Merhaba,</p>
      <p>Hesabınız ve tüm verileriniz başarıyla silinmiştir.</p>
      <p>Günübirlik hizmetlerimizi kullandığınız için teşekkür ederiz.</p>
      <p>Eğer bu işlemi siz yapmadıysanız, lütfen hemen bizimle iletişime geçin.</p>
    </div>
    <div class="footer">
      <p>Teşekkürler, <br> Günübirlik Ekibi</p>
      <p><a href="https://gunubirlik.com">Web sitemizi ziyaret edin</a></p>
    </div>
  </div>
</body>
</html>
          `
        };
        
        await transporter.sendMail(mailOptions);
        console.log(`Hesap silindi e-postası gönderildi: ${deleteCodeData.email}`);
      } catch (emailError) {
        console.error('E-posta gönderme hatası:', emailError);
        // E-posta gönderimi başarısız olsa bile işleme devam et
      }
      
      res.status(200).json({ 
        success: true, 
        message: 'Hesabınız ve tüm verileriniz başarıyla silindi' 
      });
      
    } catch (deleteError) {
      console.error('Kullanıcı silme hatası:', deleteError);
      return res.status(500).json({ 
        success: false, 
        message: 'Hesap silinirken bir hata oluştu', 
        error: deleteError.message 
      });
    }
    
  } catch (error) {
    console.error('Hesap silme hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Hesap silinirken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Kullanıcının tüm verilerini silme fonksiyonu
async function deleteUserData(userId) {
  try {
    // Kullanıcı belgesini al
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new Error('Kullanıcı bulunamadı');
    }
    
    const userData = userDoc.data();
    const email = userData.email;
    
    // Kullanıcının iş ilanlarını bul ve sil
    const jobsQuery = await db.collection('jobs').where('userId', '==', userId).get();
    const jobDeletes = jobsQuery.docs.map(doc => db.collection('jobs').doc(doc.id).delete());
    
    // Kullanıcının mesajlarını bul ve sil
    const messagesQuery = await db.collection('messages').where('senderId', '==', userId).get();
    const messageDeletes = messagesQuery.docs.map(doc => db.collection('messages').doc(doc.id).delete());
    
    // Kullanıcının alıcı olduğu mesajları bul ve sil
    const receivedMessagesQuery = await db.collection('messages').where('receiverId', '==', userId).get();
    const receivedMessageDeletes = receivedMessagesQuery.docs.map(doc => db.collection('messages').doc(doc.id).delete());
    
    // QR oturumlarını bul ve sil
    const qrSessionsQuery = await db.collection('qr_sessions').where('userId', '==', userId).get();
    const qrSessionDeletes = qrSessionsQuery.docs.map(doc => db.collection('qr_sessions').doc(doc.id).delete());
    
    // Cihaz tokenlarını bul ve sil
    const deviceTokensQuery = await db.collection('device_tokens').where('userId', '==', userId).get();
    const deviceTokenDeletes = deviceTokensQuery.docs.map(doc => db.collection('device_tokens').doc(doc.id).delete());
    
    // Favorileri bul ve sil
    const favoritesQuery = await db.collection('favorites').where('userId', '==', userId).get();
    const favoriteDeletes = favoritesQuery.docs.map(doc => db.collection('favorites').doc(doc.id).delete());
    
    // Bildirimleri bul ve sil
    const notificationsQuery = await db.collection('notifications').where('userId', '==', userId).get();
    const notificationDeletes = notificationsQuery.docs.map(doc => db.collection('notifications').doc(doc.id).delete());
    
    // Doğrulama kodlarını bul ve sil
    const verificationCodesQuery = await db.collection('verification_codes').where('userId', '==', userId).get();
    const verificationCodeDeletes = verificationCodesQuery.docs.map(doc => db.collection('verification_codes').doc(doc.id).delete());
    
    // Kullanıcı ayarlarını sil
    const userSettingsDeletes = db.collection('userSettings').doc(userId).delete().catch(() => {});
    
    // Tüm silme işlemlerini bekle
    await Promise.all([
      ...jobDeletes,
      ...messageDeletes,
      ...receivedMessageDeletes,
      ...qrSessionDeletes,
      ...deviceTokenDeletes,
      ...favoriteDeletes,
      ...notificationDeletes,
      ...verificationCodeDeletes,
      userSettingsDeletes
    ]);
    
    // Son olarak kullanıcı belgesini sil
    await db.collection('users').doc(userId).delete();
    
    // Firebase Authentication'dan kullanıcıyı sil
    await auth.deleteUser(userId);
    
    console.log(`Kullanıcı ${userId} ve tüm ilişkili verileri silindi`);
    
    return true;
  } catch (error) {
    console.error('Kullanıcı verilerini silme hatası:', error);
    throw error;
  }
}

module.exports = router; 