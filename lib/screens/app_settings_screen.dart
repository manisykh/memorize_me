// lib/screens/app_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glassmorphic_card.dart';
import 'tts_settings_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('앱 설정'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계정', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _buildAuthSection(context),
              const SizedBox(height: 24),
              Text('디자인', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _buildThemeSettingsSection(context),
              const SizedBox(height: 24),
              Text('소리', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  leading: const Icon(CupertinoIcons.speaker_2_fill),
                  title: const Text('TTS 목소리 설정'),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const TtsSettingsScreen()));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods from old SettingsScreen
  Widget _buildAuthSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (authProvider.isLoading) return const Center(child: CircularProgressIndicator());

    return GlassmorphicCard(
      child: user != null ? _buildLoggedInUser(context, user) : _buildLoginButton(context),
    );
  }

  Widget _buildLoggedInUser(BuildContext context, GoogleSignInAccount user) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GoogleUserCircleAvatar(identity: user),
      title: Text(
        user.displayName ?? 'No Name',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(user.email, style: theme.textTheme.bodyMedium),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => context.read<AuthProvider>().signOut(),
        color: theme.iconTheme.color,
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.read<AuthProvider>().signIn(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/google_logo.png', height: 24, width: 24),
            const SizedBox(width: 12),
            Text('Google 계정으로 로그인', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();
    final String currentThemeName;
    final IconData currentIcon;

    if (themeNotifier.currentTheme == AppThemeType.eyeCare) {
      currentThemeName = "시력 보호 테마";
      currentIcon = CupertinoIcons.eyeglasses;
    } else {
      currentThemeName = "기본 테마";
      currentIcon = CupertinoIcons.sun_max_fill;
    }

    return GlassmorphicCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            leading: Icon(currentIcon, color: theme.primaryColor),
            title: Text(currentThemeName, style: theme.textTheme.bodyLarge),
            onTap: () {
              final newTheme =
                  themeNotifier.currentTheme == AppThemeType.basic
                      ? AppThemeType.eyeCare
                      : AppThemeType.basic;
              themeNotifier.setTheme(newTheme);
            },
          ),
          if (themeNotifier.currentTheme == AppThemeType.eyeCare)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
              child: Row(
                children: [
                  Text("배경 농도", style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: themeNotifier.eyeCareLevel.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: "Level ${themeNotifier.eyeCareLevel}",
                      onChanged: (value) {
                        themeNotifier.setEyeCareLevel(value.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
