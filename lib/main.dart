import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'screens/supplier/supplier_list_screen.dart';
import 'screens/supplier/add_supplier_screen.dart';
import 'screens/fuel_delivery/add_fuel_delivery_screen.dart';
import 'screens/fuel_delivery/fuel_delivery_history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';

void main() async {
  // Wrap the app initialization in a try-catch block to catch any startup errors
  try {
    developer.log('App starting up...');
    
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();
    developer.log('Flutter binding initialized');
    
    // Initialize shared preferences
    final prefs = await SharedPreferences.getInstance();
    developer.log('SharedPreferences initialized');
    
    // Debug: List any existing preferences
    final prefsKeys = prefs.getKeys();
    if (prefsKeys.isNotEmpty) {
      developer.log('Found existing preferences: $prefsKeys');
    } else {
      developer.log('No existing preferences found');
    }
    
    // Run the app
    developer.log('Running app...');
    runApp(const MyApp());
  } catch (e, stackTrace) {
    // Log any startup errors
    developer.log('Error during app initialization: $e');
    if (kDebugMode) {
      developer.log('Stack trace: $stackTrace');
      print('Error during app initialization: $e');
      print('Stack trace: $stackTrace');
    }
    
    // Still try to run the app with error reporting
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    developer.log('Building MyApp widget');
    return MaterialApp(
      title: 'Petrol Pump Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use the consistent app theme from AppTheme
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryBlue),
        useMaterial3: true,
        // Apply the appBarTheme to ensure consistent styling across all screens
        appBarTheme: AppTheme.appBarTheme,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/suppliers': (context) => const SupplierListScreen(),
        '/add_supplier': (context) => const AddSupplierScreen(),
        '/fuel_delivery': (context) => const FuelDeliveryHistoryScreen(),
        '/add_fuel_delivery': (context) => const AddFuelDeliveryScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
