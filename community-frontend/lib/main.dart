import 'package:community_frontend/config/app_theme.dart';
import 'package:community_frontend/screens/add_member_screen.dart';
import 'package:community_frontend/screens/change_password_screen.dart';
import 'package:community_frontend/screens/chat_support_screen.dart';
import 'package:community_frontend/screens/community_entry_screen.dart';
import 'package:community_frontend/screens/create_community_screen.dart';
import 'package:community_frontend/screens/create_post_screen.dart';
import 'package:community_frontend/screens/edit_person_screen.dart';
import 'package:community_frontend/screens/edit_profile_screen.dart';
import 'package:community_frontend/screens/faq_screen.dart';
import 'package:community_frontend/screens/feedback_screen.dart';
import 'package:community_frontend/screens/help_feedback_screen.dart';
import 'package:community_frontend/screens/join_community_screen.dart';
import 'package:community_frontend/screens/login_screen.dart';
import 'package:community_frontend/screens/main_nav_screen.dart';
import 'package:community_frontend/screens/manage_family_screen.dart';
import 'package:community_frontend/screens/member_screen.dart';
import 'package:community_frontend/screens/otp_screen.dart';
import 'package:community_frontend/screens/person_detail_screen.dart';
import 'package:community_frontend/screens/privacy_security_screen.dart';
import 'package:community_frontend/screens/register_family_screen.dart';
import 'package:community_frontend/screens/register_screen.dart';
import 'package:community_frontend/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'screens/entry_screen.dart';

void main() {
  runApp(CommunityApp());
}

class CommunityApp extends StatelessWidget {
  const CommunityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: AppTheme.darkTheme,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/otp': (context) =>
            const OtpScreen(name: "", email: "", phone: "", password: ""),
        '/': (context) => const EntryScreen(),
        '/community-entry': (context) => const CommunityEntryScreen(),
        '/create-community': (context) => const CreateCommunityScreen(),
        '/join-community': (context) => const JoinCommunityScreen(),
        '/main-nav': (context) => const MainNavigationScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/manage-family': (context) => const ManageFamilyScreen(),
        '/register-family': (context) => const RegisterFamilyScreen(),
        "/add-member": (context) => const AddMemberScreen(),
        '/privacy': (context) => const PrivacySettingsScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/help-feedback': (context) => const HelpFeedbackScreen(),
        '/faq': (context) => const FAQScreen(),
        '/feedback': (context) => const FeedbackScreen(),
        '/chat': (context) => const ChatSupportScreen(),
        '/create-post': (context) => const CreatePostScreen(),
        '/members': (context) => const MemberScreen(),
        '/user-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return UserProfileScreen(userId: args['userId']);
        },
      },
      // Add onGenerateRoute to handle dynamic args like person
      onGenerateRoute: (settings) {
        if (settings.name == '/person-detail') {
          final person = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PersonDetailScreen(person: person),
          );
        }

        if (settings.name == '/edit-person') {
          final person = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => EditPersonScreen(person: person),
          );
        }

        return null; // fallback
      },
    );
  }
}
