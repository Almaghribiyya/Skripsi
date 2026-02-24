import 'package:flutter/material.dart';

class SidebarMenu extends StatelessWidget {
  const SidebarMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF172B1E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Logika New Chat
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0FB345),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("New Chat",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                "TODAY",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            _historyItem("Makna Sabar", Icons.chat_bubble_outline),
            _historyItem("Kisah Nabi Musa", Icons.history),
            const Spacer(),
            const Divider(color: Color(0xFF23482F)),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text("Settings",
                  style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey, size: 20),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      onTap: () {},
    );
  }
}