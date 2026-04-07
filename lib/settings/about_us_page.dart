import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
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
                      'O nama',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // -- Hero Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    color: const Color(0xFFD8E6C0),
                    // TODO: Replace with real image:
                    // Image.asset('assets/images/about_us.jpg', fit: BoxFit.cover)
                    // or Image.network(url, fit: BoxFit.cover)
                    child: const Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 56,
                        color: Color(0xFF6B7C45),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // -- Our Story
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Naša priča',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bookit je platforma koja spaja ljubitelje hrane s najboljim restoranima u njihovoj blizini. Naš cilj je pojednostaviti proces rezervacije i pružiti nezaboravno iskustvo svakom gostu.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        height: 1.7,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Vjerujemo da svaki obrok može biti poseban trenutak. Zato smo izgradili alat koji restoranima pomaže da upravljaju rezervacijama jednostavno, a gostima da pronađu savršeno mjesto za svaku priliku.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // -- Values
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Naše vrijednosti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              ..._values.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                  child: _ValueCard(
                    icon: v['icon'] as IconData,
                    title: v['title'] as String,
                    description: v['description'] as String,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // -- Team
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Tim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 120,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _team.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _TeamCard(member: _team[index]);
                  },
                ),
              ),

              // -- Contact / reach out
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7C45).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6B7C45).withOpacity(0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kontaktirajte nas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ContactRow(
                        icon: Icons.email_outlined,
                        value: 'info@bookit.ba',
                      ),
                      const SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.language_outlined,
                        value: 'www.bookit.ba',
                      ),
                      const SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.location_on_outlined,
                        value: 'Tuzla, Bosna i Hercegovina',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // -- App Version
              Center(
                child: Text(
                  'BookIt v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}


// -- Static Content

const _values = [
  {
    'icon': Icons.favorite_outline,
    'title': 'Strast prema hrani',
    'description': 'Svaki obrok je poseban. Pomažemo Vam da pronađete savršeno mjesto za svaku priliku.',
  },
  {
    'icon': Icons.handshake_outlined,
    'title': 'Partnerstvo s restoranima',
    'description': 'Radimo ruku pod ruku s restoranima kako bismo im pomogli da rastu i uspijevaju.',
  },
  {
    'icon': Icons.security_outlined,
    'title': 'Pouzdanost i sigurnost',
    'description': 'Vaši podaci i rezervacije su sigurni. Transparentnost je osnova svega što radimo.',
  },
];

const _team = [
  {'name': 'Amra Hodžić',   'role': 'Osnivač & CEO',      'initials': 'AH'},
  {'name': 'Tarik Begić',   'role': 'Tehnički direktor',   'initials': 'TB'},
  {'name': 'Sara Muratović','role': 'Dizajn & UX',         'initials': 'SM'},
  {'name': 'Dino Karić',    'role': 'Partnerstva',         'initials': 'DK'},
];


// -- Value Card

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ValueCard({
    required this.icon,
    required this.title,
    required this.description
  });

  @override  
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7C45).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF6B7C45)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// -- Team Card

class _TeamCard extends StatelessWidget {
  final Map<String, String> member;

  const _TeamCard({required this.member});

  @override 
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFD8E6C0),
            child: Text(
              member['initials']!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7C45),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            member['name']!.split(' ').first,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            member['role']!,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall!.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


// -- Contact Row

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.value
  });

  @override  
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7C45)),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
      ],
    );
  }
}