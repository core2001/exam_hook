import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedCourse = 'All';
  String selectedExam = 'All';

  void _openLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ExamHook', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00C896),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedCourse,
                    isExpanded: true,
                    hint: const Text('Course'),
                    items: ['All', 'Math', 'Science', 'Programming', 'Accounting'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => selectedCourse = val!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedExam,
                    isExpanded: true,
                    hint: const Text('Exam Type'),
                    items: ['All', 'Midterm', 'Final', 'Quiz'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => selectedExam = val!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (selectedCourse!= 'All') docs = docs.where((d) => d['course'] == selectedCourse).toList();
                if (selectedExam!= 'All') docs = docs.where((d) => d['examType'] == selectedExam).toList();

                if (docs.isEmpty) return Center(child: Text('No resources yet', style: GoogleFonts.poppins()));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf, color: const Color(0xFF00C896)),
                        title: Text(data['title']?? 'No Title', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Text('${data['course']} • ${data['examType']}', style: GoogleFonts.poppins(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
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
