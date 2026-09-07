import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard.dart';

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
  Set<String> likedDocs = {};
  Set<String> ratedDocs = {};
  String _themeMode = 'light'; // NEW: for theme

  // FOR 5-TAP ADMIN ACCESS
  int _tapCount = 0;
  DateTime? _lastTapTime;

  final List<Color> _cardColors = [ // NEW: colorful cards
    const Color(0xFF00C896),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('theme_mode')?? 'light';
    });
    _checkTerms();
  }

  Future<void> _saveTheme(String theme) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', theme);
    setState(() => _themeMode = theme);
  }

  Future<void> _checkTerms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool accepted = prefs.getBool('terms_accepted')?? false;
    if (!accepted && mounted) _showTermsDialog();
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Terms & Conditions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text('By using ExamHook you agree to:\n\n1. Resources are for educational purposes only.\n2. Do not redistribute files without permission.\n3. Admin reserves the right to remove content.\n4. We collect anonymous usage stats to improve the app.', style: GoogleFonts.poppins(fontSize: 14))),
        actions: [TextButton(onPressed: () async {SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.setBool('terms_accepted', true); Navigator.pop(context);}, child: const Text('Accept', style: TextStyle(color: Color(0xFF00C896))))],
      ),
    );
  }

  void _showRequestDialog() {
    _requestController.clear();
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('Request Notes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), content: TextField(controller: _requestController, decoration: const InputDecoration(labelText: 'What subject/topic do you need?', border: OutlineInputBorder()), maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async {if (_requestController.text.isNotEmpty) {await _firestore.collection('requests').add({'subject': _requestController.text, 'message': 'User requested: ${_requestController.text}', 'timestamp': FieldValue.serverTimestamp()}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to Admin!'), backgroundColor: Colors.green));}}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896)), child: const Text('Send Request'))]));
  }

  void _openLink(String docId, String url) async {
    await _firestore.collection('resources').doc(docId).update({'downloads': FieldValue.increment(1)});
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _likeResource(String docId) async {
    if (likedDocs.contains(docId)) return;
    await _firestore.collection('resources').doc(docId).update({'likes': FieldValue.increment(1)});
    setState(() => likedDocs.add(docId));
  }

  void _rateResource(String docId, double rating) async {
    if (ratedDocs.contains(docId)) return;
    DocumentSnapshot doc = await _firestore.collection('resources').doc(docId).get();
    double currentRating = doc['rating']?? 0.0;
    int ratingCount = doc['ratingCount']?? 0;
    double newRating = ((currentRating * ratingCount) + rating) / (ratingCount + 1);
    await _firestore.collection('resources').doc(docId).update({'rating': newRating, 'ratingCount': FieldValue.increment(1)});
    setState(() => ratedDocs.add(docId));
  }

  void _handleHeaderTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin Access Granted'), backgroundColor: Colors.green));
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

  Color _getCardColor(String course) { // NEW: consistent color per subject
    int index = course.hashCode % _cardColors.length;
    return _cardColors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF00C896);
    const Color secondaryBlue = Color(0xFF3B82F6);
    bool isDark = _themeMode == 'dark';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('settings').doc('app').snapshots(),
      builder: (context, settingsSnap) {
        List<String> liveSubjects = ['All', 'Maths', 'Physics', 'Chemistry', 'Biology'];

        if (settingsSnap.hasData && settingsSnap.data!.exists) {
          var data = settingsSnap.data!.data() as Map<String, dynamic>;
          if (data['subjects']!= null) {
            List<String> dbSubjects = List<String>.from(data['subjects']);
            liveSubjects = ['All',...dbSubjects];
          }
        }

        if (!liveSubjects.contains(selectedCourse)) selectedCourse = 'All';

        return Theme( // NEW: Theme wrapper
          data: ThemeData(
            brightness: isDark? Brightness.dark : Brightness.light,
            primaryColor: primaryGreen,
            scaffoldBackgroundColor: isDark? const Color(0xFF121212) : Colors.grey.shade50,
            cardColor: isDark? const Color(0xFF1E1E1E) : Colors.white,
          ),
          child: Scaffold(
            appBar: AppBar(
              title: GestureDetector( // also allow 5 tap on appbar title
                onTap: _handleHeaderTap,
                child: Text('ExamHook', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))
              ), 
              backgroundColor: primaryGreen, 
              elevation: 0, 
              actions: [IconButton(icon: const Icon(Icons.mail_outline), onPressed: _showRequestDialog)]
            ),
            drawer: Drawer(
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _handleHeaderTap,
                          child: const Icon(Icons.school, size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text('ExamHook', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Subjects', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      ],
                    )
                  ),
                  // NEW: THEME SWITCHER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode)),
                            ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                          ],
                          selected: {_themeMode},
                          onSelectionChanged: (newSelection) {
                            _saveTheme(newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: liveSubjects.length,
                      itemBuilder: (context, index) {
                        String subject = liveSubjects[index];
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
                  ListTile(leading: Icon(Icons.description, color: primaryGreen), title: Text('Terms & Conditions', style: GoogleFonts.poppins()), onTap: _showTermsDialog),
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
                      hintText: 'Search resources...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark? Colors.grey.shade800 : Colors.grey.shade100
                    ),
                    onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                  )
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    value: selectedCourse,
                    decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: liveSubjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => selectedCourse = val!),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { // NEW: ATTRACTIVE EMPTY STATE
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 100, color: primaryGreen.withOpacity(0.5)),
                                const SizedBox(height: 20),
                                Text('No resources yet', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Ask the admin to upload notes, past papers and quizzes', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _showRequestDialog,
                                  icon: const Icon(Icons.mail),
                                  label: const Text('Request Notes'),
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                )
                              ],
                            ),
                          ),
                        );
                      }

                      var docs = snapshot.data!.docs;
                      if (selectedCourse!= 'All') docs = docs.where((d) => d['course'] == selectedCourse).toList();
                      if (searchQuery.isNotEmpty) docs = docs.where((d) => d['title'].toString().toLowerCase().contains(searchQuery) || d['course'].toString().toLowerCase().contains(searchQuery)).toList();
                      
                      return ListView.builder(itemCount: docs.length, itemBuilder: (context, index) {
                        var doc = docs[index]; var data = doc.data() as Map<String, dynamic>; String docId = doc.id;
                        bool isLiked = likedDocs.contains(docId); bool isRated = ratedDocs.contains(docId);
                        Color cardColor = _getCardColor(data['course']?? ''); // NEW: colorful

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                          elevation: 4, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Container( // NEW: Gradient
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [cardColor.withOpacity(0.1), cardColor.withOpacity(0.02)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: cardColor.withOpacity(0.3))
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14), 
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cardColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.picture_as_pdf, color: cardColor, size: 28)), 
                                  const SizedBox(width: 12), 
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(data['title']?? 'No Title', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)), 
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
                                      child: Text('${data['course']} • ${data['examType']}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white))
                                    )
                                  ])), 
                                  IconButton(icon: const Icon(Icons.download_for_offline, color: secondaryBlue, size: 30), onPressed: () => _openLink(docId, data['fileUrl']))
                                ]),
                                const SizedBox(height: 10), 
                                Row(children: [Icon(Icons.calendar_today, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(_formatDate(data['uploadedAt']), style: GoogleFonts.poppins(fontSize: 11)), const SizedBox(width: 12), Icon(Icons.data_object, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(_formatBytes(data['fileSize']?? 0), style: GoogleFonts.poppins(fontSize: 11))]),
                                const SizedBox(height: 10), 
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [IconButton(icon: Icon(Icons.favorite, color: isLiked? Colors.red : Colors.grey, size: 20), onPressed: () => _likeResource(docId)), Text('${data['likes']?? 0}', style: GoogleFonts.poppins(fontSize: 12))]), 
                                  Row(children: [Icon(Icons.star, color: Colors.amber, size: 20), Text(' ${data['rating']?.toStringAsFixed(1)?? '0.0'}', style: GoogleFonts.poppins(fontSize: 12)), PopupMenuButton<double>(enabled:!isRated, onSelected: (val) => _rateResource(docId, val), itemBuilder: (context) => [1,2,3,4,5].map((e) => PopupMenuItem(value: e.toDouble(), child: Text('$e Star'))).toList(), child: Icon(Icons.rate_review, size: 20, color: isRated? Colors.grey : Colors.black))]), 
                                  Row(children: [Icon(Icons.download, color: Colors.blue, size: 20), Text(' ${data['downloads']?? 0}', style: GoogleFonts.poppins(fontSize: 12))])
                                ])
                              ])
                            ),
                          )
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}