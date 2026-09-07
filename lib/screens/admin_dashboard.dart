import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart'; // CHANGED
import 'dart:typed_data';
import 'dart:io'; // for File
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
  final _searchController = TextEditingController();

  String _course = 'Maths';
  String _examType = 'Notes';
  bool _isUploading = false;
  String _searchQuery = '';

  final supabase = Supabase.instance.client;
  final firestore = FirebaseFirestore.instance;
  final uuid = const Uuid();
  final ImagePicker _picker = ImagePicker(); // CHANGED

  List<String> subjects = ['Maths', 'Physics', 'Chemistry', 'Biology'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    DocumentReference settingsRef = firestore.collection('settings').doc('app');
    DocumentSnapshot doc = await settingsRef.get();
    
    if (doc.exists) {
      setState(() {
        if (doc['subjects']!= null) subjects = List<String>.from(doc['subjects']);
        if (doc['secretCode']!= null) {
          _secretCodeController.text = doc['secretCode'];
        } else {
          _secretCodeController.text = '63-1678367V27PURE';
        }
      });
    } else {
      await settingsRef.set({
        'subjects': subjects,
        'secretCode': '63-1678367V27PURE',
      });
      _secretCodeController.text = '63-1678367V27PURE';
    }
  }

  Future<void> _uploadFile() async { // CHANGED to use image_picker
    if (!_formKey.currentState!.validate()) return;
    
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery); // pick image
    if (image == null) return;

    Uint8List fileBytes = await image.readAsBytes();
    String fileName = '${uuid.v4()}_${image.name}';
    setState(() => _isUploading = true);
    try {
      await supabase.storage.from('examhook-files').uploadBinary(fileName, fileBytes);
      String fileUrl = supabase.storage.from('examhook-files').getPublicUrl(fileName);
      await firestore.collection('resources').add({
        'title': _titleController.text,
        'course': _course,
        'examType': _examType,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileBytes.length, 
        'likes': 0, 
        'rating': 0.0, 
        'ratingCount': 0,
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
        content: const Text('Delete this file from storage and database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    )?? false;

    if (confirm) {
      await supabase.storage.from('examhook-files').remove([fileName]);
      await firestore.collection('resources').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _addSubject() async {
    if (_newSubjectController.text.isEmpty) return;
    String newSub = _newSubjectController.text.trim();
    if (!subjects.contains(newSub)) {
      setState(() => subjects.add(newSub));
      await firestore.collection('settings').doc('app').set({'subjects': subjects}, SetOptions(merge: true));
      _newSubjectController.clear();
    }
  }

  Future<void> _deleteSubject(String subject) async {
    setState(() => subjects.remove(subject));
    await firestore.collection('settings').doc('app').set({'subjects': subjects}, SetOptions(merge: true));
  }

  Future<void> _saveSecretCode() async {
    await firestore.collection('settings').doc('app').set({'secretCode': _secretCodeController.text}, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secret Code Updated'), backgroundColor: Colors.green));
  }

  Future<void> _deleteRequest(String docId) async {
    await firestore.collection('requests').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Deleted'), backgroundColor: Colors.orange));
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
          Padding(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: ListView(children: [
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Resource Title', border: OutlineInputBorder()), validator: (val) => val!.isEmpty? 'Enter title' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _course, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()), items: subjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _course = val!)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _examType, decoration: const InputDecoration(labelText: 'Exam Type', border: OutlineInputBorder()), items: ['ExamPrac', 'Notes', 'Quiz', 'Assignment'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _examType = val!)),
            const SizedBox(height: 24),
            _isUploading? const Center(child: CircularProgressIndicator()) : ElevatedButton.icon(icon: const Icon(Icons.image), label: const Text('Pick & Upload Image'), style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50)), onPressed: _uploadFile), // CHANGED TEXT
          ]))),

          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search resources by title, subject...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore.collection('resources').orderBy('uploadedAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    if (docs.isEmpty) return Center(child: Text('No resources yet', style: GoogleFonts.poppins()));
                    
                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((d) {
                        var data = d.data() as Map<String, dynamic>;
                        return data['title'].toString().toLowerCase().contains(_searchQuery) ||
                               data['course'].toString().toLowerCase().contains(_searchQuery) ||
                               data['examType'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: const Icon(Icons.image, color: Color(0xFF00C896)), // CHANGED ICON
                            title: Text(data['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            subtitle: Text('${data['course']} • ${data['examType']}\nLikes: ${data['likes']} • Rating: ${data['rating']?.toStringAsFixed(1)} • Downloads: ${data['downloads']}'),
                            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResource(doc.id, data['fileName'])),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          Padding(padding: const EdgeInsets.all(16), child: ListView(children: [
            Text('Manage Subjects', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(child: TextField(controller: _newSubjectController, decoration: const InputDecoration(labelText: 'New Subject'))),
              IconButton(icon: Icon(Icons.add_circle, color: primaryGreen, size: 32), onPressed: _addSubject),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: subjects.map((s) => Chip(label: Text(s), deleteIcon: const Icon(Icons.close, size: 18), onDeleted: () => _deleteSubject(s))).toList()),
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
                      title: Text(data['subject']?? 'No Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${data['message']?? ''}\n${data['timestamp']!= null ? DateFormat('dd MMM, hh:mm a').format((data['timestamp'] as Timestamp).toDate()) : ''}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRequest(d.id)),
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