import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/app_routes.dart';
import 'package:frontend/presentation/widgets/custom_button.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/user_provider.dart';
import 'dart:typed_data'; // For Uint8List

class ArtistProfile extends ConsumerWidget {
  const ArtistProfile({super.key});

  /// Picks an image from the gallery and updates the user's profile image.
  Future<void> _pickAndUpdateProfileImage(WidgetRef ref, BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null && context.mounted) {
        final userState = ref.read(userProvider);
        final user = userState.user;

        if (user != null) {
          final imageBytes = await pickedFile.readAsBytes();
          final fileName = pickedFile.name;

          final token = userState.token ?? await ref.read(userProvider.notifier).getCurrentToken();
          if (token != null) {
            await ref.read(userProvider.notifier).updateProfileImage(
              token,
              user.id,
              imageBytes,
              fileName,
            );
            // Refresh profile data and clear image cache
            await _refreshProfileData(ref, context);
            imageCache.clear();
            imageCache.clearLiveImages();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile image updated successfully')),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No authentication token available')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile image: $e')),
        );
      }
    }
  }

  /// Refreshes the profile data by calling fetchProfile.
  Future<void> _refreshProfileData(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(userProvider.notifier).fetchProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile data refreshed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final userNotifier = ref.read(userProvider.notifier);
    final user = userState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Black background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop(); // Navigate back to the previous screen
            } else {
              context.go(AppRoutes.login); // Fallback to login if no previous route
            }
          },
        ),
        title: Text(
          'Artist Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.black,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        elevation: Theme.of(context).appBarTheme.elevation ?? 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshProfileData(ref, context),
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          : userState.error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${userState.error}',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Try Again',
              icon: Icons.refresh,
              color: const Color(0xFF1DB954),
              onPressed: () => _refreshProfileData(ref, context),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture with Checkmark and Update Button
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFF212121),
                  foregroundImage: user?.profileImage != null
                      ? NetworkImage(user!.profileImage!)
                      : null,
                  child: user?.profileImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _pickAndUpdateProfileImage(ref, context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              user?.fullName ?? 'Artist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      '${user?.followersCount ?? 0}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Followers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 80),
                Column(
                  children: [
                    Text(
                      '${user?.followingCount ?? 0}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Following',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Buttons
            CustomButton(
              text: 'Artist Dashboard',
              icon: Icons.person,
              color: const Color(0xFF1DB954),
              isFullWidth: true,
              onPressed: () {
                context.push(AppRoutes.artistDashboard);
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Edit Profile',
              icon: Icons.person,
              trailingIcon: Icons.arrow_forward,
              color: const Color(0xFF212121),
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Get Verified',
              icon: Icons.verified,
              trailingIcon: Icons.arrow_forward,
              color: const Color(0xFF212121),
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Get Verified feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Settings',
              icon: Icons.settings,
              trailingIcon: Icons.arrow_forward,
              color: const Color(0xFF212121),
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Help & Support',
              icon: Icons.help,
              trailingIcon: Icons.arrow_forward,
              color: const Color(0xFF212121),
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & Support feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'About',
              icon: Icons.info,
              trailingIcon: Icons.arrow_forward,
              color: const Color(0xFF212121),
              isFullWidth: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('About feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 24),
            // Logout Button (Functional)
            CustomButton(
              text: 'Logout',
              icon: Icons.logout,
              color: const Color(0xFFFF0000),
              isFullWidth: true,
              onPressed: () async {
                try {
                  userNotifier.logout();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}