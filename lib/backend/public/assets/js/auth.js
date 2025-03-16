import { 
    auth, 
    firestore,
    onAuthStateChanged, 
    signOut,
    collection, 
    getDocs, 
    doc,
    getDoc,
    query,
    where,
    orderBy,
    setDoc,
    onSnapshot,
    serverTimestamp
} from './firebaseConfig.js';
import { loadAllJobs, loadJobStats } from './jobs.js';

let isProcessing = false;
let currentUserId = null;

// Kullanıcı oturumunu ve QR oturumunu kontrol et, verileri yükle
export async function checkAuthAndLoadData() {
    try {
        if (isProcessing) return false;
        isProcessing = true;
        
        console.log('Oturum kontrolü başlatılıyor...');
        const user = auth.currentUser;
        const qrSessionData = localStorage.getItem('qrSession');
        
        // QR oturumu kontrolü
        if (qrSessionData) {
            try {
                const qrSession = JSON.parse(qrSessionData);
                const sessionDoc = await getDoc(doc(firestore, 'qr_sessions', qrSession.sessionId));
                
                if (sessionDoc.exists() && sessionDoc.data().status === 'completed') {
                    console.log('QR oturumu aktif:', qrSession.uid);
                    
                    // Kullanıcının hala var olup olmadığını kontrol et
                    const userDoc = await getDoc(doc(firestore, 'users', qrSession.uid));
                    if (!userDoc.exists()) {
                        console.log('Kullanıcı hesabı silinmiş, oturum kapatılıyor...');
                        localStorage.removeItem('qrSession');
                        await signOut(auth);
                        isProcessing = false;
                        return false;
                    }
                    
                    currentUserId = qrSession.uid;
                    await loadUserData(qrSession.uid);
                    isProcessing = false;
                    return true;
                }
                
                console.log('QR oturumu geçersiz');
                localStorage.removeItem('qrSession');
            } catch (error) {
                console.error('QR oturum kontrolü hatası:', error);
            }
        }

        // Firebase Auth kontrolü
        if (user) {
            console.log('Firebase Auth oturumu bulundu:', user.uid);
            
            // Kullanıcının hala var olup olmadığını kontrol et
            const userDoc = await getDoc(doc(firestore, 'users', user.uid));
            if (!userDoc.exists()) {
                console.log('Kullanıcı hesabı silinmiş, oturum kapatılıyor...');
                await signOut(auth);
                isProcessing = false;
                return false;
            }
            
            currentUserId = user.uid;
            await loadUserData(user.uid);
            isProcessing = false;
            return true;
        }

        // Hiçbir oturum bulunamadı, ancak onAuthStateChanged ile tekrar kontrol et
        return new Promise((resolve) => {
            const unsubscribe = onAuthStateChanged(auth, async (authUser) => {
                unsubscribe(); // Dinlemeyi hemen durdur
                
                if (authUser) {
                    console.log('onAuthStateChanged: Kullanıcı bulundu:', authUser.uid);
                    
                    // Kullanıcının hala var olup olmadığını kontrol et
                    const userDoc = await getDoc(doc(firestore, 'users', authUser.uid));
                    if (!userDoc.exists()) {
                        console.log('Kullanıcı hesabı silinmiş, oturum kapatılıyor...');
                        await signOut(auth);
                        isProcessing = false;
                        resolve(false);
                        return;
                    }
                    
                    currentUserId = authUser.uid;
                    await loadUserData(authUser.uid);
                    isProcessing = false;
                    resolve(true);
                } else {
                    console.log('onAuthStateChanged: Kullanıcı bulunamadı');
                    isProcessing = false;
                    resolve(false);
                }
            });
            
            // 3 saniye sonra timeout
            setTimeout(() => {
                unsubscribe();
                console.log('onAuthStateChanged: Timeout');
                isProcessing = false;
                resolve(false);
            }, 3000);
        });
    } catch (error) {
        console.error('Oturum kontrolü hatası:', error);
        isProcessing = false;
        return false;
    }
}

// Kullanıcı bilgilerini yükle
export async function loadUserData(userId) {
    try {
        console.log('Kullanıcı bilgileri yükleniyor:', userId);
        const userDoc = await getDoc(doc(firestore, 'users', userId));
        if (userDoc.exists()) {
            const userData = userDoc.data();
            updateUserInfo(userData);
            
            // DOM yüklendikten sonra iş verilerini yükle
            setTimeout(async () => {
                try {
                    // Sadece homepage.html sayfasında iş verilerini yükle
                    const currentPage = window.location.pathname;
                    if (currentPage.includes('homepage.html')) {
                        console.log('İş verileri yükleniyor...');
                        await loadAllJobs();
                        await loadJobStats(userId);
                    }
                } catch (error) {
                    console.error('İş verileri yüklenirken hata:', error);
                }
            }, 100);
            
            return userData;
        } else {
            console.error('Kullanıcı bilgileri bulunamadı');
            return null;
        }
    } catch (error) {
        console.error('Kullanıcı bilgileri yüklenirken hata:', error);
        return null;
    }
}

// QR oturumlarını dinle
export function listenForSessionChanges(userId, sessionId) {
    const sessionUnsubscribe = onSnapshot(
        doc(firestore, 'qr_sessions', sessionId),
        (snapshot) => {
            if (!snapshot.exists()) return;
            
            const data = snapshot.data();
            if (data.status === 'disconnected') {
                console.log('Oturum sonlandırıldı, çıkış yapılıyor...');
                logout();
            }
        }
    );
    
    const allSessionsUnsubscribe = onSnapshot(
        query(
            collection(firestore, 'qr_sessions'),
            where('userId', '==', userId),
            where('status', '==', 'disconnected')
        ),
        (snapshot) => {
            snapshot.docChanges().forEach((change) => {
                if (change.type === 'added' || change.type === 'modified') {
                    const data = change.doc.data();
                    if (data.sessionId === sessionId) {
                        console.log('Oturum sonlandırıldı, çıkış yapılıyor...');
                        logout();
                    }
                }
            });
        }
    );
    
    window.addEventListener('beforeunload', () => {
        sessionUnsubscribe();
        allSessionsUnsubscribe();
    });
}

// Çıkış yapma fonksiyonu
export async function logout() {
    try {
        const qrSessionData = localStorage.getItem('qrSession');
        if (qrSessionData) {
            const qrSession = JSON.parse(qrSessionData);
            console.log('QR oturumu sonlandırılıyor:', qrSession.sessionId);
            
            try {
                await setDoc(doc(firestore, 'qr_sessions', qrSession.sessionId), {
                    'status': 'disconnected',
                    'disconnectedAt': serverTimestamp(),
                    'disconnectedBy': 'web_manual_logout',
                    'disconnectedByUserId': qrSession.uid
                }, { merge: true });
                console.log('QR oturumu başarıyla sonlandırıldı');
            } catch (error) {
                console.error('QR oturumu sonlandırma hatası:', error);
            }
        }
        
        localStorage.removeItem('qrSession');
        await signOut(auth);
        window.location.replace('/register.html');
    } catch (error) {
        console.error('Çıkış hatası:', error);
        alert('Çıkış yapılırken hata oluştu');
    }
}

// Kullanıcı bilgilerini güncelleme fonksiyonu
export function updateUserInfo(userData) {
    try {
        // Kullanıcı adını güncelle (tüm sayfalarda ortak)
        const userDisplayName = document.getElementById('userDisplayName');
        if (userDisplayName) {
            userDisplayName.textContent = userData.fullName || 'Kullanıcı';
        }

        // Profil sayfası elementlerini güncelle
        const profileElements = {
            'fullNameValue': userData.fullName,
            'usernameValue': userData.username,
            'emailValue': userData.email,
            'phoneNumberValue': userData.phoneNumber,
            'phoneVerifiedValue': userData.phoneVerified ? '✅ Doğrulanmış' : '❌ Doğrulanmamış',
            'referralCodeValue': userData.referralCode,
            'roleValue': userData.role,
            'isActiveValue': userData.isActive ? '✅ Aktif' : '❌ Pasif',
            'createdAtValue': userData.createdAt ? new Date(userData.createdAt.toDate()).toLocaleString('tr-TR') : 'Belirtilmemiş',
            'lastLoginValue': userData.lastLogin ? new Date(userData.lastLogin.toDate()).toLocaleString('tr-TR') : 'Belirtilmemiş',
            'lastUpdatedValue': userData.lastUpdated ? new Date(userData.lastUpdated.toDate()).toLocaleString('tr-TR') : 'Belirtilmemiş'
        };

        // Her bir elementi kontrol et ve varsa güncelle
        Object.entries(profileElements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value || 'Belirtilmemiş';
            }
        });

        // Cihaz bilgilerini güncelle
        const deviceInfoElement = document.getElementById('deviceInfoValue');
        if (deviceInfoElement && userData.deviceInfo) {
            const deviceInfo = `Platform: ${userData.deviceInfo.platform || 'Belirtilmemiş'}
                              Versiyon: ${userData.deviceInfo.version || 'Belirtilmemiş'}`;
            deviceInfoElement.textContent = deviceInfo;
        }
    } catch (error) {
        console.error('Kullanıcı bilgileri güncellenirken hata:', error);
    }
} 