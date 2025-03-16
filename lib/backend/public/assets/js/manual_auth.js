import { 
    auth, 
    firestore,
    createUserWithEmailAndPassword,
    signInWithEmailAndPassword,
    updateProfile,
    signOut,
    doc,
    setDoc,
    getDoc
} from './firebaseConfig.js';

// Manuel kayıt fonksiyonu
export async function registerWithEmail(fullName, email, password) {
    try {
        const userCredential = await createUserWithEmailAndPassword(auth, email, password);
        
        await updateProfile(userCredential.user, {
            displayName: fullName
        });

        await setDoc(doc(firestore, 'users', userCredential.user.uid), {
            fullName: fullName,
            email: email,
            createdAt: new Date().toISOString(),
            userId: userCredential.user.uid,
            isActive: true,
            role: 'user'
        });

        return { success: true, user: userCredential.user };
    } catch (error) {
        console.error('Register error:', error);
        return { success: false, error: error.message };
    }
}

// Manuel giriş fonksiyonu
export async function loginWithEmail(email, password) {
    try {
        const userCredential = await signInWithEmailAndPassword(auth, email, password);
        if (userCredential.user) {
            const userDoc = await getDoc(doc(firestore, 'users', userCredential.user.uid));
            if (userDoc.exists()) {
                const userData = userDoc.data();
                updateUserInfo(userData);
            }
            return { success: true, user: userCredential.user };
        }
    } catch (error) {
        console.error('Login error:', error);
        return { success: false, error: error.message };
    }
}

// Çıkış yapma fonksiyonu
export async function logout() {
    try {
        await signOut(auth);
        window.location.replace('/register.html');
    } catch (error) {
        console.error('Logout error:', error);
        throw error;
    }
}

// Kullanıcı bilgilerini güncelleme fonksiyonu
export function updateUserInfo(userData) {
    try {
        // Kullanıcı adını güncelle
        const userDisplayName = document.getElementById('userDisplayName');
        if (userDisplayName) {
            userDisplayName.textContent = userData.fullName || 'Kullanıcı';
        }

        // Profil sayfası elementlerini güncelle
        const profileElements = {
            'fullNameValue': userData.fullName,
            'emailValue': userData.email,
            'roleValue': userData.role,
            'isActiveValue': userData.isActive ? '✅ Aktif' : '❌ Pasif',
            'createdAtValue': userData.createdAt ? new Date(userData.createdAt).toLocaleString('tr-TR') : 'Belirtilmemiş'
        };

        Object.entries(profileElements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value || 'Belirtilmemiş';
            }
        });
    } catch (error) {
        console.error('Kullanıcı bilgileri güncellenirken hata:', error);
    }
} 