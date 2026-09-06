import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _newSubjectController = TextEditingController();
  final _secretCodeController = TextEditingController();

  String _course = 'Maths';
  String _examType = 'Notes';
  bool _isUploading = false;

  final supabase = Supabase.instance.client;
  final firestore = FirebaseFirestore.instance;
  final uuid = const Uuid();

  List<String> subjects = ['Maths', 'Physics', 'Chemistry', 'Biology'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSubjects();
    _loadSecretCode();
  }

  Future<void> _loadSubjects() async {
    DocumentSnapshot doc = await firestore.collection('settings').doc('app').get();
    if (doc.exists && doc['subjects']!= null) {
      setState(() => subjects = List<String>.from(doc['subjects']));
    }
  }

  Future<void> _loadSecretCode() async {
    DocumentSnapshot doc = await firestore.collection('settings').doc('app').get();
    if (doc.exists && doc['secretCode']!= null) {
      _secretCodeController.text = doc['secretCode'];
    } else {
      _secretCodeController.text = '63-1678367V27PURE';
    }
  }

  Future<void> _uploadFile() async {
    if (!_formKey.currentState!.validate()) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'], withData: true);
    if (result == null) return;
    Uint8List? fileBytes = result.files.first.bytes;
    String fileName = '${uuid.v4()}_${result.files.first.name}';
    setState(() => _isUploading = true);
    try {
      await supabase.storage.from('examhook-files').uploadBinary(fileName, fileBytes!);
      String fileUrl = supabase.storage.from('examhook-files').getPublicUrl(fileName);
      await firestore.collection('resources').add({
        'title': _titleController.text,
        'course': _course,
        'examType': _examType,
        'fileUrl': fileUrl,
        'fileName': fileName, // save full name for delete
        'fileSize': result.files.first.size,
        'likes': 0, 
        'rating': 0.0, 
        'ratingCount': 0, // <-- IMPORTANT FOR RATING MATH
        'downloads': 0,
        'uploadedAt': FieldValue.serverTimestamp()
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource Uploaded!'), backgroundColor: Colors.green));
      _titleController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  Future<void> _deleteResource(String docId, String fileName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource'),
        content: const Text('Are you sure? This will delete from storage and database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await supabase.storage.from('examhook-files').remove([fileName]);
      await firestore.collection('resources').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _addSubject() async {
    if (_newSubjectController.text.isEmpty) return;
    if (!subjects.contains(_newSubjectController.text)) {
      subjects.add(_newSubjectController.text);
      await firestore.collection('settings').doc('app').set({'subjects': subjects}, SetOptions(merge: true));
      _newSubjectController.clear();
      setState(() {});
    }
  }

  Future<void> _saveSecretCode() async {
    await firestore.collection('settings').doc('app').set({'secretCode': _secretCodeController.text}, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secret Code Updated'), backgroundColor: Colors.green));
  }

  Future<void> _markRequestDone(String docId) async {
    await firestore.collection('requests').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF00C896);
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: primaryGreen,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Upload'),
            Tab(icon: Icon(Icons.list), text: 'Manage'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: UPLOAD
          Padding(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: ListView(children: [
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Resource Title', border: OutlineInputBorder()), validator: (val) => val!.isEmpty? 'Enter title' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _course, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()), items: subjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _course = val!)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _examType, decoration: const InputDecoration(labelText: 'Exam Type', border: OutlineInputBorder()), items: ['ExamPrac', 'Notes', 'Quiz', 'Assignment'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _examType = val!)),
            const SizedBox(height: 24),
            _isUploading? const Center(child: CircularProgressIndicator()) : ElevatedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Pick & Upload File'), style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50)), onPressed: _uploadFile),
          ]))),

          // TAB 2: MANAGE RESOURCES
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text('No resources yet', style: GoogleFonts.poppins()));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF00C896)),
                      title: Text(data['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${data['course']} • ${data['examType']}\n'
                        'Likes: ${data['likes']} • Rating: ${data['rating']?.toStringAsFixed(1)} • Downloads: ${data['downloads']}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResource(doc.id, data['fileName'])),
                    ),
                  );
                },
              );
            },
          ),

          // TAB 3: SETTINGS
          Padding(padding: const EdgeInsets.all(16), child: ListView(children: [
            Text('Manage Subjects', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(child: TextField(controller: _newSubjectController, decoration: const InputDecoration(labelText: 'New Subject'))),
              IconButton(icon: Icon(Icons.add_circle, color: primaryGreen, size: 32), onPressed: _addSubject),
            ]),
            const Divider(height: 40),
            Text('Change Admin Secret Code', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: _secretCodeController, decoration: const InputDecoration(labelText: 'Secret Code')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _saveSecretCode, child: const Text('Save Code'), style: ElevatedButton.styleFrom(backgroundColor: primaryGreen)),
            const Divider(height: 40),
            Text('User Requests', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('requests').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Text('Loading...');
                if (snap.data!.docs.isEmpty) return const Text('No requests yet');
                return Column(children: snap.data!.docs.map((d) {
                  var data = d.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.mail, color: Colors.orange),
                      title: Text(data['subject'] ?? 'No Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('dd MMM, hh:mm a').format((data['timestamp'] as Timestamp).toDate())),
                      trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _markRequestDone(d.id)),
                    ),
                  );
                }).toList());
              }
            )
          ])),
        ],
      ),
    );
  }
}