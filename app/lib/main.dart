import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/dashboard_provider.dart';
import 'services/api_service.dart';

// RouteObserver để detect navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ AWAIT Firebase nhưng với timeout ngắn để không block lâu
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      Duration(seconds: 2),  // Chỉ đợi 2s
    );
    firebaseReady = Firebase.apps.isNotEmpty;
    if (firebaseReady) {
      debugPrint('✅ Firebase initialized successfully');
    }
  } on TimeoutException {
    debugPrint('⚠️ Firebase timeout after 2s, launching anyway...');
    firebaseReady = Firebase.apps.isNotEmpty;
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    firebaseReady = false;
  }
  
  try {
    ApiService.setupInterceptors();
    debugPrint('✅ API interceptors setup');
  } catch (e) {
    debugPrint('❌ API setup failed: $e');
  }
  
  // ✅ LAUNCH APP
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Refmind',
      navigatorObservers: [routeObserver],
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Color(0xFF2D60FF),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white, 
          foregroundColor: Colors.black
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF121212), 
        primaryColor: Color(0xFF2D60FF),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E), 
          foregroundColor: Colors.white
        ),
        cardColor: Color(0xFF1E1E1E), 
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF2D60FF),
          unselectedItemColor: Colors.grey,
        ),
      ),
      // Apply text scale factor via builder (only override textScaler, preserve all other MediaQuery data)
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.textScaleFactor),
          ),
          child: child!,
        );
      },
      home: SplashScreen(), 
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _firebaseReady = false;
  bool _checkComplete = false;
  
  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }
  
  Future<void> _checkFirebase() async {
    // Đợi Firebase init (tối đa 3s)
    int attempts = 0;
    while (Firebase.apps.isEmpty && attempts < 6) {
      await Future.delayed(Duration(milliseconds: 500));
      attempts++;
    }
    
    if (mounted) {
      setState(() {
        _firebaseReady = Firebase.apps.isNotEmpty;
        _checkComplete = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Đang check Firebase
    if (!_checkComplete) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // Firebase KHÔNG ready → Skip auth, đi thẳng HomeScreen (demo mode)
    if (!_firebaseReady) {
      debugPrint('⚠️ Firebase not ready, entering demo mode');
      return HomeScreen();
    }
    
    // Firebase ready → normal auth flow
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return HomeScreen(); 
        }
        return AuthScreen(); 
      },
    );
  }
}