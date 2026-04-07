import 'package:flutter/material.dart';
import 'login_page.dart';

// -- Data Model for each intro slide 

class IntroSlideData {
    final String imagePath;
    final String title;
    final String subtitle;

    const IntroSlideData({
        required this.imagePath,
        required this.title,
        required this.subtitle,
    });
}

// -- Intro Page (PageView Controller)

class IntroPage extends StatefulWidget {
    const IntroPage({super.key});

    @override  
    State<IntroPage> createState() => _IntroPageState();
}


class _IntroPageState extends State<IntroPage> {
    final PageController _pageController = PageController();
    int _currentPage = 0;

    // Replace imagePath values with your actual asset path.
    // Add them to pubspec.yaml under flutter > assets
    final List<IntroSlideData> _slides = const [
        IntroSlideData(
            imagePath: 'assets/images/intro1.jpg',
            title: 'Napravi svoj jedinstveni restoran',
            subtitle: 'Stolovi i stolice napravljeni od najboljeg drveta'
        ),

        IntroSlideData(
            imagePath: 'assets/images/intro2.jpg',
            title: 'Istrazi jelovnike i\nekskluzivne ponude na svojoj aplikaciji',
            subtitle: 'Otkrij najbolje restorane oko sebe i napravi rezervaciju u samo nekoliko koraka'
        ),

        IntroSlideData(
            imagePath: 'assets/images/intro3.jpg',
            title: 'Rezervisi stol u\nsekundi',
            subtitle: 'Odaberi datum, vrijeme, i broj gostiju - mi cemo odraditi ostalo'
        ),
    ];

    // -- Ovo dugme vodi na sljedeci PageView ili slide
    void _onDalje() {
        if (_currentPage < _slides.length - 1) {
            _pageController.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
            );
        } else {
            _goToHome();
        }
    }

    // -- Ovo dugme vodi na HomePage (trenutno nedostupan)
    void _goToHome() {
        // TODO: Replace with actual home route when ready.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          )
        );
        // ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //         content: Text('Home page coming soon!')
        //     )
        // );
    }

    @override  
    void dispose() {
        _pageController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            // backgroundColor: const Color(0xFFF0F5E4),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
                child: Column(
                    children: [
                        // -- Slides
                        Expanded(
                            child: PageView.builder(
                                controller: _pageController,
                                itemCount: _slides.length,
                                onPageChanged: (index) => 
                                    setState(() => _currentPage = index),
                                itemBuilder: (context, index) => 
                                    _IntroSlide(data: _slides[index]),
                            ),
                        ),

                        // -- Dot indicators
                        _DotIndicator(
                            count: _slides.length,
                            currentIndex: _currentPage,
                        ),

                        const SizedBox(height: 28),

                        // -- Dalje button
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                    onPressed: _onDalje,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6B7C45),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                    ),
                                    child: Text(
                                        _currentPage == _slides.length - 1 ? 'Početak' : 'Dalje',
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                        ),
                                    ),
                                ),
                            ),
                        ),

                        const SizedBox(height: 16), 

                        // -- Preskoci link
                        GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                                'Preskoci',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF4A5340),
                                    fontWeight: FontWeight.w500,
                                ),
                            ),
                        ),

                        const SizedBox(height: 12),
                    ],
                ),
            ),
        );
    }
}

// -- Single Intro Slide Widget

class _IntroSlide extends StatelessWidget {
    final IntroSlideData data;

    const _IntroSlide({required this.data});

    @override  
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
                children: [
                    const SizedBox(height: 24),

                    // -- Arched image 
                    _ArchedImage(imagePath: data.imagePath),

                    const SizedBox(height: 36),

                    // -- Title 
                    Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2A1A),
                            height: 1.3,
                        ),
                    ),

                    const SizedBox(height: 14),

                    // -- Subtitle
                    Text(
                        data.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF5A6355),
                            height: 1.6,
                        ),
                    ),
                ],
            ),
        );
    }
}


// -- Arched Image Widget

class _ArchedImage extends StatelessWidget {
    final String imagePath;

    const _ArchedImage({required this.imagePath});

    @override  
    Widget build(BuildContext context) {
        final double imageWidth = MediaQuery.of(context).size.width * 0.72;
        final double imageHeigth = imageWidth * 1.1;    

        return Stack(
            alignment: Alignment.center,
            children: [
                // Outer card/shadow rectangle
                Container(
                    width: imageWidth + 12,
                    height: imageHeigth + 12,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                            ),
                        ],
                    ),
                ),

                // -- Arched Clip image
                ClipPath(
                    clipper: _ArchClipper(),
                    child: SizedBox(
                        width: imageWidth,
                        height: imageHeigth,
                        child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFD8E6C0),
                                child: const Icon(
                                    Icons.restaurant,
                                    size: 64,
                                    color: Color(0xFF6B7C45),
                                ),
                            ),
                        ),
                    ),
                ),

                // Arch border overlay (decorative green border)
                ClipPath(
                    clipper: _ArchClipper(),
                    child: Container(
                        width: imageWidth,
                        height: imageHeigth,
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF6B7C45).withOpacity(0.5),
                                width: 2,
                            ),
                        ),
                    ),
                ),
            ],
        );
    }
}


// -- Custom arch shape clipper

class _ArchClipper extends CustomClipper<Path> {
    @override 
    Path getClip(Size size) {
        final double archRadius = size.width / 2;
        final path = Path();

        path.moveTo(0, size.height);
        path.lineTo(0, archRadius);
        path.arcToPoint(
            Offset(size.width, archRadius),
            radius: Radius.circular(archRadius),
            clockwise: false,
        );
        path.lineTo(size.width, size.height);
        path.close();
        return path;
    }

    @override  
    bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


// -- Page dot indicator

class _DotIndicator extends StatelessWidget {
    final int count;
    final int currentIndex;

    const _DotIndicator({required this.count, required this.currentIndex});

    @override  
    Widget build(BuildContext context) {
        return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (index) {
                final bool isActive = index == currentIndex;
                return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 16,
                    height: 6,
                    decoration: BoxDecoration(
                        color: isActive 
                            ? const Color(0xFFD94F4F)
                            : const Color(0xFFD94F4F).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                    ),
                );
            }),
        );
    }
}