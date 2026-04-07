import 'package:flutter/material.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _messageController = TextEditingController();
  String? _selectedTopic;

  final List<String> _topics = [
    'Problem sa rezervacijom',
    'Problem sa računom',
    'Problem sa aplikacijom',
    'Prijedlog za poboljšanje',
    'Ostalo',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Podrška',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Contact info card ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _ContactRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: 'podrska@bookit.ba',
                            context: context,
                          ),
                          const Divider(
                            height: 20,
                            color: Color(0xFFCCD9B0),
                          ),
                          _ContactRow(
                            icon: Icons.phone_outlined,
                            label: 'Telefon',
                            value: '+387 33 000 000',
                            context: context,
                          ),
                          const Divider(
                            height: 20,
                            color: Color(0xFFCCD9B0),
                          ),
                          _ContactRow(
                            icon: Icons.access_time_outlined,
                            label: 'Radno vrijeme',
                            value: 'Pon – Pet, 09:00 – 17:00',
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Send message section ─────────────────────────────
                    Text(
                      'Pošaljite poruku',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Opišite Vaš problem i javit ćemo Vam se u što kraćem roku.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Topic dropdown ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCCD9B0),
                          width: 1.2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTopic,
                          isExpanded: true,
                          hint: Text(
                            'Odaberite temu',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .color,
                            ),
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF8A9A7A),
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                          dropdownColor:
                              Theme.of(context).colorScheme.surface,
                          onChanged: (value) {
                            setState(() => _selectedTopic = value);
                          },
                          items: _topics
                              .map(
                                (topic) => DropdownMenuItem(
                                  value: topic,
                                  child: Text(topic),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Message text field ───────────────────────────────
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: 500,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Opišite Vaš problem...',
                        hintStyle: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodySmall!.color,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCCD9B0),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6B7C45),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Submit button ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        // TODO: Send support message to Firebase or email
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B7C45),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: Color(0xFF6B7C45),
                              width: 1.8,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Pošaljite poruku',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Contact info row ─────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final BuildContext context;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall!.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}