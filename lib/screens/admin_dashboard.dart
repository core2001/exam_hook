import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _course = 'Math';
  String _examType = 'Final';
  bool _isUploading = false;
  
  final supabase = Supabase.instance.client;
  final firestore = FirebaseFirestore.instance;
  final uuid = const Uuid();

  Future<void> _uploadFile() async {
    if (!_formKey.currentState!.validate()) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
    if (result == null) return;
    Uint8List? fileBytes = result.files.first.bytes;
    String fileName = '${uuid.v4()}_${result.files.first.name}';
    setState(() => _isUploading = true);
    try {
      await supabase.storage.from('resources').uploadBinary(fileName, fileBytes!);
      String fileUrl = supabase.storage.from('resources').getPublicUrl(fileName);
      await firestore.collection('resources').add({'title': _titleController.text, 'course': _course, 'examType': _examType, 'fileUrl': fileUrl, 'fileName': result.files.first.name, 'uploadedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded!'), backgroundColor: Colors.green));
      _titleController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Dashboard', style: GoogleFonts.poppins())),
      body: Padding(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(children: [
        TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Resource Title', border: OutlineInputBorder()), validator: (val) => val!.isEmpty? 'Enter title' : null),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(value: _course, decoration: const InputDecoration(labelText: 'Course', border: OutlineInputBorder()), items: ['Math', 'Science', 'Programming', 'Accounting'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _course = val!)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(value: _examType, decoration: const InputDecoration(labelText: 'Exam Type', border: OutlineInputBorder()), items: ['Midterm', 'Final', 'Quiz', 'Assignment'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _examType = val!)),
        const SizedBox(height: 24),
        _isUploading ? const CircularProgressIndicator() : ElevatedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Pick & Upload File'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896), minimumSize: const Size(double.infinity, 50)), onPressed: _uploadFile),
      ]))),
    );
  }
}
