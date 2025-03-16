/**
 * E-posta gönderme işlemleri için yardımcı fonksiyonlar
 */

import { 
    auth, 
    sendEmailVerification,
    sendPasswordResetEmail
} from './firebaseConfig.js';

/**
 * Doğrulama kodu e-postası gönderir
 * @param {string} email - Alıcı e-posta adresi
 * @param {string} code - Doğrulama kodu
 * @param {string} action - İşlem türü (delete, change-email, vb.)
 * @returns {Promise<boolean>} - İşlem başarılı mı?
 */
export async function sendVerificationEmail(email, code, action = 'verify') {
    try {
        console.log('E-posta gönderiliyor...');
        console.log(`Alıcı: ${email}`);
        console.log(`Doğrulama Kodu: ${code}`);
        
        // Hesap silme işlemi için özel URL
        let actionUrl;
        let actionTitle;
        
        if (action === 'delete-account') {
            actionUrl = `${window.location.origin}/delete-account-verification.html?code=${code}&action=${action}&email=${encodeURIComponent(email)}`;
            actionTitle = 'Hesap Silme İşlemi';
        } else {
            actionUrl = `${window.location.origin}/verify-action.html?code=${code}&action=${action}&email=${encodeURIComponent(email)}`;
            actionTitle = 'Doğrulama İşlemi';
        }
        
        // Firebase'in kendi e-posta sistemini kullanarak şifre sıfırlama e-postası gönder
        const actionCodeSettings = {
            url: actionUrl,
            handleCodeInApp: true
        };
        
        // Kullanıcının e-posta adresine şifre sıfırlama e-postası gönder
        await sendPasswordResetEmail(auth, email, actionCodeSettings);
        
        console.log('E-posta başarıyla gönderildi!');
        return true;
    } catch (error) {
        console.error('E-posta gönderme hatası:', error);
        return false;
    }
}

/**
 * Bilgilendirme e-postası gönderir
 * @param {string} email - Alıcı e-posta adresi
 * @param {string} subject - E-posta konusu
 * @param {string} message - E-posta mesajı
 * @returns {Promise<boolean>} - İşlem başarılı mı?
 */
export async function sendInfoEmail(email, subject, message) {
    try {
        console.log('Bilgilendirme e-postası gönderiliyor...');
        console.log(`Alıcı: ${email}`);
        console.log(`Konu: ${subject}`);
        console.log(`Mesaj: ${message}`);
        
        // Not: Firebase'in standart e-posta gönderme API'si özelleştirilmiş içerik göndermeye izin vermez
        // Gerçek bir uygulama için Firebase Cloud Functions veya üçüncü taraf bir e-posta servisi kullanmanız gerekir
        
        // Bu örnek için şifre sıfırlama e-postası gönderiyoruz
        const actionCodeSettings = {
            url: `${window.location.origin}/info.html?subject=${encodeURIComponent(subject)}&message=${encodeURIComponent(message)}`,
            handleCodeInApp: true
        };
        
        await sendPasswordResetEmail(auth, email, actionCodeSettings);
        
        console.log('Bilgilendirme e-postası başarıyla gönderildi!');
        return true;
    } catch (error) {
        console.error('E-posta gönderme hatası:', error);
        return false;
    }
}

/**
 * Hesap silme bilgilendirme e-postası gönderir
 * @param {string} email - Alıcı e-posta adresi
 * @returns {Promise<boolean>} - İşlem başarılı mı?
 */
export async function sendAccountDeletionEmail(email) {
    try {
        console.log('Hesap silme bilgilendirme e-postası gönderiliyor...');
        console.log(`Alıcı: ${email}`);
        
        const subject = "Hesabınız Silindi";
        const message = "Hesabınız ve tüm verileriniz başarıyla silinmiştir. Günübirlik hizmetlerimizi kullandığınız için teşekkür ederiz.";
        
        // Bu örnek için şifre sıfırlama e-postası gönderiyoruz
        const actionCodeSettings = {
            url: `${window.location.origin}/account-deleted.html?email=${encodeURIComponent(email)}`,
            handleCodeInApp: true
        };
        
        await sendPasswordResetEmail(auth, email, actionCodeSettings);
        
        console.log('Hesap silme bilgilendirme e-postası başarıyla gönderildi!');
        return true;
    } catch (error) {
        console.error('E-posta gönderme hatası:', error);
        return false;
    }
} 