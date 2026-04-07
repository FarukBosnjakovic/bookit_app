import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                    'Politika privatnosti',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Last updated label ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Posljednje ažuriranje: Januar 2025.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _PolicySection(
                    title: '1. Uvod',
                    content:
                        'Bookit d.o.o. ("mi", "naš") posvećen je zaštiti Vaše privatnosti. Ova Politika privatnosti objašnjava kako prikupljamo, koristimo, dijelimo i štitimo Vaše lične podatke kada koristite našu aplikaciju. Molimo Vas da pažljivo pročitate ovaj dokument.',
                  ),
                  _PolicySection(
                    title: '2. Podaci koje prikupljamo',
                    content:
                        'Prikupljamo sljedeće vrste podataka:\n\n'
                        '• Lični podaci: ime, prezime, email adresa i broj telefona koje unosite pri registraciji.\n\n'
                        '• Podaci o lokaciji: Vašu geografsku lokaciju radi prikazivanja restorana u blizini, uz Vašu izričitu dozvolu.\n\n'
                        '• Podaci o rezervacijama: historija rezervacija, posjećeni restorani i ostavljene recenzije.\n\n'
                        '• Tehnički podaci: vrsta uređaja, operativni sistem i anonimni podaci o korištenju aplikacije.',
                  ),
                  _PolicySection(
                    title: '3. Kako koristimo Vaše podatke',
                    content:
                        'Vaše podatke koristimo za sljedeće svrhe:\n\n'
                        '• Upravljanje Vašim korisničkim računom i autentifikaciju.\n\n'
                        '• Obradu i upravljanje rezervacijama restorana.\n\n'
                        '• Personalizaciju sadržaja i preporuka restorana.\n\n'
                        '• Slanje obavijesti o rezervacijama i promotivnih ponuda (uz Vašu dozvolu).\n\n'
                        '• Poboljšanje kvaliteta naše usluge i korisničkog iskustva.',
                  ),
                  _PolicySection(
                    title: '4. Dijeljenje podataka',
                    content:
                        'Vaše lične podatke ne prodajemo trećim stranama. Podatke možemo dijeliti isključivo u sljedećim slučajevima:\n\n'
                        '• Sa restoranima u svrhu potvrde i upravljanja Vašim rezervacijama.\n\n'
                        '• Sa pouzdanim partnerima koji nam pomažu u pružanju usluge (npr. Firebase, cloud servisi).\n\n'
                        '• Kada to zahtijeva zakon ili nadležni organ vlasti.',
                  ),
                  _PolicySection(
                    title: '5. Pohrana i sigurnost podataka',
                    content:
                        'Vaši podaci se pohranjuju na sigurnim serverima putem Firebase platforme. Primjenjujemo odgovarajuće tehničke i organizacijske mjere zaštite, uključujući enkripciju podataka u prijenosu i pohrani. Međutim, nijedan sistem nije u potpunosti siguran, te ne možemo garantovati apsolutnu sigurnost.',
                  ),
                  _PolicySection(
                    title: '6. Vaša prava',
                    content:
                        'U skladu sa važećim propisima o zaštiti podataka, imate pravo na:\n\n'
                        '• Pristup Vašim ličnim podacima koje čuvamo.\n\n'
                        '• Ispravku netačnih ili nepotpunih podataka.\n\n'
                        '• Brisanje Vašeg računa i svih povezanih podataka.\n\n'
                        '• Prigovor na obradu Vaših podataka u marketinške svrhe.\n\n'
                        'Za ostvarivanje ovih prava kontaktirajte nas na: privatnost@bookit.ba',
                  ),
                  _PolicySection(
                    title: '7. Kolačići i praćenje',
                    content:
                        'Aplikacija koristi anonimne analitičke alate za praćenje korištenja u svrhu poboljšanja korisničkog iskustva. Ovi podaci su u potpunosti anonimizirani i ne mogu se povezati sa Vašim identitetom.',
                  ),
                  _PolicySection(
                    title: '8. Podaci djece',
                    content:
                        'Naša aplikacija nije namijenjena osobama mlađim od 16 godina. Ne prikupljamo namjerno lične podatke djece. Ukoliko saznamo da smo prikupili podatke djeteta, odmah ćemo ih obrisati.',
                  ),
                  _PolicySection(
                    title: '9. Izmjene politike privatnosti',
                    content:
                        'Možemo periodično ažurirati ovu Politiku privatnosti. O svim značajnim izmjenama obavijestit ćemo Vas putem aplikacije ili emaila. Preporučujemo da povremeno pregledate ovu stranicu kako biste bili upoznati sa eventualnim izmjenama.',
                  ),
                  _PolicySection(
                    title: '10. Kontakt',
                    content:
                        'Ukoliko imate pitanja ili nedoumice u vezi sa ovom Politikom privatnosti, slobodno nas kontaktirajte:\n\n'
                        'Email: privatnost@bookit.ba\n'
                        'Podrška u aplikaciji: Podesavanja → Pomoc → Podrska',
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Policy section ───────────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          const SizedBox(height: 8),
          // Section content
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium!.color,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}