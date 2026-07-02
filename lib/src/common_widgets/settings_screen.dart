import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/indexing/presentation/indexing_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: SafeArea(
        child: ListView(
          addAutomaticKeepAlives: true,
          children: [
            // indexing status
            const IndexingCard(),
          ],
        ),
      ),
    );
  }
}
