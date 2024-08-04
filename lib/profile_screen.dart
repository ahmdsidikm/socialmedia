import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'PostDetailScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<dynamic>> _userPostsFuture;

  @override
  void initState() {
    super.initState();
    _userPostsFuture = _fetchUserPosts();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: Center(
          child: Text('User tidak terautentikasi'),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _userPostsFuture,
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profil'),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profil'),
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final posts = snapshot.data ?? [];
        final email = user.email ?? 'Unknown';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Postingan Saya'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email: $email',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: posts.isEmpty
                      ? Center(child: Text('Tidak ada postingan'))
                      : ListView.builder(
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            final createdAt =
                                DateTime.parse(post['created_at']);
                            final formattedDate = timeago.format(createdAt);

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.blue, width: 2),
                              ),
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  post['content'],
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (post['image_url'] != null)
                                      Image.network(
                                        post['image_url'],
                                        height: 50,
                                        width: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      _showDeleteConfirmation(post['id']),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(
                                        postId: post['id'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _fetchUserPosts() async {
    final user = supabase.auth.currentUser;
    if (user?.email == null) {
      return [];
    }

    try {
      final response = await supabase
          .from('posts')
          .select('id, content, created_at, image_url')
          .eq('username', user!.email as Object)
          .order('created_at', ascending: false);

      return response as List<dynamic>;
    } catch (error) {
      print('Error fetching user posts: $error');
      return [];
    }
  }

  Future<void> _showDeleteConfirmation(int postId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Penghapusan'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Apakah Anda yakin ingin menghapus postingan ini?'),
                Text('Tindakan ini tidak dapat dibatalkan.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Hapus'),
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost(postId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(int postId) async {
    try {
      await supabase.from('posts').delete().eq('id', postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Postingan berhasil dihapus')),
      );
      setState(() {
        _userPostsFuture = _fetchUserPosts();
      });
    } catch (error) {
      print('Error deleting post: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus postingan')),
      );
    }
  }
}
