import { 
    auth, 
    firestore,
    collection,
    doc,
    getDoc,
    getDocs,
    query,
    where,
    orderBy,
    limit,
    startAfter,
    serverTimestamp
} from './firebaseConfig.js';

// Tüm işleri yükleme fonksiyonu
export async function loadAllJobs() {
    try {
        console.log('İşler yüklenmeye başlıyor...');
        const jobsContainer = document.getElementById('allJobs');
        const loadingIndicator = document.getElementById('loadingIndicator');
        const emptyState = document.getElementById('emptyState');

        if (!jobsContainer) {
            console.error('allJobs ID\'li container bulunamadı!');
            return;
        }

        // Önce mevcut içeriği temizle
        jobsContainer.innerHTML = '';
        
        // Loading durumunu göster
        if (loadingIndicator) {
            loadingIndicator.style.display = 'block';
            loadingIndicator.style.position = 'relative';
            loadingIndicator.style.marginTop = '20px';
        }
        if (emptyState) emptyState.style.display = 'none';

        console.log('Firestore\'dan işler çekiliyor...');
        const jobsRef = collection(firestore, 'jobs');
        const q = query(jobsRef, orderBy('createdAt', 'desc'));
        const querySnapshot = await getDocs(q);
        
        console.log(`${querySnapshot.docs.length} adet iş bulundu`);

        if (querySnapshot.empty) {
            if (loadingIndicator) loadingIndicator.style.display = 'none';
            if (emptyState) emptyState.style.display = 'block';
            return;
        }

        const jobs = [];
        for (const jobDoc of querySnapshot.docs) {
            try {
                console.log(`İş ID: ${jobDoc.id} işleniyor...`);
                const jobData = jobDoc.data();
                
                if (!jobData.employerId) {
                    console.error(`İş ID: ${jobDoc.id} için employerId bulunamadı`);
                    continue;
                }

                // Kullanıcı bilgilerini çek
                const userRef = doc(firestore, 'users', jobData.employerId);
                const userSnapshot = await getDoc(userRef);
                const userData = userSnapshot.exists() ? userSnapshot.data() : {};

                const createdAt = jobData.createdAt?.toDate?.() || new Date();
                
                const jobCard = `
                    <div class="job-card-container" data-status="${jobData.status || 'active'}">
                        <div class="job-card">
                            <div class="job-card-front">
                                <div class="job-logo-area">
                                    <div class="job-logo">
                                        <i class="fas fa-briefcase"></i>
                                    </div>
                                </div>
                                <div class="job-info-area">
                                    <div class="job-name">${jobData.jobName || 'İsimsiz İş'}</div>
                                    <div class="job-employer">${userData.fullName || 'İsimsiz Kullanıcı'}</div>
                                    <div class="job-contact"><i class="fas fa-map-marker-alt"></i> ${jobData.neighborhood || 'Konum belirtilmemiş'}</div>
                                    <div class="job-contact"><i class="fas fa-calendar-alt"></i> ${createdAt.toLocaleDateString('tr-TR')}</div>
                                    <div class="job-price">₺${jobData.jobPrice?.toLocaleString('tr-TR') || '0'}</div>
                                </div>
                            </div>
                            <div class="job-card-back">
                                <div class="job-description-back">${jobData.jobDescription || 'Açıklama bulunmuyor'}</div>
                                <div class="job-back-details">
                                    <div class="job-status-badge-back ${jobData.status || 'active'}">
                                        <i class="fas fa-circle"></i> ${jobData.status === 'active' ? 'Aktif' : jobData.status === 'completed' ? 'Tamamlandı' : jobData.status === 'cancelled' ? 'İptal Edildi' : 'Aktif'}
                                    </div>
                                    <div class="job-meta-back">
                                        <div class="job-meta-item-back">
                                            <i class="fas fa-heart"></i> ${jobData.likes || 0} Beğeni
                                        </div>
                                        <div class="job-meta-item-back">
                                            <i class="fas fa-eye"></i> ${jobData.views || 0} Görüntülenme
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
                
                jobs.push(jobCard);
                console.log(`İş ID: ${jobDoc.id} başarıyla işlendi`);

            } catch (docError) {
                console.error('Belge işlenirken hata:', docError);
                continue;
            }
        }

        // Loading durumunu gizle
        if (loadingIndicator) loadingIndicator.style.display = 'none';

        // Tüm kartları bir kerede ekle
        if (jobs.length > 0) {
            jobsContainer.innerHTML = jobs.join('');
            if (emptyState) emptyState.style.display = 'none';
        } else {
            if (emptyState) emptyState.style.display = 'block';
        }

        console.log('İşler başarıyla yüklendi ve görüntülendi.');
        return true;

    } catch (error) {
        console.error('İşler yüklenirken kritik hata:', error);
        const jobsContainer = document.getElementById('allJobs');
        const loadingIndicator = document.getElementById('loadingIndicator');
        const emptyState = document.getElementById('emptyState');
        
        if (loadingIndicator) loadingIndicator.style.display = 'none';
        if (emptyState) emptyState.style.display = 'none';
        
        if (jobsContainer) {
            jobsContainer.innerHTML = `
                <div class="error">
                    <p>Veriler yüklenirken bir hata oluştu:</p>
                    <p class="error-message">${error.message}</p>
                </div>
            `;
        }
        return false;
    }
}

// İş istatistiklerini yükleme fonksiyonu
export async function loadJobStats(userId) {
    try {
        console.log('İş istatistikleri yükleniyor...');
        const jobsRef = collection(firestore, 'jobs');
        const querySnapshot = await getDocs(jobsRef);
        
        const stats = {
            total: 0,
            active: 0,
            completed: 0,
            totalLikes: 0
        };
        
        querySnapshot.forEach((doc) => {
            const job = doc.data();
            stats.total++;
            
            // İş durumuna göre sayaçları güncelle
            switch(job.status) {
                case 'active':
                    stats.active++;
                    break;
                case 'completed':
                    stats.completed++;
                    break;
            }
            
            // Beğeni sayısını güncelle
            if (job.likes) {
                stats.totalLikes += Number(job.likes);
            }
        });
        
        // İstatistikleri DOM'a uygula
        const elements = {
            total: document.getElementById('totalJobs'),
            active: document.getElementById('activeJobs'),
            completed: document.getElementById('completedJobs'),
            totalLikes: document.getElementById('totalLikes')
        };
        
        // Her bir elementi kontrol et ve varsa güncelle
        Object.entries(elements).forEach(([key, element]) => {
            if (element) {
                element.textContent = stats[key];
            }
        });
        
        console.log('İş istatistikleri yüklendi:', stats);
        return stats;
        
    } catch (error) {
        console.error('İş istatistikleri yüklenirken hata:', error);
        showError('İstatistikler yüklenirken bir hata oluştu: ' + error.message);
        throw error;
    }
}

// Kategori istatistiklerini yükleme fonksiyonu
export async function loadCategoryStats() {
    try {
        console.log('Kategori istatistikleri yükleniyor...');
        const jobsRef = collection(firestore, 'jobs');
        const querySnapshot = await getDocs(jobsRef);
        
        const categoryStats = {};
        
        querySnapshot.forEach((doc) => {
            const job = doc.data();
            const category = job.category || 'Diğer';
            
            if (!categoryStats[category]) {
                categoryStats[category] = 0;
            }
            categoryStats[category]++;
        });
        
        console.log('Kategori istatistikleri yüklendi:', categoryStats);
        return categoryStats;
        
    } catch (error) {
        console.error('Kategori istatistikleri yüklenirken hata:', error);
        return null;
    }
}

// Aylık istatistikleri yükleme fonksiyonu
export async function loadMonthlyStats() {
    try {
        console.log('Aylık istatistikler yükleniyor...');
        const jobsRef = collection(firestore, 'jobs');
        const sixMonthsAgo = new Date();
        sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
        
        const q = query(
            jobsRef,
            where('createdAt', '>=', serverTimestamp().before(sixMonthsAgo)),
            orderBy('createdAt', 'asc')
        );
        
        const querySnapshot = await getDocs(q);
        const monthlyStats = {};
        
        querySnapshot.forEach((doc) => {
            const job = doc.data();
            const date = job.createdAt.toDate();
            const monthYear = `${date.getMonth() + 1}/${date.getFullYear()}`;
            
            if (!monthlyStats[monthYear]) {
                monthlyStats[monthYear] = 0;
            }
            monthlyStats[monthYear]++;
        });
        
        console.log('Aylık istatistikler yüklendi:', monthlyStats);
        return monthlyStats;
        
    } catch (error) {
        console.error('Aylık istatistikler yüklenirken hata:', error);
        return null;
    }
}

// Son işleri yükleme fonksiyonu
export async function loadRecentJobs() {
    try {
        console.log('Son işler yükleniyor...');
        const jobsRef = collection(firestore, 'jobs');
        const q = query(
            jobsRef,
            orderBy('createdAt', 'desc'),
            limit(5)
        );
        
        const querySnapshot = await getDocs(q);
        const recentJobs = [];
        
        querySnapshot.forEach((doc) => {
            const job = doc.data();
            const createdDate = job.createdAt && typeof job.createdAt.toDate === 'function' 
                ? job.createdAt.toDate() 
                : new Date(job.createdAt);
                
            recentJobs.push({
                id: doc.id,
                title: job.title,
                category: job.category,
                status: job.status,
                createdAt: createdDate
            });
        });
        
        // Son işleri DOM'a ekle
        const recentJobsList = document.getElementById('recentJobsList');
        if (recentJobsList) {
            recentJobsList.innerHTML = '';
            
            recentJobs.forEach(job => {
                const li = document.createElement('li');
                li.className = 'recent-job-item';
                li.innerHTML = `
                    <div class="job-title">${job.title}</div>
                    <div class="job-category">${job.category}</div>
                    <div class="job-status ${job.status}">${job.status}</div>
                    <div class="job-date">${job.createdAt.toLocaleDateString()}</div>
                `;
                recentJobsList.appendChild(li);
            });
        }
        
        console.log('Son işler yüklendi:', recentJobs);
        return recentJobs;
        
    } catch (error) {
        console.error('Son işler yüklenirken hata:', error);
        return null;
    }
}

// Hata gösterme fonksiyonu
function showError(message) {
    const containers = [
        document.querySelector('.stats-container'),
        document.querySelector('.category-stats'),
        document.getElementById('recentJobs')
    ];

    containers.forEach(container => {
        if (container) {
            container.innerHTML = `
                <div class="error-message">
                    <p>${message}</p>
                </div>
            `;
        }
    });
}

// Grafikleri oluştur
export function createCategoryChart(data) {
    const ctx = document.getElementById('categoryChart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: Object.keys(data),
            datasets: [{
                data: Object.values(data),
                backgroundColor: [
                    '#FF6384',
                    '#36A2EB',
                    '#FFCE56',
                    '#4BC0C0',
                    '#9966FF'
                ]
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    position: 'right'
                },
                title: {
                    display: true,
                    text: 'Kategori Dağılımı'
                }
            }
        }
    });
}

export function createMonthlyChart(data) {
    const ctx = document.getElementById('monthlyChart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: Object.keys(data),
            datasets: [{
                label: 'Aylık İş Sayısı',
                data: Object.values(data),
                borderColor: '#36A2EB',
                tension: 0.1
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    position: 'top'
                },
                title: {
                    display: true,
                    text: 'Aylık İş Dağılımı'
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1
                    }
                }
            }
        }
    });
} 