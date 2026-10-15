import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

class LoginScreenExample {
  void handleLogin() async {

    final apiResponse = {
      'success': true,
      'data': {
        'id': '123',
        'name': 'Mamadou Diallo',
        'email': 'mamadou@example.com',
        'phone': '771234567',
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        'avatar': 'https://api.example.com/avatars/123.jpg',
        'role': 'citizen',
      }
    };

    if (apiResponse['success'] != null) {
      final userData = apiResponse['data'] as Map<String, dynamic>;

      await AuthService.instance.saveLoginData(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        phone: userData['phone'],
        token: userData['token'],
        avatar: userData['avatar'],
        role: userData['role'],
      );

      // Afficher un message de succès
      Get.snackbar(
        'Connexion réussie',
        'Bienvenue ${userData['name']} !',
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offAllNamed(Routes.HOME);
    }
  }
}

class RegisterScreenExample {
  void handleRegister() async {

    final apiResponse = {
      'success': true,
      'data': {
        'id': '456',
        'name': 'Fatou Sow',
        'email': 'fatou@example.com',
        'phone': '779876543',
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        'avatar': null,
        'role': 'citizen',
      }
    };

    if (apiResponse['success'] != null) {
      final userData = apiResponse['data'] as Map<String, dynamic>;

      await AuthService.instance.saveLoginData(
        id: userData['id'],
        name: userData['name'],
        email: userData['email'],
        phone: userData['phone'],
        token: userData['token'],
        avatar: userData['avatar'],
        role: userData['role'],
      );

      Get.snackbar(
        'Inscription réussie',
        'Bienvenue ${userData['name']} !',
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offAllNamed(Routes.HOME);
    }
  }
}

class LogoutExample {
  void handleLogout() async {
    Get.dialog(
      AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();

              await AuthService.instance.logout();

            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class UserDataExample extends StatelessWidget {
  const UserDataExample({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: Obx(() => Column(
        children: [
          // Afficher l'avatar
          if (authService.userAvatar.value != null)
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(authService.userAvatar.value!),
            )
          else
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),

          const SizedBox(height: 16),

          // Afficher le nom
          Text(
            authService.userName.value ?? 'Utilisateur',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // Afficher l'email
          Text(authService.userEmail.value ?? ''),

          const SizedBox(height: 8),

          // Afficher le téléphone
          Text(authService.userPhone.value ?? ''),

          const SizedBox(height: 24),

          // Bouton de déconnexion
          ElevatedButton(
            onPressed: () async {
              await AuthService.instance.logout();
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      )),
    );
  }
}

class AuthCheckExample {
  void checkAuthStatus() {
    final authService = AuthService.instance;

    if (authService.isUserLoggedIn) {
      print('Utilisateur connecté');
      print('Token: ${authService.authToken}');
      print('Nom: ${authService.userName.value}');
    } else {
      print('Utilisateur non connecté');
      // Rediriger vers login si nécessaire
      Get.offAllNamed(Routes.SPLASH);
    }
  }
}

class UpdateProfileExample {
  void updateUserProfile() async {

    await AuthService.instance.updateProfile(
      name: 'Nouveau Nom',
      email: 'nouveau@email.com',
      phone: '771111111',
      avatar: 'https://api.example.com/avatars/new.jpg',
    );

    Get.snackbar(
      'Succès',
      'Profil mis à jour',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

// ============================================
// EXEMPLE 7: Dans main.dart - Initialisation
// ============================================
/*
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Get.putAsync(() async => AuthService());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Citoyen Alerte',
      initialRoute: Routes.SPLASH, // Toujours commencer par le splash
      getPages: AppPages.routes,
    );
  }
}
*/