import 'package:bookit/settings/privacy_policy_page.dart';
import 'package:bookit/settings/terms_of_service_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bookit/providers/theme_provider.dart';
// import 'package:bookit/settings/about_us_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // TODO: Load these preferences from Firebase/shared_preferences
  bool _locationEnabled = true;
  String _selectedLanguage = 'Bosanski';

  final List<String> _languages = ['Bosanski', 'English', 'Deutsch'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFFF0F5E4),
      // After — reads from active theme
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
                    'Podesavanja',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Izgled (Appearance) ────────────────────────────────
                    _SectionLabel(label: 'Izgled'),
                    _SettingsCard(
                      children: [
                        _ToggleRow(
                          icon: Icons.dark_mode_outlined,
                          label: 'Tamni mod',
                          // Reads live value from ThemeProvider
                          value: context.watch<ThemeProvider>().isDarkMode,
                          onChanged: (value) {
                            // Updates ThemeProvider — rebuilds entire app
                            context.read<ThemeProvider>().toggleTheme(value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Jezik (Language) ───────────────────────────────────
                    _SectionLabel(label: 'Jezik'),
                    _SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.language_outlined,
                                size: 22,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Jezik aplikacije',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedLanguage,
                                  icon: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onChanged: (value) {
                                    // TODO: Apply language change globally
                                    setState(
                                        () => _selectedLanguage = value!);
                                  },
                                  items: _languages
                                      .map(
                                        (lang) => DropdownMenuItem(
                                          value: lang,
                                          child: Text(lang),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Lokacija (Location) ────────────────────────────────
                    _SectionLabel(label: 'Lokacija'),
                    _SettingsCard(
                      children: [
                        _ToggleRow(
                          icon: Icons.location_on_outlined,
                          label: 'Dijeli lokaciju',
                          value: _locationEnabled,
                          onChanged: (value) {
                            // TODO: Request/revoke location permissions
                            setState(() => _locationEnabled = value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── O aplikaciji (About) ───────────────────────────────
                    _SectionLabel(label: 'O aplikaciji'),
                    _SettingsCard(
                      children: [
                        _ArrowRow(
                          icon: Icons.description_outlined,
                          label: 'Uslovi korištenja',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TermsOfServicePage(),
                              ),
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: Color(0xFFECF2DF),
                        ),
                        _ArrowRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Politika privatnosti',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PrivacyPolicyPage()
                              ),
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: Color(0xFFECF2DF),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 22,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Verzija aplikacije',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              ),
                              Text(
                                '1.0.0',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
    );
  }
}

// ─── Settings card (white rounded container) ──────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

// ─── Toggle row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).textTheme.bodyLarge!.color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF6B7C45),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCCD9B0),
          ),
        ],
      ),
    );
  }
}

// ─── Arrow row ────────────────────────────────────────────────────────────────

class _ArrowRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ArrowRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).textTheme.bodyLarge!.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ],
        ),
      ),
    );
  }
}