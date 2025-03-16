// Kart çevirme fonksiyonu
export function flipCard() {
    document.querySelector('.card').classList.toggle('flipped');
}

// Sayfa yüklendiğinde event listener'ları ekle
document.addEventListener('DOMContentLoaded', () => {
    // Giriş/Kayıt linkleri için event listener'lar
    const loginLink = document.querySelector('[data-action="login"]');
    const registerLink = document.querySelector('[data-action="register"]');

    if (loginLink) {
        loginLink.addEventListener('click', flipCard);
    }

    if (registerLink) {
        registerLink.addEventListener('click', flipCard);
    }
}); 