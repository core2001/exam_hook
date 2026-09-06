import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
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
  
  String selectedCourse = 'All';
  String searchQuery = '';
  List<String> subjects = ['All', 'Maths', 'Physics', 'Chemistry', 'Biology'];

  void _openLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
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
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryGreen, secondaryBlue])),
              child: Center(child: Text('Subjects', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  String subject = subjects[index];
                  return ListTile(
                    leading: Icon(Icons.book, color: primaryGreen),
                    title: Text(subject, style: GoogleFonts.poppins()),
                    onTap: () {
                      setState(() => selectedCourse = subject);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR with Secret Code
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search subjects or topics',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (val) {
                setState(() => searchQuery = val.toLowerCase());
                _checkSecretCode(val); // Secret code check
              },
            ),
          ),
          // FILTERS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCourse,
                    decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: subjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => selectedCourse = val!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // RESOURCES LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No resources yet', style: GoogleFonts.poppins()));

                var docs = snapshot.data!.docs;

                // Filter by course
                if (selectedCourse != 'All') docs = docs.where((d) => d['course'] == selectedCourse).toList();
                
                // Filter by search
                if (searchQuery.isNotEmpty) {
                  docs = docs.where((d) => 
                    d['title'].toString().toLowerCase().contains(searchQuery) ||
                    d['course'].toString().toLowerCase().contains(searchQuery)
                  ).toList();
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.picture_as_pdf, color: primaryGreen, size: 28),
                        ),
                        title: Text(data['title'] ?? 'No Title', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${data['course']} • ${data['examType']}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatDate(data['uploadedAt']), style: GoogleFonts.poppins(fontSize: 11)),
                                const SizedBox(width: 12),
                                Icon(Icons.data_object, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(_formatBytes(data['fileSize'] ?? 0), style: GoogleFonts.poppins(fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.favorite, size: 14, color: Colors.red),
                                Text(' ${data['likes'] ?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                                const SizedBox(width: 12),
                                Icon(Icons.star, size: 14, color: Colors.amber),
                                Text(' ${data['rating']?.toStringAsFixed(1) ?? '0.0'}', style: GoogleFonts.poppins(fontSize: 12)),
                                const SizedBox(width: 12),
                                Icon(Icons.download, size: 14, color: Colors.blue),
                                Text(' ${data['downloads'] ?? 0}', style: GoogleFonts.poppins(fontSize: 12)),
                              ],
                            )
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_for_offline, color: secondaryBlue),
                          onPressed: () => _openLink(data['fileUrl']),
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