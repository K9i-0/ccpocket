import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A custom license page with search functionality.
///
/// Uses [LicenseRegistry.licenses] to load all licenses and groups them
/// by package name. A search bar filters packages by name.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Grouped licenses: package name → list of license paragraphs.
  Map<String, List<LicenseEntry>>? _licenses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    final grouped = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        grouped.putIfAbsent(package, () => []).add(entry);
      }
    }
    if (mounted) {
      setState(() {
        _licenses = Map.fromEntries(
          grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        );
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Open Source Licenses')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search packages...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // License list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _FilteredLicenseList(
                    licenses: _licenses!,
                    searchQuery: _searchQuery,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilteredLicenseList extends StatelessWidget {
  final Map<String, List<LicenseEntry>> licenses;
  final String searchQuery;

  const _FilteredLicenseList({
    required this.licenses,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.toLowerCase();

    final filtered = query.isEmpty
        ? licenses.entries.toList()
        : licenses.entries
              .where((e) => e.key.toLowerCase().contains(query))
              .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No packages found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return _LicensePackageTile(
          packageName: entry.key,
          entries: entry.value,
        );
      },
    );
  }
}

class _LicensePackageTile extends StatelessWidget {
  final String packageName;
  final List<LicenseEntry> entries;

  const _LicensePackageTile({required this.packageName, required this.entries});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final licenseCount = entries.length;
    final subtitle = '$licenseCount license${licenseCount == 1 ? '' : 's'}';

    return ExpansionTile(
      title: Text(
        packageName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final entry in entries) ...[
          const Divider(height: 16),
          _LicenseTextContent(entry: entry),
        ],
      ],
    );
  }
}

class _LicenseTextContent extends StatelessWidget {
  final LicenseEntry entry;

  const _LicenseTextContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paragraphs = entry.paragraphs.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: EdgeInsets.only(left: paragraph.indent * 16.0, bottom: 8),
            child: Text(
              paragraph.text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
