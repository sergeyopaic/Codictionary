import 'package:flutter/material.dart';

class VocabsView extends StatelessWidget {
  const VocabsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vocabularies'), centerTitle: true),
      drawerScrimColor: Colors.black54,
      drawer: Builder(
        builder: (context) {
          final width = MediaQuery.of(context).size.width * 0.25;
          return Drawer(
            width: width.clamp(240.0, 420.0),
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.library_books),
                    title: Text('My Vocabularies'),
                    // We are already here
                    enabled: false,
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Dictionary'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
                    enabled: false,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: const Center(child: Text('No vocabularies yet. Add one!')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        icon: const Icon(Icons.add),
        label: const Text('New Vocabulary'),
      ),
    );
  }
}
