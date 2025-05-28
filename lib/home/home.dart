import 'package:flutter/material.dart';

import 'home_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();

  @override
  void initState() {
    super.initState();
    manager.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genesis 1')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(child: Text('Drawer Header')),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: ValueListenableBuilder(
            valueListenable: manager.textNotifier,
            builder: (context, text, child) {
              return Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'sbl'),
                textDirection: TextDirection.rtl,
              );
            },
          ),
        ),
      ),
    );
  }
}
