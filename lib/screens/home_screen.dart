import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_media_app/PostDetailScreen.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _getPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postContentController.dispose();
    super.dispose();
  }

  Future<void> _addPost() async {
    final content = _postContentController.text.trim();
    final defaultUsername = "Anonymous";

    if (content.isNotEmpty) {
      try {
        await _supabase.from('posts').insert({
          'username': defaultUsername,
          'content': content,
          'views': 0,
        });

        _postContentController.clear();
        await _refreshPosts();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding post: $error')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter content')),
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
          .select('id, content, created_at, username, views')
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
      print('Error fetching posts: $error');
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
      print('Error updating views: $error');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _getPosts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Postingan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _postContentController,
                    decoration: InputDecoration(
                      hintText: 'Apa yang Anda pikirkan?',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addPost,
                  child: const Text('Kirim Postingan'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                _posts.isEmpty && !_isLoading
                    ? Center(child: Text('Tidak ada postingan'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _posts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _posts.length) {
                            return _isLoading
                                ? Center(child: CircularProgressIndicator())
                                : SizedBox.shrink();
                          }

                          final post = _posts[index];
                          final createdAt = DateTime.parse(post['created_at']);
                          final formattedDate = timeago.format(createdAt);

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    Icons.remove_red_eye,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post['views']} views',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'by ${post['username']} pada $formattedDate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                post['content'],
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              onTap: () {
                                _incrementViews(post['id']);
                                _navigateToPostDetail(post['id']);
                              },
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
