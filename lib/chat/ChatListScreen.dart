import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/chat/chatpage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = true;
  bool _isInitialized = false;
  late SharedPreferences _prefs;
  final String _chatsCacheKey = 'chats_cache';
  final String _lastFetchTimeKey = 'chats_last_fetch';
  final String _searchWidthKey = 'search_width_pref';
  final String _searchHeightKey = 'search_height_pref';

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _filteredChatRooms = [];
  
  // Arama alanı boyutları için değişkenler
  double _searchFieldWidth = 0.7; // Ekran genişliğinin yüzdesi olarak (varsayılan %70)
  double _searchFieldHeight = 40.0; // Piksel cinsinden yükseklik (varsayılan 40px)

  @override
  void initState() {
    super.initState();
    _quickInit();
    _loadSearchPreferences();
  }
  
  // Arama alanı tercihlerini yükle
  Future<void> _loadSearchPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedWidth = _prefs.getDouble(_searchWidthKey);
      final savedHeight = _prefs.getDouble(_searchHeightKey);
      
      if (mounted) {
        setState(() {
          if (savedWidth != null) _searchFieldWidth = savedWidth;
          if (savedHeight != null) _searchFieldHeight = savedHeight;
        });
      }
    } catch (e) {
      print('Arama tercihleri yükleme hatası: $e');
    }
  }
  
  // Arama alanı genişliği tercihini kaydet
  Future<void> _saveSearchWidthPreference(double width) async {
    try {
      await _prefs.setDouble(_searchWidthKey, width);
    } catch (e) {
      print('Arama genişliği tercihi kaydetme hatası: $e');
    }
  }
  
  // Arama alanı yüksekliği tercihini kaydet
  Future<void> _saveSearchHeightPreference(double height) async {
    try {
      await _prefs.setDouble(_searchHeightKey, height);
    } catch (e) {
      print('Arama yüksekliği tercihi kaydetme hatası: $e');
    }
  }

  Future<void> _quickInit() async {
    // Önce cache'den yükle
    await _loadCachedChats();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    // Arka planda Firestore'dan yükle
    await _fetchChatRooms();
  }

  Future<void> _loadCachedChats() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final chatsJson = _prefs.getString(_chatsCacheKey);

      if (chatsJson != null) {
        final List<dynamic> decodedChats = json.decode(chatsJson);
        if (mounted) {
          setState(() {
            _chatRooms = List<Map<String, dynamic>>.from(decodedChats);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Cache yükleme hatası: $e');
    }
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 5,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0,
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
            ),
            title: Container(
              width: 140,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchChatRooms() async {
    String currentUserId = _auth.currentUser!.uid;
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('chats')
          .where('users', arrayContains: currentUserId)
          .get();

      List<Map<String, dynamic>> chatRooms = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> chatRoomData = doc.data() as Map<String, dynamic>;
        List<String> users = List<String>.from(chatRoomData['users'] ?? []);
        String otherUserId = users.firstWhere((user) => user != currentUserId);

        String otherUserName = await _fetchOtherUserName(otherUserId);
        String otherUserProfileImageUrl =
            await _fetchOtherUserProfileImageUrl(otherUserId);

        chatRooms.add({
          'chatId': doc.id,
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'otherUserProfileImageUrl': otherUserProfileImageUrl,
          'lastMessage': chatRoomData['lastMessage'] ?? '',
          'lastMessageTime': (chatRoomData['lastMessageTime'] as Timestamp?)
                  ?.toDate()
                  ?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Son mesaj tarihine göre sırala
      chatRooms
          .sort((a, b) => b['lastMessageTime'].compareTo(a['lastMessageTime']));

      // Cache'i güncelle
      await _prefs.setString(_chatsCacheKey, json.encode(chatRooms));
      await _prefs.setInt(
          _lastFetchTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _chatRooms = chatRooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Sohbet odaları yükleme hatası: $e');
    }
  }

  Future<String> _fetchOtherUserName(String otherUserId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      if (userDoc.exists) {
        return userDoc['username'] ?? '';
      }
    } catch (e) {
      print('Kullanıcı adı çekme hatası: $e');
    }
    return 'Bilinmeyen Kullanıcı';
  }

  Future<String> _fetchOtherUserProfileImageUrl(String otherUserId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      if (userDoc.exists) {
        return userDoc['profileImageUrl'] ??
            'https://randomuser.me/api/portraits/men/1.jpg';
      }
    } catch (e) {
      print('Profil fotoğrafı çekme hatası: $e');
    }
    return 'https://randomuser.me/api/portraits/men/1.jpg';
  }
  
  // Arama alanı boyutlarını ayarlamak için bottom sheet
  void _showSearchSizeSettings() {
    // Değerleri sınırlar içinde tutmak için yuvarlama işlemi
    double tempWidth = _searchFieldWidth;
    if (tempWidth > 0.9) tempWidth = 0.9;
    if (tempWidth < 0.3) tempWidth = 0.3;
    
    double tempHeight = _searchFieldHeight;
    if (tempHeight > 70) tempHeight = 70;
    if (tempHeight < 30) tempHeight = 30;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Tam yükseklikte açılmasını sağlar
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kaydırma çubuğu
                      Container(
                        width: 40,
                        height: 5,
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Text(
                        'Arama Alanı Boyutları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Genişlik ayarı
                      Text(
                        'Genişlik: ${(tempWidth * 100).round()}%',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Icon(Icons.width_normal, size: 24),
                          Expanded(
                            child: Slider(
                              value: tempWidth,
                              min: 0.3,
                              max: 0.9,
                              divisions: 12,
                              label: '${(tempWidth * 100).round()}%',
                              onChanged: (value) {
                                // Değeri sınırlar içinde tut
                                double safeValue = value;
                                if (safeValue > 0.9) safeValue = 0.9;
                                if (safeValue < 0.3) safeValue = 0.3;
                                
                                setModalState(() {
                                  tempWidth = safeValue;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 10),
                      
                      // Yükseklik ayarı
                      Text(
                        'Yükseklik: ${tempHeight.round()}px',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Icon(Icons.height, size: 24),
                          Expanded(
                            child: Slider(
                              value: tempHeight,
                              min: 30,
                              max: 70,
                              divisions: 8,
                              label: '${tempHeight.round()}px',
                              onChanged: (value) {
                                // Değeri sınırlar içinde tut
                                double safeValue = value;
                                if (safeValue > 70) safeValue = 70;
                                if (safeValue < 30) safeValue = 30;
                                
                                setModalState(() {
                                  tempHeight = safeValue;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 15),
                      
                      // Önizleme
                      Text('Önizleme:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Container(
                        width: MediaQuery.of(context).size.width * tempWidth,
                        height: tempHeight,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 20, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sohbet ara...',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Kaydet butonu
                      ElevatedButton(
                        onPressed: () {
                          // Değerleri sınırlar içinde tut
                          double safeWidth = tempWidth;
                          if (safeWidth > 0.9) safeWidth = 0.9;
                          if (safeWidth < 0.3) safeWidth = 0.3;
                          
                          double safeHeight = tempHeight;
                          if (safeHeight > 70) safeHeight = 70;
                          if (safeHeight < 30) safeHeight = 30;
                          
                          setState(() {
                            _searchFieldWidth = safeWidth;
                            _searchFieldHeight = safeHeight;
                          });
                          _saveSearchWidthPreference(safeWidth);
                          _saveSearchHeightPreference(safeHeight);
                          Navigator.pop(context);
                        },
                        child: Text('Kaydet'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 45),
                        ),
                      ),
                      SizedBox(height: 10), // Alt kısımda biraz boşluk bırak
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF64B5F6), // Açık mavi
                Color(0xFF42A5F5), // Mavi
                Color(0xFF2196F3), // Koyu mavi
              ],
            ),
          ),
        ),
        title: _isSearching
            ? Container(
                width: MediaQuery.of(context).size.width * _searchFieldWidth,
                height: _searchFieldHeight,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Sohbet ara...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.settings, color: Colors.white70, size: 20),
                      onPressed: _showSearchSizeSettings,
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: _filterChats,
                ),
              )
            : Text('Mesajlar'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredChatRooms = [];
                }
              });
            },
          ),
        ],
      ),
      body: !_isInitialized ? _buildSkeletonLoader() : _buildChatList(),
    );
  }

  Widget _buildChatList() {
    final chatsToShow = _isSearching && _searchController.text.isNotEmpty
        ? _filteredChatRooms
        : _chatRooms;

    if (chatsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 70, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _isSearching ? 'Sohbet bulunamadı' : 'Henüz mesaj yok',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chatsToShow.length,
      itemBuilder: (context, index) {
        final chatRoom = chatsToShow[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0,
          child: ListTile(
            leading: Hero(
              tag: 'profile_${chatRoom['otherUserId']}',
              child: CircleAvatar(
                radius: 25,
                backgroundImage:
                    NetworkImage(chatRoom['otherUserProfileImageUrl']),
                backgroundColor: Colors.grey[200],
              ),
            ),
            title: Text(
              chatRoom['otherUserName'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatRoom['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDateTime(chatRoom['lastMessageTime']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            onTap: () => _navigateToChat(chatRoom),
          ),
        );
      },
    );
  }

  void _filterChats(String query) {
    setState(() {
      _filteredChatRooms = _chatRooms
          .where((chat) => chat['otherUserName']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      final weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return weekDays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _navigateToChat(Map<String, dynamic> chatRoom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          otherUserId: chatRoom['otherUserId'],
          otherUserName: chatRoom['otherUserName'],
          otherUserProfileImageUrl: chatRoom['otherUserProfileImageUrl'],
        ),
      ),
    ).then((_) => _fetchChatRooms()); // Geri döndüğünde sohbetleri yenile
  }
}
