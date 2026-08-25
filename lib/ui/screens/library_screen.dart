import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/repositories/bible_repository.dart';
import 'listening_screen.dart';

/// Library: book list with a "Continue" shortcut and large touch targets.
class LibraryScreen extends StatefulWidget {
  final BibleRepository bible;
  const LibraryScreen({super.key, required this.bible});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Book>> _books;

  @override
  void initState() {
    super.initState();
    _books = widget.bible.books();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open Scripture Voice')),
      body: FutureBuilder<List<Book>>(
        future: _books,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snap.data!;
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, i) {
              final b = books[i];
              return ListTile(
                // Large touch targets for low-literacy users.
                minVerticalPadding: 20,
                title: Text(b.name,
                    style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text(
                    '${b.testament == 'OT' ? 'Old' : 'New'} Testament · ${b.chapterCount} chapters'),
                onTap: () => _pickChapter(context, b),
              );
            },
          );
        },
      ),
    );
  }

  void _pickChapter(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => GridView.count(
        crossAxisCount: 5,
        padding: const EdgeInsets.all(16),
        children: [
          for (var ch = 1; ch <= book.chapterCount; ch++)
            Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListeningScreen(
                        bookId: book.id,
                        bookName: book.name,
                        chapter: ch,
                      ),
                    ),
                  );
                },
                child: Text('$ch'),
              ),
            ),
        ],
      ),
    );
  }
}
