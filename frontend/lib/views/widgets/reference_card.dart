import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class ReferenceCard extends StatelessWidget {
  final VerseReference reference;

  const ReferenceCard({Key? key, required this.reference}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 40.0),
      decoration: BoxDecoration(
        color: const Color(0xFF15291F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF23482F)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF0FB345),
          collapsedIconColor: const Color(0xFF0FB345),
          title: Row(
            children: [
              const Icon(Icons.menu_book, color: Color(0xFF0FB345), size: 18),
              const SizedBox(width: 8),
              Text(
                "REFERENCE VERSES",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0FB345).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reference.ayatNumber,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0FB345),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      reference.arabicText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamily: 'Amiri', // Disarankan tambah font Arab di pubspec
                        height: 1.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    reference.surahName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0FB345),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${reference.translation}"',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}