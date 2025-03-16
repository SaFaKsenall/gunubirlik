import { 
    auth, 
    firestore,
    onAuthStateChanged,
    doc, 
    getDoc, 
    setDoc,
    updateDoc,
    serverTimestamp 
} from './firebaseConfig.js';

class ThemeManager {
    constructor() {
        this.isInitialized = false;
        this.isAuthenticated = false;
        console.log('ThemeManager başlatılıyor...');
        this.init();
    }

    async init() {
        try {
            console.log('ThemeManager init başladı');
            
            // QR oturumu kontrolü
            const qrSessionData = localStorage.getItem('qrSession');
            if (qrSessionData) {
                try {
                    const qrSession = JSON.parse(qrSessionData);
                    const sessionDoc = await getDoc(doc(firestore, 'qr_sessions', qrSession.sessionId));
                    
                    if (sessionDoc.exists() && sessionDoc.data().status === 'completed') {
                        console.log('QR oturumu bulundu:', qrSession.uid);
                        this.isAuthenticated = true;
                        await this.loadUserSettings(qrSession.uid);
                    }
                } catch (error) {
                    console.error('QR oturum kontrolü hatası:', error);
                }
            }

            // Event listener'ları ayarla
            this.setupEventListeners();

            // Auth state değişikliklerini dinle
            onAuthStateChanged(auth, async (user) => {
                this.isAuthenticated = !!user;
                if (user) {
                    console.log('Firebase oturumu açık, kullanıcı ID:', user.uid);
                    await this.loadUserSettings(user.uid);
                } else if (!qrSessionData) {
                    console.log('Oturum kapalı, varsayılan tema uygulanıyor');
                    this.applyDefaultTheme();
                }
            });

            this.isInitialized = true;
            console.log('ThemeManager başarıyla başlatıldı');
        } catch (error) {
            console.error('Theme Manager başlatma hatası:', error);
            throw error;
        }
    }

    async waitForAuth() {
        console.log('Oturum kontrolü yapılıyor...');
        
        // QR oturumu kontrolü
        const qrSessionData = localStorage.getItem('qrSession');
        if (qrSessionData) {
            try {
                const qrSession = JSON.parse(qrSessionData);
                const sessionDoc = await getDoc(doc(firestore, 'qr_sessions', qrSession.sessionId));
                
                if (sessionDoc.exists() && sessionDoc.data().status === 'completed') {
                    console.log('Aktif QR oturumu bulundu');
                    this.isAuthenticated = true;
                    return;
                }
            } catch (error) {
                console.error('QR oturum kontrolü hatası:', error);
            }
        }

        // Firebase oturumu kontrolü
        if (auth.currentUser) {
            console.log('Aktif Firebase oturumu bulundu');
            this.isAuthenticated = true;
            return;
        }

        // Oturum yoksa hata fırlat
        throw new Error('Aktif oturum bulunamadı');
    }

    applyDefaultTheme() {
        const savedTheme = localStorage.getItem('theme') || 'light';
        const savedFontSize = localStorage.getItem('fontSize') || 'medium';
        
        document.documentElement.setAttribute('data-theme', savedTheme);
        document.documentElement.setAttribute('data-font-size', savedFontSize);

        // Select elementlerini güncelle
        if (this.themeSelect) this.themeSelect.value = savedTheme;
        if (this.fontSizeSelect) this.fontSizeSelect.value = savedFontSize;
    }

    async loadUserSettings(userId) {
        try {
            console.log('Kullanıcı ayarları yükleniyor...');
            const settingsDoc = await getDoc(doc(firestore, 'userSettings', userId));
            
            if (settingsDoc.exists()) {
                const settings = settingsDoc.data();
                console.log('Yüklenen ayarlar:', settings);
                
                // Tema ve yazı boyutunu uygula
                if (settings.theme) {
                    this.applyTheme(settings.theme, false);
                }
                
                if (settings.fontSize) {
                    this.applyFontSize(settings.fontSize, false);
                }

                // Select elementlerini güncelle
                if (this.themeSelect) this.themeSelect.value = settings.theme || 'light';
                if (this.fontSizeSelect) this.fontSizeSelect.value = settings.fontSize || 'medium';
            } else {
                // Kullanıcının ayarları yoksa varsayılan ayarları kaydet
                console.log('Kullanıcı ayarları bulunamadı, varsayılan ayarlar kaydediliyor...');
                await this.saveSettingsToFirestore();
            }
        } catch (error) {
            console.error('Kullanıcı ayarları yüklenirken hata:', error);
        }
    }

    setupEventListeners() {
        console.log('Event listener\'lar ayarlanıyor...');
        this.themeSelect = document.getElementById('themeSelect');
        this.fontSizeSelect = document.getElementById('fontSizeSelect');

        if (!this.themeSelect) console.warn('themeSelect elementi bulunamadı!');
        if (!this.fontSizeSelect) console.warn('fontSizeSelect elementi bulunamadı!');

        if (this.themeSelect) {
            this.themeSelect.addEventListener('change', async (e) => {
                try {
                    console.log('Tema değiştirme isteği:', e.target.value);
                    await this.waitForAuth();
                    await this.updateTheme(e.target.value);
                } catch (error) {
                    console.error('Tema değiştirme hatası:', error);
                }
            });
        }

        if (this.fontSizeSelect) {
            this.fontSizeSelect.addEventListener('change', async (e) => {
                try {
                    console.log('Yazı boyutu değiştirme isteği:', e.target.value);
                    await this.waitForAuth();
                    await this.updateFontSize(e.target.value);
                } catch (error) {
                    console.error('Yazı boyutu değiştirme hatası:', error);
                }
            });
        }
        console.log('Event listener\'lar başarıyla ayarlandı');
    }

    applyTheme(theme, save = true) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('theme', theme);
        if (save && this.isAuthenticated) {
            this.saveSettingsToFirestore();
        }
    }

    applyFontSize(size, save = true) {
        document.documentElement.setAttribute('data-font-size', size);
        localStorage.setItem('fontSize', size);
        if (save && this.isAuthenticated) {
            this.saveSettingsToFirestore();
        }
    }

    async updateTheme(theme = 'light') {
        try {
            console.log('Tema güncelleme başladı:', theme);
            this.applyTheme(theme);
            if (this.isAuthenticated) {
                await this.saveSettingsToFirestore();
                console.log('Tema başarıyla güncellendi ve kaydedildi:', theme);
            } else {
                console.warn('Tema sadece lokalde güncellendi (oturum yok):', theme);
            }
        } catch (error) {
            console.error('Tema güncelleme hatası:', error);
            throw error;
        }
    }

    async updateFontSize(fontSize = 'medium') {
        try {
            console.log('Yazı boyutu güncelleme başladı:', fontSize);
            this.applyFontSize(fontSize);
            if (this.isAuthenticated) {
                await this.saveSettingsToFirestore();
                console.log('Yazı boyutu başarıyla güncellendi ve kaydedildi:', fontSize);
            } else {
                console.warn('Yazı boyutu sadece lokalde güncellendi (oturum yok):', fontSize);
            }
        } catch (error) {
            console.error('Yazı boyutu güncelleme hatası:', error);
            throw error;
        }
    }

    async saveSettingsToFirestore() {
        console.log('Firestore\'a kaydetme başladı');
        try {
            // QR oturumu kontrolü
            const qrSessionData = localStorage.getItem('qrSession');
            let userId = null;

            if (qrSessionData) {
                const qrSession = JSON.parse(qrSessionData);
                const sessionDoc = await getDoc(doc(firestore, 'qr_sessions', qrSession.sessionId));
                
                if (sessionDoc.exists() && sessionDoc.data().status === 'completed') {
                    userId = qrSession.uid;
                }
            }

            // Firebase oturumu kontrolü
            if (!userId && auth.currentUser) {
                userId = auth.currentUser.uid;
            }

            if (!userId) {
                throw new Error('Kullanıcı oturumu bulunamadı');
            }

            const settings = {
                theme: localStorage.getItem('theme') || 'light',
                fontSize: localStorage.getItem('fontSize') || 'medium',
                updatedAt: serverTimestamp()
            };

            console.log('Kaydedilecek ayarlar:', settings);

            const userSettingsRef = doc(firestore, 'userSettings', userId);
            try {
                console.log('Firestore güncelleme deneniyor...');
                await updateDoc(userSettingsRef, settings);
                console.log('Firestore güncelleme başarılı');
            } catch (error) {
                if (error.code === 'not-found') {
                    console.log('Döküman bulunamadı, yeni oluşturuluyor...');
                    await setDoc(userSettingsRef, {
                        ...settings,
                        createdAt: serverTimestamp()
                    });
                    console.log('Yeni döküman oluşturuldu');
                } else {
                    console.error('Firestore işlem hatası:', error);
                    throw error;
                }
            }

            console.log('Ayarlar başarıyla Firestore\'a kaydedildi');

        } catch (error) {
            console.error('Ayarları kaydetme hatası:', error);
            throw error;
        }
    }
}

// Sayfa yüklendiğinde ThemeManager'ı başlat
let themeManager;
document.addEventListener('DOMContentLoaded', () => {
    console.log('Sayfa yüklendi, ThemeManager başlatılıyor...');
    try {
        themeManager = new ThemeManager();
    } catch (error) {
        console.error('ThemeManager başlatma hatası:', error);
    }
});

// Tema değişikliklerini dinle
window.addEventListener('storage', (event) => {
    console.log('Storage event:', event);
    if (event.key === 'theme' || event.key === 'fontSize') {
        console.log('Tema/yazı boyutu değişikliği algılandı:', event.key, event.newValue);
        themeManager?.applyDefaultTheme();
    }
});

export default ThemeManager; 