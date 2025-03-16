import { 
    auth, 
    firestore,
    GoogleAuthProvider,
    FacebookAuthProvider,
    TwitterAuthProvider,
    signInWithPopup,
    doc,
    setDoc
} from './firebaseConfig.js';

// Sosyal medya sağlayıcıları
const googleProvider = new GoogleAuthProvider();
const facebookProvider = new FacebookAuthProvider();
const twitterProvider = new TwitterAuthProvider();

// Google ile giriş
export async function signInWithGoogle() {
    try {
        const result = await signInWithPopup(auth, googleProvider);
        if (result.user) {
            await setDoc(doc(firestore, 'users', result.user.uid), {
                fullName: result.user.displayName,
                email: result.user.email,
                createdAt: new Date().toISOString(),
                userId: result.user.uid
            }, { merge: true });
            window.location.replace('./homepage.html');
        }
    } catch (error) {
        console.error('Google login error:', error);
        alert('Google ile giriş hatası: ' + error.message);
    }
}

// Facebook ile giriş
export async function signInWithFacebook() {
    try {
        const result = await signInWithPopup(auth, facebookProvider);
        if (result.user) {
            await setDoc(doc(firestore, 'users', result.user.uid), {
                fullName: result.user.displayName,
                email: result.user.email,
                createdAt: new Date().toISOString(),
                userId: result.user.uid
            }, { merge: true });
            window.location.replace('./homepage.html');
        }
    } catch (error) {
        console.error('Facebook login error:', error);
        alert('Facebook ile giriş hatası: ' + error.message);
    }
}

// Twitter ile giriş
export async function signInWithTwitter() {
    try {
        const result = await signInWithPopup(auth, twitterProvider);
        if (result.user) {
            await setDoc(doc(firestore, 'users', result.user.uid), {
                fullName: result.user.displayName,
                email: result.user.email,
                createdAt: new Date().toISOString(),
                userId: result.user.uid
            }, { merge: true });
            window.location.replace('./homepage.html');
        }
    } catch (error) {
        console.error('Twitter login error:', error);
        alert('Twitter ile giriş hatası: ' + error.message);
    }
} 