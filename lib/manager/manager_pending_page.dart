import 'package:flutter/material.dart';
import 'package:bookit/manager/manager_login_page.dart';

class ManagerPendingPage extends StatelessWidget {
  const ManagerPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),

              // ── Pending icon ───────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B84B).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 48,
                  color: Color(0xFFE8B84B),
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ──────────────────────────────────────────────────
              Text(
                'Zahtjev je poslan!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Vaš zahtjev za registraciju restorana je primljen i čeka odobrenje od strane Bookit tima.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // ── What happens next card ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Šta se dešava dalje?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const _PendingStep(
                      number: '1',
                      label: 'Bookit tim pregleda Vaš zahtjev.',
                    ),
                    const SizedBox(height: 12),
                    const _PendingStep(
                      number: '2',
                      label: 'Dobijate email obavijest o odobrenju.',
                    ),
                    const SizedBox(height: 12),
                    const _PendingStep(
                      number: '3',
                      label:
                          'Prijavite se i počnite upravljati rezervacijama!',
                    ),

                    const SizedBox(height: 16),

                    // ── Estimated time note ────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B84B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE8B84B).withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: Color(0xFFE8B84B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pregled traje do 48 radnih sati.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Back to login button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Clears the stack so user can't go back to signup
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManagerLoginPage(),
                      ),
                      (route) => false,
                    );
                  },
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
                    'Nazad na prijavu',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Contact support ────────────────────────────────────────
              GestureDetector(
                // TODO: Navigate to SupportPage or open email
                onTap: () {},
                child: Text(
                  'Trebate pomoć? Kontaktirajte nas',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pending step row ─────────────────────────────────────────────────────────

class _PendingStep extends StatelessWidget {
  final String number;
  final String label;

  const _PendingStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numbered circle
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF6B7C45),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium!.color,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}