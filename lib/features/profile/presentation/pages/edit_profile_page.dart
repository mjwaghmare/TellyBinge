import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: 'Mj');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Colors.blue, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 0.5
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 1, thickness: 0.5),
            
            // Profile Photo Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.transparent,
                      backgroundImage: CachedNetworkImageProvider(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'Choose profile photo',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1, thickness: 0.5),
            
            // Display Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display name',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  TextField(
                    controller: _displayNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: Colors.blue,
                    decoration: const InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1, thickness: 0.5),
            
            // Personal Information Section
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, 24.0, AppSpacing.md, 16.0),
              child: Text(
                'Personal information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Static Information Fields
            _buildStaticField('Birth year', '1993'),
            _buildStaticField('Gender', 'Male'),
            
            const Divider(color: Colors.white24, height: 1, thickness: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
