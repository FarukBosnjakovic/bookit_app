import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // -- Top Bar
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
                    'Uslovi korištenja',
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

            // -- Last updated label
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

            // -- Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _TermsSection(
                    title: '1. Prihvatanje uslova',
                    content: 
                      'Korištenjem aplikacije Bookit prihvatate ove uslove korištenja. Molimo Vas da ih pažljivo pročitate prije nego što počnete koristiti našu aplikaciju. Ukoliko se ne slažete sa ovim uslovima, molimo Vas da ne koristite aplikaciju.',
                  ),
                  _TermsSection(
                    title: '2. Opis usluge',
                    content: 
                      'Bookit je platforma koja omogućava korisnicima da pretražuju restorane, pregledaju menije i vrše rezervacije stolova. Aplikacija služi kao posrednik između korisnika i restorana, pri čemu ne preuzimamo direktnu odgovornost za kvalitet usluge pojedinih restorana.',
                  ),
                  _TermsSection(
                    title: '3. Korisnički račun',
                    content: 
                      'Za korištenje određenih funkcija aplikacije potrebno je kreirati korisnički račun. Odgovorni ste za čuvanje povjerljivosti Vaših pristupnih podataka. Obavezujete se da ćete nas odmah obavijestiti o svakoj neovlaštenoj upotrebi Vašeg računa.',
                  ),
                  _TermsSection(
                    title: '4. Rezervacije',
                    content:  
                      'Rezervacije se vrše direktno putem aplikacije. Korisnik je obavezan da otkaže rezervaciju najmanje 2 sata prije dogovorenog termina. Kašnjenje duže od 15 minuta bez prethodne najave može rezultirati otkazivanjem rezervacije od strane restorana.',
                  ),
                  _TermsSection(
                    title: '5. Recenzije i ocjene',
                    content:
                       'Korisnici mogu ostavljati recenzije i ocjene restorana koje su posjetili. Recenzije moraju biti iskrene, relevantne i ne smiju sadržavati uvredljiv sadržaj. Zadržavamo pravo uklanjanja recenzija koje krše ove smjernice.',
                  ),
                  _TermsSection(
                    title: '6. Privatnost',
                    content: 
                      'Prikupljamo i obrađujemo Vaše lične podatke u skladu sa našom Politikom privatnosti. Korištenjem aplikacije pristajete na prikupljanje i obradu podataka kako je opisano u Politici privatnosti.',
                  ),
                  _TermsSection(
                    title: '7. Zabranjena upotreba',
                    content: 
                      'Zabranjeno je koristiti aplikaciju u nezakonite svrhe, lažno predstavljati sebe ili druge, distribuirati zlonamjerni softver, te pokušavati neovlašteno pristupiti sistemima aplikacije.',
                  ),
                  _TermsSection(
                    title: '8. Izmjene uslova',
                    content: 
                      'Zadržavamo pravo izmjene ovih uslova u bilo kojem trenutku. O značajnim izmjenama obavijestit ćemo Vas putem aplikacije ili emaila. Nastavak korištenja aplikacije nakon objave izmjena smatra se prihvatanjem novih uslova.',
                  ),
                  _TermsSection(
                    title: '9. Kontakt',
                    content: 
                      'Ukoliko imate pitanja u vezi sa ovim uslovima korištenja, molimo Vas da nas kontaktirate putem emaila: podrska@bookit.ba ili putem opcije Podrška u aplikaciji.',
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


// -- Terms section

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({
    required this.title,
    required this.content
  });

  @override  
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Section title
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