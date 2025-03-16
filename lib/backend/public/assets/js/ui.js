// İçerik gösterme fonksiyonu
export function showContent(contentType) {
    document.getElementById('dashboardContent').style.display = 'none';
    document.getElementById('statisticsContent').style.display = 'none';
    document.getElementById('profileContent').style.display = 'none';
    document.getElementById('settingsContent').style.display = 'none';
    
    document.getElementById(`${contentType}Content`).style.display = 'block';
    
    // Aktif menü öğesini güncelle
    document.querySelectorAll('.sidebar-menu a').forEach(a => {
        a.classList.remove('active');
        if(a.getAttribute('onclick').includes(contentType)) {
            a.classList.add('active');
        }
    });
}

// Sidebar toggle fonksiyonu
export function toggleSidebar() {
    const sidebar = document.querySelector('.sidebar');
    sidebar.classList.toggle('active');
}

// Event listener'ları ekle
document.addEventListener('DOMContentLoaded', () => {
    const mainContent = document.querySelector('.main-content');
    if (mainContent) {
        mainContent.addEventListener('click', () => {
            const sidebar = document.querySelector('.sidebar');
            if (sidebar && sidebar.classList.contains('active')) {
                sidebar.classList.remove('active');
            }
        });
    }
}); 