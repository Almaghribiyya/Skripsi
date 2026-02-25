import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../services/auth_service.dart';

class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF172B1E),
      child: SafeArea(
        child: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      viewModel.createNewSession();
                      Navigator.pop(context); // Tutup sidebar setelah diklik
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
                    "CHAT HISTORY",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewModel.sessions.length,
                    itemBuilder: (context, index) {
                      final session = viewModel.sessions[index];
                      final isActive = session.id == viewModel.activeSessionId;
                      
                      return ListTile(
                        selected: isActive,
                        selectedTileColor: const Color(0xFF23482F),
                        leading: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                        title: Text(
                          session.title,
                          style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[300], 
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          color: const Color(0xFF102216),
                          onSelected: (value) {
                            if (value == 'rename') {
                              _showRenameDialog(context, viewModel, session.id, session.title);
                            } else if (value == 'delete') {
                              viewModel.deleteSession(session.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'rename',
                              child: Text('Rename', style: TextStyle(color: Colors.white)),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        onTap: () {
                          viewModel.switchSession(session.id);
                          Navigator.pop(context); // Tutup sidebar
                        },
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0xFF23482F)),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text("Settings", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    // Siapkan navigasi ke halaman pengaturan
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await AuthService().signOut();
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatViewModel viewModel, String sessionId, String currentTitle) {
    final TextEditingController titleController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF172B1E),
          title: const Text("Rename Chat", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter new title",
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                viewModel.renameSession(sessionId, titleController.text);
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Color(0xFF0FB345))),
            ),
          ],
        );
      },
    );
  }
}