import 'dart:io';
import 'package:flutter/material.dart';
import 'package:social_media_app/profile_screen.dart';
import 'package:social_media_app/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_media_app/PostDetailScreen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _postContentController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _currentPage = 0;
  final int _postsPerPage = 10;
  List<Map<String, dynamic>> _posts = [];
  late ScrollController _scrollController;
  bool _hasMorePosts = true;
  final int _maxLines = 5;
  final int _maxChars = 200;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _getPosts();
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postContentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final response = await _supabase
          .from('profiles')
          .select('photo_url')
          .eq('id', user.id)
          .single();
      setState(() {
        _profilePhotoUrl = response['photo_url'];
      });
    }
  }

  Future<void> _editProfilePhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File file = File(image.path);
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final user = _supabase.auth.currentUser;

      try {
        await _supabase.storage.from('profile_photos').upload(fileName, file);
        final String imageUrl =
            _supabase.storage.from('profile_photos').getPublicUrl(fileName);

        await _supabase.from('profiles').upsert({
          'id': user!.id,
          'photo_url': imageUrl,
        });

        setState(() {
          _profilePhotoUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memperbarui foto profil: $error')),
        );
      }
    }
  }

  Future<void> _addPost() async {
    final content = _postContentController.text.trim();
    final user = _supabase.auth.currentUser;
    final username = user?.email ?? "Anonymous";

    final RegExp imageUrlRegExp = RegExp(r'\[Image: (.+)\]');
    final RegExpMatch? match = imageUrlRegExp.firstMatch(content);
    String? imageUrl;

    if (match != null) {
      imageUrl = match.group(1);
    }

    if (content.isNotEmpty) {
      try {
        await _supabase.from('posts').insert({
          'username': username,
          'content': content.replaceAll(imageUrlRegExp, '').trim(),
          'views': 0,
          'image_url': imageUrl,
        });

        _postContentController.clear();
        await _refreshPosts();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error menambahkan post: $error')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon masukkan konten')),
      );
    }
  }

  Future<void> _getPosts() async {
    if (_isLoading || !_hasMorePosts) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('posts')
          .select('id, content, created_at, username, views, image_url')
          .order('created_at', ascending: false)
          .range(_currentPage * _postsPerPage,
              (_currentPage + 1) * _postsPerPage - 1);

      if (response.isEmpty) {
        setState(() {
          _hasMorePosts = false;
        });
      } else {
        setState(() {
          if (_currentPage == 0) {
            _posts = List<Map<String, dynamic>>.from(response);
          } else {
            _posts.addAll(List<Map<String, dynamic>>.from(response));
          }
          _currentPage++;
        });
      }
    } catch (error) {
      print('Error mengambil posts: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _incrementViews(int postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('views')
          .eq('id', postId)
          .single();

      final currentViews = response['views'] as int;

      await _supabase
          .from('posts')
          .update({'views': currentViews + 1}).eq('id', postId);

      await _refreshPosts();
    } catch (error) {
      print('Error memperbarui views: $error');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _getPosts();
    } else if (_scrollController.position.pixels == 0) {
      _refreshPosts();
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _posts.clear();
      _currentPage = 0;
      _hasMorePosts = true;
    });
    await _getPosts();
  }

  void _navigateToPostDetail(int postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: postId),
      ),
    );
  }

  Future<void> _uploadImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File file = File(image.path);
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      try {
        await _supabase.storage.from('post_images').upload(fileName, file);
        final String imageUrl =
            _supabase.storage.from('post_images').getPublicUrl(fileName);

        setState(() {
          _postContentController.text += '\n\n[Image: $imageUrl]';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gambar berhasil diunggah')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mengunggah gambar: $error')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await _supabase.auth.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  String _truncateText(String text, int maxLines, int maxChars) {
    final maxLineChars = maxChars * maxLines;
    if (text.length <= maxLineChars) {
      return text;
    } else {
      return text.substring(0, maxLineChars) + '... Baca Selengkapnya';
    }
  }

  void _showFullPostContent(BuildContext context, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konten Post'),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final username = user?.email ?? "Anonymous";
    final displayName = username.isNotEmpty ? username : "Anonymous";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                displayName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                displayName.isEmpty ? "by Anonymous" : "",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              currentAccountPicture: GestureDetector(
                onTap: _editProfilePhoto,
                child: CircleAvatar(
                  backgroundColor: Colors.blue,
                  backgroundImage: _profilePhotoUrl != null
                      ? NetworkImage(_profilePhotoUrl!)
                      : null,
                  child: _profilePhotoUrl == null
                      ? const Icon(Icons.camera_alt)
                      : null,
                ),
              ),
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Postingan Saya'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            final content = post['content'] as String;
            final postId = post['id'] as int;
            final postUsername = post['username'] as String? ?? "Anonymous";
            final createdAt = DateTime.parse(post['created_at'] as String);
            final timeAgo = timeago.format(createdAt);
            final views = post['views'] as int;
            final imageUrl = post['image_url'] as String?;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.blue),
              ),
              child: ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postUsername,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      postUsername.isEmpty ? "by Anonymous" : "",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showFullPostContent(context, content),
                      child: Text(
                        _truncateText(content, _maxLines, _maxChars),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.remove_red_eye,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$views',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  _incrementViews(postId);
                  _navigateToPostDetail(postId);
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Tambah Post'),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _postContentController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Tulis sesuatu...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_postContentController.text.contains('[Image: '))
                        const Text('Gambar telah ditambahkan'),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _uploadImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Tambahkan Gambar'),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () {
                      _addPost();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Post'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
