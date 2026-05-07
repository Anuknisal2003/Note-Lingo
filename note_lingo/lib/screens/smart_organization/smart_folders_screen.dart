import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/smart_organization_provider.dart';

class SmartFoldersScreen extends StatefulWidget {
  const SmartFoldersScreen({super.key});

  @override
  State<SmartFoldersScreen> createState() => _SmartFoldersScreenState();
}

class _SmartFoldersScreenState extends State<SmartFoldersScreen> {
  final TextEditingController _folderNameController = TextEditingController();
  List<String> _selectedTags = [];

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Smart Folder'),
        backgroundColor: AppColors.bgDark,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _folderNameController,
              decoration: const InputDecoration(
                hintText: 'Folder Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Tags:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<SmartOrganizationProvider>(
              builder: (context, provider, _) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.suggestedTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag.name);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag.name);
                          } else {
                            _selectedTags.remove(tag.name);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              if (_folderNameController.text.isNotEmpty) {
                context.read<SmartOrganizationProvider>().createSmartFolder(
                  _folderNameController.text,
                  _selectedTags,
                );
                _folderNameController.clear();
                _selectedTags.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Folders'),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.bgDark,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _showCreateFolderDialog,
        child: const Icon(Icons.add),
      ),
      body: Consumer<SmartOrganizationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          if (provider.suggestedFolders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No folders yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: _showCreateFolderDialog,
                    child: const Text('Create Folder'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.suggestedFolders.length,
            itemBuilder: (context, index) {
              final folder = provider.suggestedFolders[index];
              return _FolderTile(
                name: folder,
                onTap: () {
                  // Navigate to folder contents
                  Navigator.pushNamed(
                    context,
                    '/folder_notes',
                    arguments: folder,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }
}

class _FolderTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _FolderTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.folder, color: AppColors.accent),
        title: Text(name),
        trailing: const Icon(Icons.arrow_forward, color: Colors.grey),
        onTap: onTap,
        tileColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
