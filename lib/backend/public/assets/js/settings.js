import { 
    auth, 
    firestore,
    updatePassword,
    updateEmail,
    reauthenticateWithCredential,
    EmailAuthProvider,
    doc,
    setDoc,
    getDoc,
    updateDoc,
    serverTimestamp
} from './firebaseConfig.js';

// QR oturumunu kontrol et
async function checkQrSession() {
    const qrSessionData = localStorage.getItem('qrSession');
    if (!qrSessionData) return null;

    try {
        const qrSession = JSON.parse(qrSessionData);
        const sessionDoc = await getDoc(doc(firestore, 'qr_sessions', qrSession.sessionId));

        if (sessionDoc.exists()) {
            const sessionData = sessionDoc.data();
            
            // Oturum aktif mi kontrol et
            if (sessionData.status === 'completed') {
                // Oturumu yenile
                await updateDoc(doc(firestore, 'qr_sessions', qrSession.sessionId), {
                    lastActivity: serverTimestamp(),
                    refreshedAt: serverTimestamp()
                });
                return qrSession.uid;
            }
        }

        // Oturum geçersizse temizle
        localStorage.removeItem('qrSession');
        return null;
    } catch (error) {
        console.error('QR oturum kontrolü hatası:', error);
        return null;
    }
}

// Oturum kontrolü fonksiyonu - yönlendirme yapmaz
async function checkSession() {
    let userId = null;
    let isQrSession = false;

    // Firebase Auth kontrolü
    if (auth.currentUser) {
        userId = auth.currentUser.uid;
        console.log('Firebase Auth oturumu bulundu:', userId);
    } else {
        // QR oturumu kontrolü
        userId = await checkQrSession();
        if (userId) {
            isQrSession = true;
            console.log('QR oturumu bulundu:', userId);
        } else {
            console.log('Oturum bulunamadı');
            return { userId: null, isQrSession: false };
        }
    }

    return { userId, isQrSession };
}

// Ayarları kaydetme fonksiyonu
export async function saveSettings() {
    try {
        const { userId, isQrSession } = await checkSession();
        
        if (!userId) {
            console.error('Oturum bulunamadı');
            return;
        }

        const settings = {
            theme: document.getElementById('themeSelect').value,
            fontSize: document.getElementById('fontSizeSelect').value,
            emailNotifications: document.getElementById('emailNotifications').checked,
            newJobNotifications: document.getElementById('newJobNotifications').checked,
            messageNotifications: document.getElementById('messageNotifications').checked,
            privacy: document.getElementById('privacySelect').value,
            locationSharing: document.getElementById('locationSharing').checked,
            twoFactorAuth: document.getElementById('twoFactorAuth').checked,
            lastUpdated: serverTimestamp()
        };

        const userSettingsRef = doc(firestore, 'userSettings', userId);
        await setDoc(userSettingsRef, settings, { merge: true });
        
        // Tema değişikliğini hemen uygula
        applyTheme(settings.theme);
        
        alert('Ayarlar başarıyla kaydedildi!');
    } catch (error) {
        console.error('Ayarlar kaydedilirken hata:', error);
        alert('Ayarlar kaydedilirken bir hata oluştu: ' + error.message);
    }
}

// Ayarları yükleme fonksiyonu
export async function loadSettings() {
    try {
        console.log('Ayarlar yükleniyor...');
        const { userId, isQrSession } = await checkSession();
        
        if (!userId) {
            console.error('Oturum bulunamadı, ayarlar yüklenemedi');
            return;
        }

        console.log('Kullanıcı ID:', userId, 'QR Oturumu:', isQrSession);
        const userSettingsRef = doc(firestore, 'userSettings', userId);
        const settingsDoc = await getDoc(userSettingsRef);

        if (settingsDoc.exists()) {
            const settings = settingsDoc.data();
            console.log('Ayarlar bulundu:', settings);
            
            // Form elemanlarını doldur
            document.getElementById('themeSelect').value = settings.theme || 'light';
            document.getElementById('fontSizeSelect').value = settings.fontSize || 'medium';
            document.getElementById('emailNotifications').checked = settings.emailNotifications || false;
            document.getElementById('newJobNotifications').checked = settings.newJobNotifications || false;
            document.getElementById('messageNotifications').checked = settings.messageNotifications || false;
            document.getElementById('privacySelect').value = settings.privacy || 'public';
            document.getElementById('locationSharing').checked = settings.locationSharing || false;
            document.getElementById('twoFactorAuth').checked = settings.twoFactorAuth || false;
            
            // Temayı uygula
            applyTheme(settings.theme || 'light');
        } else {
            console.log('Ayarlar bulunamadı, varsayılan değerler kullanılıyor');
            // Varsayılan değerleri kullan
            applyTheme('light');
        }
        
        // Ayarları kaydet butonu
        const saveSettingsBtn = document.getElementById('saveSettingsBtn');
        if (saveSettingsBtn) {
            saveSettingsBtn.addEventListener('click', saveSettings);
        }
    } catch (error) {
        console.error('Ayarlar yüklenirken hata:', error);
    }
}

// Şifre değiştirme fonksiyonu
export async function changePassword(currentPassword, newPassword) {
    try {
        const { userId, isQrSession } = await checkSession();
        
        if (!userId) {
            alert('Oturum bulunamadı');
            return;
        }
        
        if (isQrSession) {
            alert('QR kod ile giriş yaptığınız için şifre değiştirme işlemi yapılamaz. Lütfen normal giriş yaparak deneyiniz.');
            return;
        }

        const user = auth.currentUser;
        if (!user) {
            throw new Error('Oturum bulunamadı');
        }

        // Kullanıcıyı yeniden doğrula
        const credential = EmailAuthProvider.credential(user.email, currentPassword);
        await reauthenticateWithCredential(user, credential);

        // Şifreyi güncelle
        await updatePassword(user, newPassword);
        alert('Şifreniz başarıyla güncellendi!');
        
    } catch (error) {
        console.error('Şifre değiştirme hatası:', error);
        if (error.code === 'auth/requires-recent-login') {
            alert('Güvenlik nedeniyle yeniden giriş yapmanız gerekiyor.');
        } else {
            alert('Şifre değiştirirken bir hata oluştu: ' + error.message);
        }
    }
}

// E-posta değiştirme fonksiyonu
export async function changeEmail(currentPassword, newEmail) {
    try {
        const { userId, isQrSession } = await checkSession();
        
        if (!userId) {
            alert('Oturum bulunamadı');
            return;
        }
        
        if (isQrSession) {
            alert('QR kod ile giriş yaptığınız için e-posta değiştirme işlemi yapılamaz. Lütfen normal giriş yaparak deneyiniz.');
            return;
        }

        const user = auth.currentUser;
        if (!user) {
            throw new Error('Oturum bulunamadı');
        }

        // Kullanıcıyı yeniden doğrula
        const credential = EmailAuthProvider.credential(user.email, currentPassword);
        await reauthenticateWithCredential(user, credential);

        // E-postayı güncelle
        await updateEmail(user, newEmail);
        
        // Firestore'daki kullanıcı bilgilerini güncelle
        const userRef = doc(firestore, 'users', user.uid);
        await updateDoc(userRef, {
            email: newEmail,
            lastUpdated: serverTimestamp()
        });

        alert('E-posta adresiniz başarıyla güncellendi!');
        
    } catch (error) {
        console.error('E-posta değiştirme hatası:', error);
        if (error.code === 'auth/requires-recent-login') {
            alert('Güvenlik nedeniyle yeniden giriş yapmanız gerekiyor.');
        } else {
            alert('E-posta değiştirirken bir hata oluştu: ' + error.message);
        }
    }
}

// Hesabı dondurma fonksiyonu
export async function deactivateAccount(password) {
    try {
        const { userId, isQrSession } = await checkSession();
        
        if (!userId) {
            alert('Oturum bulunamadı');
            return;
        }
        
        if (isQrSession) {
            alert('QR kod ile giriş yaptığınız için hesap dondurma işlemi yapılamaz. Lütfen normal giriş yaparak deneyiniz.');
            return;
        }

        const user = auth.currentUser;
        if (!user) {
            throw new Error('Oturum bulunamadı');
        }

        // Kullanıcıyı yeniden doğrula
        const credential = EmailAuthProvider.credential(user.email, password);
        await reauthenticateWithCredential(user, credential);

        // Firestore'da hesabı deaktif olarak işaretle
        const userRef = doc(firestore, 'users', user.uid);
        await updateDoc(userRef, {
            isActive: false,
            deactivatedAt: serverTimestamp()
        });

        alert('Hesabınız donduruldu. Tekrar aktifleştirmek için bizimle iletişime geçin.');
        
        // Oturumu kapat
        await auth.signOut();
        
    } catch (error) {
        console.error('Hesap dondurma hatası:', error);
        if (error.code === 'auth/requires-recent-login') {
            alert('Güvenlik nedeniyle yeniden giriş yapmanız gerekiyor.');
        } else {
            alert('Hesap dondurulurken bir hata oluştu: ' + error.message);
        }
    }
}

// Tema uygulama fonksiyonu
function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
}

// Event listener'ları ekle
document.addEventListener('DOMContentLoaded', async () => {
    try {
        // İlk oturum kontrolü
        await checkSession();
        
        // Ayarları yükle
        await loadSettings();

        // Ayarları kaydet butonu
        const saveSettingsBtn = document.getElementById('saveSettingsBtn');
        if (saveSettingsBtn) {
            saveSettingsBtn.addEventListener('click', saveSettings);
        }

        // Şifre değiştirme formu
        const changePasswordForm = document.getElementById('changePasswordForm');
        if (changePasswordForm) {
            changePasswordForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                const currentPassword = document.getElementById('currentPassword').value;
                const newPassword = document.getElementById('newPassword').value;
                await changePassword(currentPassword, newPassword);
            });
        }

        // E-posta değiştirme formu
        const changeEmailForm = document.getElementById('changeEmailForm');
        if (changeEmailForm) {
            changeEmailForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                const currentPassword = document.getElementById('emailCurrentPassword').value;
                const newEmail = document.getElementById('newEmail').value;
                await changeEmail(currentPassword, newEmail);
            });
        }

        // Hesap dondurma formu
        const deactivateForm = document.getElementById('deactivateForm');
        if (deactivateForm) {
            deactivateForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                if (confirm('Hesabınızı dondurmak istediğinizden emin misiniz?')) {
                    const password = document.getElementById('deactivatePassword').value;
                    await deactivateAccount(password);
                }
            });
        }
    } catch (error) {
        console.error('Başlangıç hatası:', error);
        window.location.href = '/register.html';
    }
});

// Sayfa kapanırken kontrolleri durdur
window.addEventListener('beforeunload', () => {
    // Periyodik kontrolleri durdur
    // Bu işlem, yeni bir sayfa yüklenmeden önce çalıştırılır
    // Burada periyodik kontrolleri durdurma işlemi yapılabilir
}); 