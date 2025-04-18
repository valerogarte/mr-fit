import 'package:flutter/material.dart';
import 'screens/planes/planes.dart';
import 'screens/home.dart';
import 'screens/estado_fisico/estado_fisico_page.dart';
import 'utils/colors.dart';
import 'screens/usuario/usuario_config.dart'; // importación agregada
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/usuario_provider.dart';
import 'models/usuario/usuario.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final usuario = await Usuario.load();
  runApp(
    ProviderScope(
      overrides: [
        usuarioProvider.overrideWithValue(usuario),
      ],
      child: const MyApp(),
    ),
  );
}

// Clase principal de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mr Fit',
      theme: ThemeData(
        primaryColor: AppColors.secondaryColor,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'MadeTommy', // Añadido para usar la fuente personalizada
        appBarTheme: AppBarTheme(
          color: AppColors.appBarBackground,
          iconTheme: IconThemeData(color: AppColors.whiteText),
          titleTextStyle: TextStyle(
            color: AppColors.whiteText,
            fontFamily: 'MadeTommy', // Aplica la fuente al título del AppBar
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.textColor),
          bodyMedium: TextStyle(color: AppColors.textColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBackground,
          labelStyle: TextStyle(color: AppColors.whiteText),
          hintStyle: TextStyle(color: AppColors.textColor),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.secondaryColor),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.accentColor),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentColor, // Cambiado de 'primary'
            foregroundColor: AppColors.whiteText, // Cambiado de 'onPrimary'
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.secondaryColor,
          selectedItemColor: AppColors.accentColor,
          unselectedItemColor: AppColors.textColor,
        ),
      ),
      home: const MyHomePage(), // Cambiado de InicioPage a MyHomePage
    );
  }
}

// Página principal después del inicio de sesión
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: Theme.of(context).appBarTheme.titleTextStyle,
            children: [
              TextSpan(text: 'Mr', style: const TextStyle(color: AppColors.advertencia)),
              TextSpan(text: 'Fit', style: const TextStyle(color: AppColors.whiteText)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UsuarioConfigPage()),
              );
            },
          ),
        ],
      ),
      body: const InicioPage(), // Directly load InicioPage
    );
  }
}
