import { 
    auth, 
    firestore,
    doc,
    getDoc,
    setDoc,
    updateDoc,
    collection,
    query,
    where,
    getDocs,
    serverTimestamp
} from './firebaseConfig.js';

import { 
    sendVerificationEmail, 
    sendInfoEmail as sendInfoEmailService,
    sendAccountDeletionEmail as sendAccountDeletionEmailService
} from './email-service.js';

/**
 * Kullanıcıya doğrulama kodu gönderir
 * @param {string} email - Kullanıcının e-posta adresi
 * @param {string} userId - Kullanıcının ID'si
 * @param {string} action - İşlem türü (delete, change-email, vb.)
 * @returns {Promise<string>} - Oluşturulan doğrulama kodu
 */
export async function sendVerificationCode(email, userId, action = 'verify') {
    try {
        // 6 haneli rastgele kod oluştur
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Doğrulama kodunu Firestore'a kaydet
        const verificationData = {
            code: verificationCode,
            email: email,
            userId: userId,
            action: action,
            createdAt: serverTimestamp(),
            expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 dakika geçerli
            used: false
        };
        
        // Kullanıcının doğrulama kodlarını saklamak için bir koleksiyon oluştur
        const verificationRef = doc(collection(firestore, 'verification_codes'));
        await setDoc(verificationRef, verificationData);
        
        // Kullanıcı belgesini güncelle
        await updateDoc(doc(firestore, 'users', userId), {
            lastVerificationId: verificationRef.id,
            lastVerificationAction: action,
            lastVerificationTime: serverTimestamp()
        });
        
        // E-posta gönder
        await sendVerificationEmail(email, verificationCode, action);
        
        return verificationCode;
    } catch (error) {
        console.error('Doğrulama kodu gönderme hatası:', error);
        throw error;
    }
}

/**
 * Doğrulama kodunu kontrol eder
 * @param {string} userId - Kullanıcının ID'si
 * @param {string} code - Doğrulama kodu
 * @param {string} action - İşlem türü (delete, change-email, vb.)
 * @returns {Promise<boolean>} - Doğrulama başarılı mı?
 */
export async function verifyCode(userId, code, action = 'verify') {
    try {
        // Kullanıcının son doğrulama kodunu al
        const userDoc = await getDoc(doc(firestore, 'users', userId));
        
        if (!userDoc.exists()) {
            throw new Error('Kullanıcı bulunamadı');
        }
        
        const userData = userDoc.data();
        const lastVerificationId = userData.lastVerificationId;
        
        if (!lastVerificationId) {
            throw new Error('Doğrulama kodu bulunamadı');
        }
        
        // Doğrulama kodunu al
        const verificationDoc = await getDoc(doc(firestore, 'verification_codes', lastVerificationId));
        
        if (!verificationDoc.exists()) {
            throw new Error('Doğrulama kodu bulunamadı');
        }
        
        const verificationData = verificationDoc.data();
        
        // Kodun geçerli olup olmadığını kontrol et
        if (verificationData.used) {
            throw new Error('Bu doğrulama kodu daha önce kullanılmış');
        }
        
        if (verificationData.action !== action) {
            throw new Error('Geçersiz doğrulama kodu');
        }
        
        if (new Date() > new Date(verificationData.expiresAt.toDate())) {
            throw new Error('Doğrulama kodunun süresi dolmuş');
        }
        
        if (verificationData.code !== code) {
            throw new Error('Geçersiz doğrulama kodu');
        }
        
        // Doğrulama kodunu kullanıldı olarak işaretle
        await updateDoc(doc(firestore, 'verification_codes', lastVerificationId), {
            used: true,
            verifiedAt: serverTimestamp()
        });
        
        return true;
    } catch (error) {
        console.error('Doğrulama kodu kontrolü hatası:', error);
        throw error;
    }
}

/**
 * Kullanıcının e-posta adresini doğrular
 * @param {string} email - Doğrulanacak e-posta adresi
 * @returns {Promise<boolean>} - E-posta geçerli mi?
 */
export async function validateEmail(email) {
    try {
        // E-posta formatını kontrol et
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return false;
        }
        
        // E-postanın sistemde kayıtlı olup olmadığını kontrol et
        const userQuery = query(collection(firestore, 'users'), where('email', '==', email));
        const userSnapshot = await getDocs(userQuery);
        
        return !userSnapshot.empty;
    } catch (error) {
        console.error('E-posta doğrulama hatası:', error);
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
        return await sendInfoEmailService(email, subject, message);
    } catch (error) {
        console.error('Bilgilendirme e-postası gönderme hatası:', error);
        throw error;
    }
}

/**
 * Hesap silme bilgilendirme e-postası gönderir
 * @param {string} email - Alıcı e-posta adresi
 * @returns {Promise<boolean>} - İşlem başarılı mı?
 */
export async function sendAccountDeletionEmail(email) {
    try {
        return await sendAccountDeletionEmailService(email);
    } catch (error) {
        console.error('Hesap silme bilgilendirme e-postası gönderme hatası:', error);
        throw error;
    }
} 