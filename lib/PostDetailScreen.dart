import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final int postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final Map<int, TextEditingController> _commentControllers = {};
  final _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _postFuture;
  late Future<List<Map<String, dynamic>>> _commentsFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = _getPost(widget.postId);
    _commentsFuture = _getComments(widget.postId);
    _setupTextController();
    _updateViews(widget.postId); // Update views count when screen is loaded
    _onRefresh(); // Refresh the page when it is opened
  }

  void _setupTextController() {
    final controller = _commentControllers.putIfAbsent(
      widget.postId,
      () => TextEditingController(),
    );

    controller.addListener(() {
      final text = controller.text;
      if (text.length > 200) {
        controller.text = text.substring(0, 200);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Komentar tidak boleh melebihi 200 karakter')),
        );
      }
    });
  }

  Future<Map<String, dynamic>> _getPost(int postId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id, content, created_at, username, likes, views')
          .eq('id', postId)
          .single();
      return response;
    } catch (error) {
      print('Error fetching post: $error');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getComments(int postId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('id, content, created_at, username')
          .eq('post_id', postId)
          .order('created_at');
      return response;
    } catch (error) {
      print('Error fetching comments: $error');
      return [];
    }
  }

  Future<void> _addComment(int postId) async {
    final content = _commentControllers[postId]?.text.trim() ?? '';
    final defaultUsername = "Anonymous";

    if (content.isNotEmpty && content.length <= 200) {
      try {
        await _supabase.from('comments').insert({
          'post_id': postId,
          'username': defaultUsername,
          'content': content,
        });

        _commentControllers[postId]?.clear();
        _refreshComments(postId);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $error')),
        );
      }
    } else if (content.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Komentar tidak boleh melebihi 200 karakter')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan konten')),
      );
    }
  }

  Future<void> _refreshComments(int postId) async {
    setState(() {
      _commentsFuture = _getComments(postId);
    });
  }

  Future<void> _onRefresh() async {
    // Refresh both post and comments
    setState(() {
      _postFuture = _getPost(widget.postId);
      _commentsFuture = _getComments(widget.postId);
    });
  }

  Future<void> _updateViews(int postId) async {
    try {
      // Menggunakan transaksi untuk memastikan konsistensi data
      await _supabase.rpc('increment_views', params: {'row_id': postId});
      print('Updated views for post $postId');
    } catch (error) {
      print('Error updating views: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Postingan'),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<Map<String, dynamic>>(
                      future: _postFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError || !snapshot.hasData) {
                          return Center(
                              child: Text(
                                  'Error loading post: ${snapshot.error}'));
                        }

                        final post = snapshot.data!;
                        final postDate = DateTime.parse(post['created_at']);
                        final postTimeAgo =
                            timeago.format(postDate, locale: 'id');
                        final views = post['views'] as int;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border:
                                    Border.all(color: Colors.blue, width: 1.0),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['content'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'by ${post['username']} ${postTimeAgo}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Divider(color: Colors.blue, thickness: 1.0),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.remove_red_eye,
                                          color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        '$views views',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Divider(color: Colors.grey[300], thickness: 1),
                            SizedBox(height: 16),
                            Text(
                              'Komentar:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 16),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _commentsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return Center(
                                      child: Text(
                                          'Error loading comments: ${snapshot.error}'));
                                } else if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Center(
                                      child: Text('Tidak ada komentar'));
                                }

                                final comments = snapshot.data!;

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    final comment = comments[index];
                                    final commentDate =
                                        DateTime.parse(comment['created_at']);
                                    final commentTimeAgo = timeago
                                        .format(commentDate, locale: 'id');

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Colors.blue, width: 1.0),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      padding: const EdgeInsets.all(12.0),
                                      margin:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment['content'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'oleh ${comment['username']} ${commentTimeAgo}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  constraints: BoxConstraints(maxHeight: 150),
                  child: TextField(
                    controller: _commentControllers[widget.postId],
                    decoration: InputDecoration(
                      hintText: 'Tulis Komentar',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _addComment(widget.postId),
                  child: const Text('Kirim Komentar'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Color.fromARGB(255, 255, 255, 255),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
