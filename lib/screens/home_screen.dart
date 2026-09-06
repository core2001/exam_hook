import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard.dart';

const String adminSecretCode = '63-1678367V27PURE';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();

  String selectedCourse = 'All';
  String searchQuery = '';
  List<String> subjects = ['All', 'Maths', 'Physics', 'Chemistry', 'Biology'];
  Set<String> likedDocs = {};
  Set<String> ratedDocs = {}; // prevent multiple ratings

  @override
  void initState() {
    super.initState();
    _checkTerms();
  }

  Future<void> _checkTerms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool accepted = prefs.getBool('terms_accepted')?? false;
    if (!accepted && mounted) {
      _showTermsDialog();
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Terms & Conditions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            'By using ExamHook you agree to:\n\n'
            '1. Resources are for educational purposes only.\n'
            '2. Do not redistribute files without permission.\n'
            '3. Admin reserves the right to remove content.\n'
            '4. We collect anonymous usage stats to improve the app.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('terms_accepted', true);
              Navigator.pop(context);
            },
            child: const Text('Accept', style: TextStyle(color: Color(0xFF00C896))),
          ),
        ],
      ),
    );
  }

  void _showRequestDialog() {
    _requestController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Notes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _requestController,
          decoration: const InputDecoration(
            labelText: 'What subject/topic do you need?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_requestController.text.isNotEmpty) {
                await _firestore.collection('requests').add({
                  'subject': _requestController.text,
                  'message': 'User requested: ${_requestController.text}',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request sent to Admin!'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896)),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _openLink(String docId, String url) async {
    await _firestore.collection('resources').doc(docId).update({
      'downloads': FieldValue.increment(1)
    });
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _likeResource(String docId) async {
    if (likedDocs.contains(docId)) return;
    await _firestore.collection('resources').doc(docId).update({'likes': FieldValue.increment(1)});
    setState(() => likedDocs.add(docId));
  }

  void _rateResource(String docId, double rating) async {
    if (ratedDocs.contains(docId)) return; // 1 rating per user session
    DocumentSnapshot doc = await _firestore.collection('resources').doc(docId).get();
    double currentRating = doc['rating']?? 0.0;
    int ratingCount = doc['ratingCount']?? 0;
    double newRating = ((currentRating * ratingCount) + rating) / (ratingCount + 1);
    await _firestore.collection('resources').doc(docId).update({
      'rating': newRating,
      'ratingCount': FieldValue.increment(1)
    });
    setState(() => ratedDocs.add(docId));
  }

  void _checkSecretCode(String value) {
    if (value.trim() == adminSecretCode) {
      _searchController.clear();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin Access Granted'), backgroundColor: Colors.green),
      );
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF00C896);
    const Color secondaryBlue = Color(0xFF3B82F6);

    return Scaffold(
      appBar: AppBar(
        title: Text('ExamHook', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.mail_outline), onPressed: _showRequestDialog), // Request button
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // DARK HEADER WITH IMAGE ICON
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Replace with Image.asset('assets/logo.png') if you have logo
                  const Icon(Icons.school, size: 60, color: Colors.white),
                  const SizedBox(height: 10),
                  Text('ExamHook', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Subjects', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  String subject = subjects[index];
                  return ListTile(
                    leading: Icon(Icons.book, color: primaryGreen),
                    title: Text(subject, style: GoogleFonts.poppins()),
                    selected: selectedCourse == subject,
                    selectedTileColor: primaryGreen.withOpacity(0.1),
                    onTap: () {
                      setState(() => selectedCourse = subject);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.description, color: primaryGreen),
              title: Text('Terms & Conditions', style: GoogleFonts.poppins()),
              onTap: _showTermsDialog,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search or enter admin code',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (val) {
                setState(() => searchQuery = val.toLowerCase());
                _checkSecretCode(val);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: selectedCourse,
              decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: subjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => selectedCourse = val!),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No resources yet', style: GoogleFonts.poppins()));

                var docs = snapshot.data!.docs;
                if (selectedCourse!= 'All') docs = docs.where((d) => d['course'] == selectedCourse).toList();
                if (searchQuery.isNotEmpty) {
                  docs = docs.where((d) =>
                    d['title'].toString().toLowerCase().contains(searchQuery) ||
                    d['course'].toString().toLowerCase().contains(searchQuery)
                  ).toList();
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;
                    bool isLiked = likedDocs.contains(docId);
                    bool isRated = ratedDocs.contains(docId);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.picture_as_pdf, color: primaryGreen, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['title']?? 'No Title', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                                      Text('${data['course']} • ${data['examType']}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_for_offline, color: secondaryBlue, size: 30),
                                  onPressed: () => _openLink(docId, data['fileUrl']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDate(data['uploadedAt']), style: GoogleFonts.poppins(fontSize: 11)),
                                const SizedBox(width: 12),
                                Icon(Icons.data_object, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatBytes(data['fileSize']?? 0), style: GoogleFonts.poppins(fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  IconButton(
                                    icon: Icon(Icons.favorite, color: isLiked? Colors.red : Colors.grey, size: 20),
                                    onPressed: () => _likeResource(docId),
                                  ),
                                  Text('${data['likes']?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                ]),
                                Row(children: [
                                  Icon(Icons.star, color: Colors.amber, size: 20),
                                  Text(' ${data['rating']?.toStringAsFixed(1)?? '0.0'}', style: GoogleFonts.poppins(fontSize: 12)),
                                  PopupMenuButton<double>(
                                    enabled:!isRated,
                                    onSelected: (val) => _rateResource(docId, val),
                                    itemBuilder: (context) => [1,2,3,4,5].map((e) => PopupMenuItem(value: e.toDouble(), child: Text('$e Star'))).toList(),
                                    child: Icon(Icons.rate_review, size: 20, color: isRated? Colors.grey : Colors.black),
                                  )
                                ]),
                                Row(children: [
                                  Icon(Icons.download, color: Colors.blue, size: 20),
                                  Text(' ${data['downloads']?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                ]),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}