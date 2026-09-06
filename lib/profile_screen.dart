import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'about_screen.dart';
import 'tab_navigator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Get current Firebase user
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String _username = '';
  String _email = '';
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
  String _serverUrl = 'http://192.168.228.12:5000'; // Default server URL

  // Image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadServerUrl();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    if (_currentUser != null) {
      // Refresh the user to get the latest data
      await _currentUser!.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      setState(() {
        _username = updatedUser?.displayName ?? 'No Name Set';
        _email = updatedUser?.email ?? 'No Email';
        _profileImageUrl = updatedUser?.photoURL;
        _isLoading = false;
      });
    } else {
      setState(() {
        _username = 'Not signed in';
        _email = 'Please login again';
        _profileImageUrl = null;
        _isLoading = false;
      });
    }
  }

  // Method to pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Upload the image to Firebase Storage
        await _uploadAndUpdateProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  // Method to show image picker options
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Method to upload profile image to Firebase Storage and update user profile
  Future<void> _uploadAndUpdateProfileImage(File imageFile) async {
    if (_currentUser == null) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      // Create a reference to the user's profile image in Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${_currentUser!.uid}.jpg');

      // Upload the file
      await storageRef.putFile(imageFile);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile with photo URL
      await _currentUser!.updatePhotoURL(downloadUrl);

      // Refresh user data
      await _loadUserData();

      setState(() {
        _isUpdatingImage = false;
      });

      _showSuccessSnackBar('Profile picture updated successfully!');
    } catch (e) {
      setState(() {
        _isUpdatingImage = false;
      });
      _showErrorSnackBar('Error updating profile picture: $e');
    }
  }

  // Method to remove profile image
  Future<void> _removeProfileImage() async {
    if (_currentUser == null || _profileImageUrl == null) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      // Try to delete the image from storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profiles')
            .child('${_currentUser!.uid}.jpg');
        await storageRef.delete();
      } catch (e) {
        // Ignore errors if image doesn't exist in storage
        print('Error deleting image from storage: $e');
      }

      // Update user profile to remove photo URL
      await _currentUser!.updatePhotoURL(null);

      // Refresh user data
      await _loadUserData();

      setState(() {
        _isUpdatingImage = false;
      });

      _showSuccessSnackBar('Profile picture removed!');
    } catch (e) {
      setState(() {
        _isUpdatingImage = false;
      });
      _showErrorSnackBar('Error removing profile picture: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Load server URL from SharedPreferences
  Future<void> _loadServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString('server_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        setState(() {
          _serverUrl = storedUrl;
        });
      }
    } catch (e) {
      print('Error loading server URL: $e');
    }
  }

  // Save server URL to SharedPreferences
  Future<void> _saveServerUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', url);
    } catch (e) {
      print('Error saving server URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Profile Avatar
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _showImagePickerOptions,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: _isUpdatingImage
                                      ? Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : _profileImageUrl != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(60),
                                              child: Image.network(
                                                _profileImageUrl!,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      color: AppColors.primary,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.grey,
                                            ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showImagePickerOptions,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Username
                          Text(
                            _username,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Email
                          Text(
                            _email,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Settings Options
                  const SizedBox(height: 20),
                  _buildSettingsCard(context),
                  const SizedBox(height: 20),
                  _buildSignOutButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.person_outline,
              title: 'Change Username',
              onTap: () {
                _showChangeUsernameDialog(context);
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                _showChangePasswordDialog(context);
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.dns_outlined,
              title: 'Server Settings',
              onTap: () {
                _showServerSettingsDialog(context);
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            _showSignOutDialog(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade800,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Sign Out',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeUsernameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    controller.text = _username;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update Firebase username
                if (_currentUser != null && controller.text.trim().isNotEmpty) {
                  await _currentUser!.updateDisplayName(controller.text.trim());

                  // Reload user data
                  await _loadUserData();

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Username updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating username: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                if (_currentUser != null && _currentUser!.email != null) {
                  // Reauthenticate user first (required for sensitive operations)
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: _currentUser!.email!,
                    password: currentPasswordController.text,
                  );

                  await _currentUser!.reauthenticateWithCredential(credential);

                  // Update password
                  await _currentUser!
                      .updatePassword(newPasswordController.text);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating password: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final TextEditingController serverUrlController =
        TextEditingController(text: _serverUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://your-server-ip:5000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For the emotion detection to work, you need to set up the Python server separately and enter its URL here.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = serverUrlController.text.trim();
              if (newUrl.isNotEmpty) {
                await _saveServerUrl(newUrl);
                setState(() {
                  _serverUrl = newUrl;
                });

                // Show confirmation
                if (context.mounted) {
                  // Close dialog first
                  Navigator.of(context).pop();

                  // Force reload by replacing the current navigator
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const TabNavigator(
                          initialIndex: 2), // Keep on profile tab
                    ),
                  );

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Server URL updated successfully!')),
                  );
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Sign out with Firebase
                await FirebaseAuth.instance.signOut();

                // Navigate to login screen
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error signing out: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade800,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
