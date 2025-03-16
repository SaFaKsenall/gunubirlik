const express = require('express');
const router = express.Router();
const admin = require('firebase-admin'); // Firebase Admin SDK'yı aktif hale getirdim
const nodemailer = require('nodemailer');
const cors = require('cors');
const fetch = require('node-fetch'); // HTTP istekleri için node-fetch ekledim

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

// Geçici veritabanı (Firebase kullanılmadığında yedek olarak)
const tempDB = {
  users: [
    { id: 'user1', email: 'test@example.com', name: 'Test User' },
    // Test için gerçek e-posta adresleri (kendi e-posta adresinizle değiştirin)
    { id: 'user2', email: 'gunubirlik.destek@gmail.com', name: 'Web Chat' },
    { id: 'user3', email: 'info@gunubirlik.com', name: 'Günübirlik' }
  ],
  resetCodes: {}
};

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

// Şifre sıfırlama kodu gönderme endpoint'i
router.post('/send-reset-code', async (req, res) => {
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
      const resetCode = generateRandomCode();
      const resetCodeExpiry = Date.now() + 3600000; // 1 saat geçerli
      
      // Sıfırlama kodunu Firestore'a kaydet
      await db.collection('resetCodes').doc(userId).set({
        code: resetCode,
        email: email,
        expiry: resetCodeExpiry,
        used: false,
        codeUsed: false,
        linkUsed: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Şifre sıfırlama bağlantısı
      const resetLink = `https://gunubirlik.com/reset-password?email=${encodeURIComponent(email)}&code=${resetCode}`;
      
      // Firebase şifre sıfırlama bağlantısı
      let firebaseResetLink = null;
      
      try {
        // Firebase şifre sıfırlama bağlantısı oluştur
        // Not: Bu URL'nin Firebase konsolunda izin verilen URL'ler listesinde olması gerekir
        const actionCodeSettings = {
          // Firebase konsolunda izin verilen bir URL kullanın
          // Eğer localhost kullanıyorsanız, Firebase konsolunda bunu whitelist'e eklemeniz gerekir
          url: `https://jobapp-14c52.firebaseapp.com/login?email=${encodeURIComponent(email)}&userId=${encodeURIComponent(userId)}&markLinkUsed=true`,
          handleCodeInApp: false
        };
        
        // Firebase şifre sıfırlama bağlantısını oluştur
        firebaseResetLink = await auth.generatePasswordResetLink(email, actionCodeSettings);
        
        // Firebase bağlantısını bizim kontrol sistemimizle sarmalayalım
        // Böylece kullanıcı önce bizim kontrol sayfamıza gelecek
        const encodedFirebaseLink = encodeURIComponent(firebaseResetLink);
        firebaseResetLink = `${req.protocol}://${req.get('host')}/api/reset-password/firebase-reset-handler?email=${encodeURIComponent(email)}&firebaseLink=${encodedFirebaseLink}`;
        
        console.log(`Firebase şifre sıfırlama bağlantısı oluşturuldu: ${firebaseResetLink}`);
      } catch (firebaseError) {
        console.error('Firebase şifre sıfırlama bağlantısı oluşturma hatası:', firebaseError);
        // Hata durumunda Firebase bağlantısı oluşturulamadı, sadece kendi bağlantımızı kullanacağız
        firebaseResetLink = null;
      }
      
      // E-posta gönderme
      try {
        // E-posta HTML içeriğini oluştur
        let emailHtml = `
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Şifre Sıfırlama</title>
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
      background-color: #6a1b9a;
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
    .reset-link {
      display: inline-block;
      text-decoration: none;
      font-size: 16px;
      padding: 12px 20px;
      color: white;
      background-color: #6a1b9a;
      border-radius: 4px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      transition: background-color 0.3s, transform 0.2s;
      margin-top: 20px;
    }
    .reset-link:hover {
      background-color: #5c1786;
      transform: scale(1.05);
    }
    .footer {
      padding: 20px;
      text-align: center;
      color: #888;
      font-size: 14px;
    }
    .footer a {
      color: #6a1b9a;
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
      <h1>Günübirlik</h1>
    </div>
    <div class="content">
      <p>Merhaba,</p>
      <p>Şifre sıfırlama talebiniz için 6 haneli kodunuz:</p>
      <div class="code-box">${resetCode}</div>
      <p>Bu kod 1 saat boyunca geçerlidir.</p>
      <p class="note">Not: Alternatif yöntemlerden birini kullandığınızda, diğer yöntem otomatik olarak devre dışı kalacaktır.</p>
      
      <div class="divider"></div>
      
      <p>Alternatif olarak, aşağıdaki bağlantıyı kullanarak da şifrenizi sıfırlayabilirsiniz:</p>
      <a href="${resetLink}" class="reset-link">Şifremi Sıfırla</a>`;
        
        // Firebase bağlantısı başarıyla oluşturulduysa ekle
        if (firebaseResetLink) {
          emailHtml += `
        <div class="divider"></div>
        
        <p>Alternatif olarak, aşağıdaki Firebase bağlantısını kullanarak da şifrenizi sıfırlayabilirsiniz:</p>
        <a href="${firebaseResetLink}" class="reset-link">Firebase ile Şifremi Sıfırla</a>`;
        }
        
        // E-posta HTML içeriğini tamamla
        emailHtml += `
        <p>Eğer bu talebi siz yapmadıysanız, lütfen bu e-postayı dikkate almayın.</p>
      </div>
      <div class="footer">
        <p>Teşekkürler, <br> Günübirlik Ekibi</p>
        <p><a href="https://gunubirlik.com">Web sitemizi ziyaret edin</a></p>
      </div>
    </div>
  </div>
</body>
</html>`;
        
        const mailOptions = {
          from: `"Günübirlik Ekibi" <${process.env.EMAIL_USER || 'gunubirlik.destek@gmail.com'}>`,
          to: email,
          subject: 'Günübirlik - Şifre Sıfırlama Kodu',
          html: emailHtml
        };
        
        await transporter.sendMail(mailOptions);
        console.log(`E-posta gönderildi: ${email}`);
      } catch (emailError) {
        console.error('E-posta gönderme hatası:', emailError);
        // E-posta gönderimi başarısız olsa bile işleme devam et
      }
      
      // Geliştirme amaçlı olarak kodu konsola yazdır
      console.log(`E-posta: ${email} için sıfırlama kodu: ${resetCode}`);
      if (firebaseResetLink) {
        console.log(`Firebase şifre sıfırlama bağlantısı: ${firebaseResetLink}`);
      }
      
      res.status(200).json({ 
        success: true, 
        message: 'Şifre sıfırlama kodu e-posta adresinize gönderildi',
        // Sadece geliştirme ortamında kodu doğrudan döndür
        resetCode: process.env.NODE_ENV === 'development' ? resetCode : undefined
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
    console.error('Şifre sıfırlama kodu gönderme hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Şifre sıfırlama kodu gönderilirken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Şifre sıfırlama kodunu doğrulama endpoint'i
router.post('/verify-reset-code', async (req, res) => {
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
      
      // Firestore'dan sıfırlama kodunu al
      const resetCodeDoc = await db.collection('resetCodes').doc(userId).get();
      
      if (!resetCodeDoc.exists) {
        return res.status(404).json({ 
          success: false, 
          message: 'Geçerli bir sıfırlama kodu bulunamadı. Lütfen önce şifre sıfırlama kodu talep edin.' 
        });
      }
      
      const resetCodeData = resetCodeDoc.data();
      
      // Kodun geçerliliğini kontrol et
      if (resetCodeData.used) {
        return res.status(400).json({ 
          success: false, 
          message: 'Bu sıfırlama talebi daha önce kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      // Alternatif link kullanılmış mı kontrol et
      if (resetCodeData.linkUsed) {
        return res.status(400).json({ 
          success: false, 
          message: 'Bu sıfırlama talebi için alternatif bağlantı zaten kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      if (Date.now() > resetCodeData.expiry) {
        return res.status(400).json({ 
          success: false, 
          message: 'Kod süresi dolmuş. Lütfen yeni bir kod talep edin.' 
        });
      }
      
      if (resetCodeData.code !== code) {
        return res.status(400).json({ 
          success: false, 
          message: 'Geçersiz kod. Lütfen doğru kodu girin.' 
        });
      }
      
      // Kodu doğrula ve token oluştur
      const resetToken = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
      
      // Token'ı Firestore'a kaydet ve kod kullanıldı olarak işaretle
      await db.collection('resetCodes').doc(userId).update({
        resetToken: resetToken,
        tokenExpiry: Date.now() + 3600000, // 1 saat geçerli
        codeUsed: true, // Kod kullanıldı olarak işaretle
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Kod doğrulandı. Kullanıcı: ${email}, Token: ${resetToken}`);
      
      res.status(200).json({ 
        success: true, 
        message: 'Kod doğrulandı', 
        resetToken: resetToken,
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

// Firebase şifre sıfırlama bağlantısı kullanıldığını işaretlemek için endpoint
router.post('/mark-link-used', async (req, res) => {
  try {
    const { email, userId } = req.body;
    
    if (!email && !userId) {
      return res.status(400).json({ 
        success: false, 
        message: 'E-posta adresi veya kullanıcı ID gereklidir' 
      });
    }
    
    try {
      let userIdToUse = userId;
      
      // Eğer userId verilmemişse, email ile kullanıcıyı bul
      if (!userIdToUse) {
        const userRecord = await auth.getUserByEmail(email);
        userIdToUse = userRecord.uid;
      }
      
      // Firestore'dan sıfırlama kodunu al
      const resetCodeDoc = await db.collection('resetCodes').doc(userIdToUse).get();
      
      if (!resetCodeDoc.exists) {
        return res.status(404).json({ 
          success: false, 
          message: 'Geçerli bir sıfırlama talebi bulunamadı' 
        });
      }
      
      const resetCodeData = resetCodeDoc.data();
      
      // Kod kullanılmış mı kontrol et
      if (resetCodeData.codeUsed) {
        return res.status(400).json({ 
          success: false, 
          message: 'Bu sıfırlama talebi için kod zaten kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      if (resetCodeData.used) {
        return res.status(400).json({ 
          success: false, 
          message: 'Bu sıfırlama talebi daha önce kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      if (Date.now() > resetCodeData.expiry) {
        return res.status(400).json({ 
          success: false, 
          message: 'Sıfırlama talebinin süresi dolmuş. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      // Link kullanıldı ve şifre sıfırlama tamamlandı olarak işaretle
      await db.collection('resetCodes').doc(userIdToUse).update({
        linkUsed: true,
        used: true, // Şifre sıfırlama işlemi tamamlandı olarak işaretle
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Firebase şifre sıfırlama bağlantısı kullanıldı. Kullanıcı: ${email || userIdToUse}`);
      
      res.status(200).json({ 
        success: true, 
        message: 'Şifre sıfırlama bağlantısı kullanıldı olarak işaretlendi' 
      });
      
    } catch (authError) {
      console.error('Firebase Auth hatası:', authError);
      return res.status(404).json({ 
        success: false, 
        message: 'Kullanıcı bulunamadı' 
      });
    }
    
  } catch (error) {
    console.error('Bağlantı kullanıldı işaretleme hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Bağlantı kullanıldı olarak işaretlenirken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Firebase şifre sıfırlama öncesi kontrol endpoint'i
router.post('/check-before-firebase-reset', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ 
        success: false, 
        message: 'E-posta adresi gereklidir' 
      });
    }
    
    try {
      // Firebase'den kullanıcıyı al
      const userRecord = await auth.getUserByEmail(email);
      const userId = userRecord.uid;
      
      // Firestore'dan sıfırlama kodunu al
      const resetCodeDoc = await db.collection('resetCodes').doc(userId).get();
      
      // Eğer sıfırlama talebi yoksa, kullanıcı doğrudan Firebase ile sıfırlama yapabilir
      if (!resetCodeDoc.exists) {
        return res.status(200).json({ 
          success: true, 
          canReset: true,
          message: 'Şifre sıfırlama işlemi yapılabilir' 
        });
      }
      
      const resetCodeData = resetCodeDoc.data();
      
      // Kod kullanılmış mı kontrol et
      if (resetCodeData.codeUsed || resetCodeData.used) {
        return res.status(200).json({ 
          success: true, 
          canReset: false,
          message: 'Bu e-posta adresi için şifre sıfırlama işlemi zaten tamamlanmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
        });
      }
      
      // Süre dolmuş mu kontrol et
      if (Date.now() > resetCodeData.expiry) {
        return res.status(200).json({ 
          success: true, 
          canReset: true,
          message: 'Şifre sıfırlama işlemi yapılabilir' 
        });
      }
      
      // Şifre sıfırlama yapılabilir
      return res.status(200).json({ 
        success: true, 
        canReset: true,
        message: 'Şifre sıfırlama işlemi yapılabilir' 
      });
      
    } catch (authError) {
      console.error('Firebase Auth hatası:', authError);
      return res.status(404).json({ 
        success: false, 
        message: 'Kullanıcı bulunamadı' 
      });
    }
    
  } catch (error) {
    console.error('Şifre sıfırlama kontrol hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Şifre sıfırlama kontrolü yapılırken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Firebase şifre sıfırlama callback endpoint'i - Frontend'den çağrılacak
router.get('/firebase-reset-callback', async (req, res) => {
  try {
    const { email, userId, markLinkUsed } = req.query;
    
    if (markLinkUsed === 'true' && (email || userId)) {
      // Arka planda API çağrısı yap
      try {
        const response = await fetch(`${req.protocol}://${req.get('host')}/api/reset-password/mark-link-used`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ email, userId }),
        });
        
        const data = await response.json();
        console.log('Firebase callback işlemi sonucu:', data);
      } catch (fetchError) {
        console.error('Firebase callback işlemi hatası:', fetchError);
      }
    }
    
    // Kullanıcıya HTML sayfası döndür
    res.send(`
      <!DOCTYPE html>
      <html lang="tr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Şifre Sıfırlama Tamamlandı</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f5f5f5;
          }
          .container {
            text-align: center;
            padding: 30px;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 500px;
          }
          h1 {
            color: #6a1b9a;
          }
          .success-icon {
            font-size: 64px;
            color: #4caf50;
            margin: 20px 0;
          }
          .error-icon {
            font-size: 64px;
            color: #f44336;
            margin: 20px 0;
          }
          p {
            margin: 15px 0;
            color: #555;
          }
          .button {
            display: inline-block;
            background-color: #6a1b9a;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 20px;
            font-weight: bold;
          }
          .button:hover {
            background-color: #5c1786;
          }
        </style>
      </head>
      <body>
        <div class="container" id="container">
          <div id="loadingMessage">
            <h1>Şifre Sıfırlama Kontrol Ediliyor</h1>
            <p>Lütfen bekleyin...</p>
          </div>
          <div id="successMessage" style="display: none;">
            <h1>Şifre Sıfırlama Tamamlandı</h1>
            <div class="success-icon">✓</div>
            <p>Şifreniz başarıyla sıfırlandı.</p>
            <p>Artık yeni şifrenizle giriş yapabilirsiniz.</p>
            <p>Diğer şifre sıfırlama yöntemleri otomatik olarak devre dışı bırakılmıştır.</p>
            <a href="https://gunubirlik.com/login" class="button">Giriş Sayfasına Git</a>
          </div>
          <div id="errorMessage" style="display: none;">
            <h1>Şifre Sıfırlama Hatası</h1>
            <div class="error-icon">✗</div>
            <p id="errorText">Bu şifre sıfırlama bağlantısı kullanılamaz.</p>
            <p>Lütfen yeni bir şifre sıfırlama talebi oluşturun.</p>
            <a href="https://gunubirlik.com/forgot-password" class="button">Şifremi Unuttum</a>
          </div>
        </div>
        <script>
          // E-posta adresini URL'den al
          const urlParams = new URLSearchParams(window.location.search);
          const email = urlParams.get('email');
          
          // Şifre sıfırlama durumunu kontrol et
          async function checkResetStatus() {
            try {
              if (!email) {
                showError('E-posta adresi bulunamadı.');
                return;
              }
              
              const response = await fetch('/api/reset-password/check-before-firebase-reset', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email }),
              });
              
              const data = await response.json();
              
              if (!data.success) {
                showError(data.message || 'Şifre sıfırlama kontrolü yapılırken bir hata oluştu.');
                return;
              }
              
              if (!data.canReset) {
                showError(data.message || 'Bu şifre sıfırlama bağlantısı kullanılamaz.');
                return;
              }
              
              // Şifre sıfırlama başarılı
              document.getElementById('loadingMessage').style.display = 'none';
              document.getElementById('successMessage').style.display = 'block';
              
              // 3 saniye sonra otomatik olarak login sayfasına yönlendir
              setTimeout(function() {
                window.location.href = 'https://gunubirlik.com/login?resetCompleted=true';
              }, 3000);
              
            } catch (error) {
              console.error('Şifre sıfırlama kontrol hatası:', error);
              showError('Şifre sıfırlama kontrolü yapılırken bir hata oluştu.');
            }
          }
          
          // Hata mesajı göster
          function showError(message) {
            document.getElementById('loadingMessage').style.display = 'none';
            document.getElementById('errorText').textContent = message;
            document.getElementById('errorMessage').style.display = 'block';
          }
          
          // Sayfa yüklendiğinde kontrol et
          checkResetStatus();
        </script>
      </body>
      </html>
    `);
    
  } catch (error) {
    console.error('Firebase callback hatası:', error);
    res.redirect('https://gunubirlik.com/login?resetError=true');
  }
});

// Şifre sıfırlama bağlantısı kullanıldığını kontrol eden endpoint
router.get('/check-reset-status', async (req, res) => {
  try {
    const { email, code } = req.query;
    
    if (!email) {
      return res.status(400).json({ 
        success: false, 
        message: 'E-posta adresi gereklidir' 
      });
    }
    
    try {
      // Firebase'den kullanıcıyı al
      const userRecord = await auth.getUserByEmail(email);
      const userId = userRecord.uid;
      
      // Firestore'dan sıfırlama kodunu al
      const resetCodeDoc = await db.collection('resetCodes').doc(userId).get();
      
      if (!resetCodeDoc.exists) {
        return res.status(404).json({ 
          success: false, 
          message: 'Geçerli bir sıfırlama talebi bulunamadı' 
        });
      }
      
      const resetCodeData = resetCodeDoc.data();
      
      // Sıfırlama durumunu kontrol et
      const status = {
        isValid: !resetCodeData.used && !resetCodeData.codeUsed && !resetCodeData.linkUsed && Date.now() <= resetCodeData.expiry,
        isExpired: Date.now() > resetCodeData.expiry,
        isUsed: resetCodeData.used,
        isCodeUsed: resetCodeData.codeUsed,
        isLinkUsed: resetCodeData.linkUsed,
        code: code === resetCodeData.code ? true : false
      };
      
      res.status(200).json({ 
        success: true, 
        status: status
      });
      
    } catch (authError) {
      console.error('Firebase Auth hatası:', authError);
      return res.status(404).json({ 
        success: false, 
        message: 'Kullanıcı bulunamadı' 
      });
    }
    
  } catch (error) {
    console.error('Sıfırlama durumu kontrol hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Sıfırlama durumu kontrol edilirken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Şifre sıfırlama endpoint'i
router.post('/reset-password', async (req, res) => {
  try {
    const { userId, resetToken, newPassword } = req.body;
    
    if (!userId || !resetToken || !newPassword) {
      return res.status(400).json({ 
        success: false, 
        message: 'Kullanıcı ID, token ve yeni şifre gereklidir' 
      });
    }
    
    // Firestore'dan token'ı kontrol et
    const resetCodeDoc = await db.collection('resetCodes').doc(userId).get();
    
    if (!resetCodeDoc.exists) {
      return res.status(404).json({ 
        success: false, 
        message: 'Geçerli bir sıfırlama talebi bulunamadı' 
      });
    }
    
    const resetCodeData = resetCodeDoc.data();
    
    // Token'ın geçerliliğini kontrol et
    if (resetCodeData.used) {
      return res.status(400).json({ 
        success: false, 
        message: 'Bu sıfırlama talebi daha önce kullanılmış' 
      });
    }
    
    // Alternatif link kullanılmış mı kontrol et
    if (resetCodeData.linkUsed) {
      return res.status(400).json({ 
        success: false, 
        message: 'Bu sıfırlama talebi için alternatif bağlantı zaten kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.' 
      });
    }
    
    if (Date.now() > resetCodeData.tokenExpiry) {
      return res.status(400).json({ 
        success: false, 
        message: 'Sıfırlama talebinin süresi dolmuş. Lütfen yeni bir kod talep edin.' 
      });
    }
    
    if (resetCodeData.resetToken !== resetToken) {
      return res.status(400).json({ 
        success: false, 
        message: 'Geçersiz token. Lütfen tekrar deneyin.' 
      });
    }
    
    try {
      // Firebase Authentication ile şifreyi güncelle
      await auth.updateUser(userId, {
        password: newPassword
      });
      
      // Sıfırlama kodunu kullanıldı olarak işaretle
      await db.collection('resetCodes').doc(userId).update({
        used: true,
        passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Kullanıcı ${userId} için şifre güncellendi`);
      
      // Şifre değiştirildiğine dair e-posta gönder
      try {
        const mailOptions = {
          from: `"Günübirlik Ekibi" <${process.env.EMAIL_USER || 'gunubirlik.destek@gmail.com'}>`,
          to: resetCodeData.email,
          subject: 'Günübirlik - Şifreniz Değiştirildi',
          html: `
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Şifre Değişikliği</title>
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
      background-color: #6a1b9a;
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
      color: #4caf50;
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
      color: #6a1b9a;
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
      <p>Şifreniz başarıyla değiştirildi.</p>
      <p>Eğer bu değişikliği siz yapmadıysanız, lütfen hemen bizimle iletişime geçin.</p>
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
        console.log(`Şifre değişikliği e-postası gönderildi: ${resetCodeData.email}`);
      } catch (emailError) {
        console.error('E-posta gönderme hatası:', emailError);
        // E-posta gönderimi başarısız olsa bile işleme devam et
      }
      
      res.status(200).json({ 
        success: true, 
        message: 'Şifre başarıyla sıfırlandı' 
      });
      
    } catch (authError) {
      console.error('Firebase Auth şifre güncelleme hatası:', authError);
      return res.status(500).json({ 
        success: false, 
        message: 'Şifre güncellenirken bir hata oluştu', 
        error: authError.message 
      });
    }
    
  } catch (error) {
    console.error('Şifre sıfırlama hatası:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Şifre sıfırlanırken bir hata oluştu', 
      error: error.message 
    });
  }
});

// Örnek şifre sıfırlama sayfası (Frontend geliştirme için)
router.get('/reset-password-example', (req, res) => {
  const { email, code } = req.query;
  
  res.send(`
    <!DOCTYPE html>
    <html lang="tr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Şifre Sıfırlama</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 0;
          padding: 0;
          background-color: #f5f5f5;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
        }
        .container {
          max-width: 500px;
          width: 100%;
          padding: 30px;
          background-color: white;
          border-radius: 8px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
          color: #6a1b9a;
          text-align: center;
          margin-bottom: 30px;
        }
        .form-group {
          margin-bottom: 20px;
        }
        label {
          display: block;
          margin-bottom: 8px;
          font-weight: bold;
          color: #333;
        }
        input {
          width: 100%;
          padding: 12px;
          border: 1px solid #ddd;
          border-radius: 4px;
          font-size: 16px;
          box-sizing: border-box;
        }
        button {
          width: 100%;
          padding: 12px;
          background-color: #6a1b9a;
          color: white;
          border: none;
          border-radius: 4px;
          font-size: 16px;
          cursor: pointer;
          font-weight: bold;
        }
        button:hover {
          background-color: #5c1786;
        }
        .alert {
          padding: 12px;
          border-radius: 4px;
          margin-bottom: 20px;
          display: none;
        }
        .alert-error {
          background-color: #ffebee;
          color: #c62828;
          border: 1px solid #ef9a9a;
        }
        .alert-success {
          background-color: #e8f5e9;
          color: #2e7d32;
          border: 1px solid #a5d6a7;
        }
        .alert-warning {
          background-color: #fff8e1;
          color: #f57f17;
          border: 1px solid #ffe082;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Şifre Sıfırlama</h1>
        
        <div id="alertBox" class="alert"></div>
        
        <div id="resetForm">
          <div class="form-group">
            <label for="password">Yeni Şifre</label>
            <input type="password" id="password" placeholder="Yeni şifrenizi girin" required>
          </div>
          
          <div class="form-group">
            <label for="confirmPassword">Şifre Tekrar</label>
            <input type="password" id="confirmPassword" placeholder="Yeni şifrenizi tekrar girin" required>
          </div>
          
          <button type="button" id="resetButton">Şifremi Sıfırla</button>
        </div>
      </div>
      
      <script>
        // Sayfa yüklendiğinde çalışacak kod
        document.addEventListener('DOMContentLoaded', function() {
          const email = '${email || ""}';
          const code = '${code || ""}';
          const alertBox = document.getElementById('alertBox');
          const resetForm = document.getElementById('resetForm');
          const resetButton = document.getElementById('resetButton');
          
          // Şifre sıfırlama durumunu kontrol et
          if (email) {
            checkResetStatus(email, code);
          } else {
            showAlert('E-posta adresi eksik. Lütfen geçerli bir şifre sıfırlama bağlantısı kullanın.', 'error');
            resetForm.style.display = 'none';
          }
          
          // Şifre sıfırlama butonuna tıklandığında
          resetButton.addEventListener('click', function() {
            const password = document.getElementById('password').value;
            const confirmPassword = document.getElementById('confirmPassword').value;
            
            // Şifre kontrolü
            if (!password || password.length < 6) {
              showAlert('Şifre en az 6 karakter olmalıdır.', 'error');
              return;
            }
            
            if (password !== confirmPassword) {
              showAlert('Şifreler eşleşmiyor.', 'error');
              return;
            }
            
            // Şifre sıfırlama isteği gönder
            resetPassword(email, code, password);
          });
          
          // Şifre sıfırlama durumunu kontrol eden fonksiyon
          async function checkResetStatus(email, code) {
            try {
              const response = await fetch(\`/api/reset-password/check-reset-status?email=\${encodeURIComponent(email)}&code=\${encodeURIComponent(code)}\`);
              const data = await response.json();
              
              if (!data.success) {
                showAlert(data.message, 'error');
                resetForm.style.display = 'none';
                return;
              }
              
              const status = data.status;
              
              if (!status.isValid) {
                if (status.isExpired) {
                  showAlert('Şifre sıfırlama bağlantısının süresi dolmuş. Lütfen yeni bir sıfırlama talebi oluşturun.', 'error');
                } else if (status.isUsed || status.isCodeUsed || status.isLinkUsed) {
                  showAlert('Bu şifre sıfırlama bağlantısı daha önce kullanılmış. Lütfen yeni bir sıfırlama talebi oluşturun.', 'error');
                } else if (!status.code) {
                  showAlert('Geçersiz şifre sıfırlama kodu.', 'error');
                } else {
                  showAlert('Şifre sıfırlama bağlantısı geçersiz.', 'error');
                }
                resetForm.style.display = 'none';
              }
            } catch (error) {
              console.error('Şifre sıfırlama durumu kontrol hatası:', error);
              showAlert('Şifre sıfırlama durumu kontrol edilirken bir hata oluştu.', 'error');
              resetForm.style.display = 'none';
            }
          }
          
          // Şifre sıfırlama isteği gönderen fonksiyon
          async function resetPassword(email, code, newPassword) {
            try {
              // Önce kullanıcı ID ve token al
              const tokenResponse = await fetch('/api/reset-password/verify-reset-code', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email, code }),
              });
              
              const tokenData = await tokenResponse.json();
              
              if (!tokenData.success) {
                showAlert(tokenData.message, 'error');
                return;
              }
              
              // Şifre sıfırlama isteği gönder
              const resetResponse = await fetch('/api/reset-password/reset-password', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ 
                  userId: tokenData.userId, 
                  resetToken: tokenData.resetToken, 
                  newPassword: newPassword 
                }),
              });
              
              const resetData = await resetResponse.json();
              
              if (!resetData.success) {
                showAlert(resetData.message, 'error');
                return;
              }
              
              // Başarılı
              showAlert('Şifreniz başarıyla sıfırlandı. Giriş sayfasına yönlendiriliyorsunuz...', 'success');
              resetForm.style.display = 'none';
              
              // 3 saniye sonra giriş sayfasına yönlendir
              setTimeout(function() {
                window.location.href = 'https://gunubirlik.com/login?resetCompleted=true';
              }, 3000);
              
            } catch (error) {
              console.error('Şifre sıfırlama hatası:', error);
              showAlert('Şifre sıfırlanırken bir hata oluştu.', 'error');
            }
          }
          
          // Uyarı mesajı gösteren fonksiyon
          function showAlert(message, type) {
            alertBox.textContent = message;
            alertBox.className = 'alert';
            alertBox.classList.add(\`alert-\${type}\`);
            alertBox.style.display = 'block';
          }
        });
      </script>
    </body>
    </html>
  `);
});

// Firebase şifre sıfırlama bağlantısı işleyici endpoint'i
router.get('/firebase-reset-handler', async (req, res) => {
  try {
    const { email, firebaseLink } = req.query;
    
    if (!email || !firebaseLink) {
      return res.status(400).send(`
        <!DOCTYPE html>
        <html lang="tr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Şifre Sıfırlama Hatası</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              margin: 0;
              background-color: #f5f5f5;
            }
            .container {
              text-align: center;
              padding: 30px;
              background-color: white;
              border-radius: 8px;
              box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              max-width: 500px;
            }
            h1 {
              color: #6a1b9a;
            }
            .error-icon {
              font-size: 64px;
              color: #f44336;
              margin: 20px 0;
            }
            p {
              margin: 15px 0;
              color: #555;
            }
            .button {
              display: inline-block;
              background-color: #6a1b9a;
              color: white;
              padding: 12px 24px;
              text-decoration: none;
              border-radius: 4px;
              margin-top: 20px;
              font-weight: bold;
            }
            .button:hover {
              background-color: #5c1786;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Şifre Sıfırlama Hatası</h1>
            <div class="error-icon">✗</div>
            <p>Geçersiz şifre sıfırlama bağlantısı.</p>
            <p>Lütfen yeni bir şifre sıfırlama talebi oluşturun.</p>
            <a href="https://gunubirlik.com/forgot-password" class="button">Şifremi Unuttum</a>
          </div>
        </body>
        </html>
      `);
    }
    
    try {
      // Şifre sıfırlama durumunu kontrol et
      const response = await fetch(`${req.protocol}://${req.get('host')}/api/reset-password/check-before-firebase-reset`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email }),
      });
      
      const data = await response.json();
      
      if (!data.success || !data.canReset) {
        return res.send(`
          <!DOCTYPE html>
          <html lang="tr">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Şifre Sıfırlama Hatası</title>
            <style>
              body {
                font-family: Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background-color: #f5f5f5;
              }
              .container {
                text-align: center;
                padding: 30px;
                background-color: white;
                border-radius: 8px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                max-width: 500px;
              }
              h1 {
                color: #6a1b9a;
              }
              .error-icon {
                font-size: 64px;
                color: #f44336;
                margin: 20px 0;
              }
              p {
                margin: 15px 0;
                color: #555;
              }
              .button {
                display: inline-block;
                background-color: #6a1b9a;
                color: white;
                padding: 12px 24px;
                text-decoration: none;
                border-radius: 4px;
                margin-top: 20px;
                font-weight: bold;
              }
              .button:hover {
                background-color: #5c1786;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h1>Şifre Sıfırlama Hatası</h1>
              <div class="error-icon">✗</div>
              <p>${data.message || 'Bu şifre sıfırlama bağlantısı kullanılamaz.'}</p>
              <p>Lütfen yeni bir şifre sıfırlama talebi oluşturun.</p>
              <a href="https://gunubirlik.com/forgot-password" class="button">Şifremi Unuttum</a>
            </div>
          </body>
          </html>
        `);
      }
      
      // Şifre sıfırlama yapılabilir, Firebase bağlantısına yönlendir
      res.redirect(decodeURIComponent(firebaseLink));
      
    } catch (error) {
      console.error('Firebase şifre sıfırlama işleyici hatası:', error);
      return res.status(500).send(`
        <!DOCTYPE html>
        <html lang="tr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Şifre Sıfırlama Hatası</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              margin: 0;
              background-color: #f5f5f5;
            }
            .container {
              text-align: center;
              padding: 30px;
              background-color: white;
              border-radius: 8px;
              box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              max-width: 500px;
            }
            h1 {
              color: #6a1b9a;
            }
            .error-icon {
              font-size: 64px;
              color: #f44336;
              margin: 20px 0;
            }
            p {
              margin: 15px 0;
              color: #555;
            }
            .button {
              display: inline-block;
              background-color: #6a1b9a;
              color: white;
              padding: 12px 24px;
              text-decoration: none;
              border-radius: 4px;
              margin-top: 20px;
              font-weight: bold;
            }
            .button:hover {
              background-color: #5c1786;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Şifre Sıfırlama Hatası</h1>
            <div class="error-icon">✗</div>
            <p>Şifre sıfırlama işlemi sırasında bir hata oluştu.</p>
            <p>Lütfen yeni bir şifre sıfırlama talebi oluşturun.</p>
            <a href="https://gunubirlik.com/forgot-password" class="button">Şifremi Unuttum</a>
          </div>
        </body>
        </html>
      `);
    }
  } catch (error) {
    console.error('Firebase şifre sıfırlama işleyici hatası:', error);
    res.redirect('https://gunubirlik.com/forgot-password');
  }
});

module.exports = router;
