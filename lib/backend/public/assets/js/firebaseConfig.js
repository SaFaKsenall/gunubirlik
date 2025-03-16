// Import Firebase modules
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js';
import { 
    getAuth,
    createUserWithEmailAndPassword,
    signInWithEmailAndPassword,
    updateProfile,
    signOut,
    onAuthStateChanged,
    GoogleAuthProvider,
    FacebookAuthProvider,
    TwitterAuthProvider,
    signInWithPopup,
    EmailAuthProvider,
    reauthenticateWithCredential,
    updatePassword,
    updateEmail,
    sendPasswordResetEmail,
    sendEmailVerification,
    verifyBeforeUpdateEmail,
    applyActionCode,
    checkActionCode
} from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js';
import { 
    getFirestore,
    doc,
    setDoc,
    getDoc,
    collection,
    getDocs,
    query,
    where,
    orderBy,
    updateDoc,
    serverTimestamp,
    limit,
    startAfter,
    onSnapshot,
    addDoc,
    deleteDoc,
    writeBatch
} from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js';
import { getDatabase } from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-database.js';
import { getStorage } from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-storage.js';
import { getAnalytics } from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-analytics.js';

// Firebase configuration
const firebaseConfig = {
    apiKey: "AIzaSyBL6tHskC6DgfH3D-Vc3CNjBtfSBT6vcYw",
    appId: "1:30004554015:web:f3032a39d6ddf3f5b1e82a",
    messagingSenderId: "30004554015",
    projectId: "jobapp-14c52",
    authDomain: "jobapp-14c52.firebaseapp.com",
    databaseURL: "https://jobapp-14c52-default-rtdb.firebaseio.com",
    storageBucket: "jobapp-14c52.firebasestorage.app",
    measurementId: "G-0MLT93KQHN"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
const auth = getAuth(app);
const firestore = getFirestore(app);
const database = getDatabase(app);
const storage = getStorage(app);
const analytics = getAnalytics(app);

// Export Firebase services and functions
export { 
    app, 
    auth, 
    firestore, 
    storage, 
    database, 
    analytics,
    // Auth functions
    createUserWithEmailAndPassword,
    signInWithEmailAndPassword,
    updateProfile,
    signOut,
    onAuthStateChanged,
    GoogleAuthProvider,
    FacebookAuthProvider,
    TwitterAuthProvider,
    signInWithPopup,
    EmailAuthProvider,
    reauthenticateWithCredential,
    updatePassword,
    updateEmail,
    sendPasswordResetEmail,
    sendEmailVerification,
    verifyBeforeUpdateEmail,
    applyActionCode,
    checkActionCode,
    // Firestore functions
    doc,
    setDoc,
    getDoc,
    collection,
    getDocs,
    query,
    where,
    orderBy,
    updateDoc,
    serverTimestamp,
    limit,
    startAfter,
    onSnapshot,
    addDoc,
    deleteDoc,
    writeBatch
};