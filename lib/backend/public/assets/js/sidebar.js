import { logout } from './auth.js';

// Make logout function available globally
window.logout = logout;

// Sidebar'ı yükle
export async function loadSidebar() {
    try {
        const response = await fetch('/components/sidebar.html');
        const sidebarHtml = await response.text();
        
        // Sidebar container oluştur ve içeriği ekle
        const sidebarContainer = document.createElement('div');
        sidebarContainer.innerHTML = sidebarHtml;
        document.body.insertBefore(sidebarContainer.firstElementChild, document.body.firstChild);
        
        // Mobil menü butonunu ekle
        document.body.appendChild(sidebarContainer.lastElementChild);
        
        // Aktif menü öğesini işaretle
        setActiveMenuItem();
        
    } catch (error) {
        console.error('Sidebar yüklenirken hata:', error);
    }
}

// Aktif menü öğesini işaretle
function setActiveMenuItem() {
    const currentPath = window.location.pathname;
    const menuItems = document.querySelectorAll('.sidebar-menu a');
    
    menuItems.forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('href') === currentPath) {
            item.classList.add('active');
        }
    });
} 