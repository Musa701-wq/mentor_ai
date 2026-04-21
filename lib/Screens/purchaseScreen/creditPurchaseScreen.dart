import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/IAPService.dart';
import '../../services/adService.dart';

class CreditsStoreScreen extends StatefulWidget {
  const CreditsStoreScreen({super.key});

  @override
  State<CreditsStoreScreen> createState() => _CreditsStoreScreenState();
}

class _CreditsStoreScreenState extends State<CreditsStoreScreen> with TickerProviderStateMixin {
  final InAppReview _inAppReview = InAppReview.instance;
  late IAPService _iapService;
  late TabController _tabController;
  int _userCredits = 0;
  bool _isLoadingCredits = true;
  bool _showFullScreenLoading = false;
  bool _isWatchingAd = false;
  StreamSubscription? _creditsSubscription;
  static const String _privacyUrl = 'https://vectorlabzlimited.com/privacy-policy/';
  static const String _termsUrl = 'https://vectorlabzlimited.com/terms-of-use/';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserCredits();
    _initializeIAP();
    _setupCreditsListener();
  }

  @override
  void dispose() {
    _creditsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupCreditsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _creditsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          setState(() {
            _userCredits = doc.data()?['credits'] ?? 0;
            _isLoadingCredits = false;
          });
        }
      }, onError: (error) {
        debugPrint('Error listening to credits: $error');
        setState(() => _isLoadingCredits = false);
      });
    } else {
      setState(() => _isLoadingCredits = false);
    }
  }

  Future<void> _loadUserCredits() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        setState(() {
          _userCredits = doc.data()?['credits'] ?? 0;
          _isLoadingCredits = false;
        });
      } catch (e) {
        debugPrint('Error loading credits: $e');
        setState(() => _isLoadingCredits = false);
      }
    } else {
      setState(() => _isLoadingCredits = false);
    }
  }

  void _initializeIAP() {
    _iapService = Provider.of<IAPService>(context, listen: false);
    
    // Ensure it's initialized (though main.dart does it, safety first)
    _iapService.init().then((_) {
      if (_iapService.errorMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Store error: ${_iapService.errorMessage}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });

    // Handle errors from the service
    /* _iapService.onError = (error) {
      if (mounted) {
        setState(() => _showFullScreenLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }; */
  }

  Future<void> _requestReview() async {
    if (await _inAppReview.isAvailable()) {
      _inAppReview.requestReview();
    } else {
      _inAppReview.openStoreListing();
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _showSuccessDialog(String productName, int creditsAdded) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.celebration_rounded, size: 60, color: Colors.purple),
            const SizedBox(height: 16),
            const Text(
              'Purchase Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve received $creditsAdded credits from $productName!',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Total Credits: ${_userCredits}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue', style: TextStyle(color: Colors.purple)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestReview();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rate App'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        ChangeNotifierProvider.value(
          value: _iapService,
          child: Scaffold(
            backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
            appBar: AppBar(
              title: const Text(
                'Credits & Subscription',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              centerTitle: false,
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                labelColor: Colors.purple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.purple,
                tabs: const [
                  Tab(text: 'Store', icon: Icon(Icons.store)),
                  Tab(text: 'FAQ', icon: Icon(Icons.help_outline)),
                ],

              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildStoreTab(isDark, screenWidth, screenHeight),
                _buildFAQTab(isDark, screenWidth, screenHeight),
              ],
            ),
          ),
        ),
        if (_showFullScreenLoading || _isWatchingAd)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    strokeWidth: 4,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    _isWatchingAd ? 'Loading ad...' : 'Processing purchase...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStoreTab(bool isDark, double screenWidth, double screenHeight) {
    return Consumer<IAPService>(
      builder: (context, iapService, _) {
        if (iapService.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
                SizedBox(height: 16),
                Text('Loading store...'),
              ],
            ),
          );
        }

        if (iapService.errorMessage != null) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Store Unavailable',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    iapService.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _iapService.init,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Credits Card
                    _buildCreditsCard(screenWidth, screenHeight),
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Subscription Section
                    _buildSubscriptionSection(iapService, screenWidth, screenHeight),
                    SizedBox(height: screenHeight * 0.03),

                    Center(
                      child: TextButton(onPressed: (){
                        _iapService.restore();
                      }, child: Text('Restore Purchase')),
                    ),

                    SizedBox(height: screenHeight * 0.03),
                    // Credits Section
                    Text(
                      'Buy Credits',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'Credits are used for AI processing including homework help, note generation, and quiz creation',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),
              ),
            ),
            
            // Credits Grid
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: screenWidth < 600 ? 2 : 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final creditProducts = iapService.products
                        .where((p) => IAPService.creditIds.contains(p.id))
                        .toList();
                    
                    if (index >= creditProducts.length) return null;
                    
                    final product = creditProducts[index];
                    final credits = IAPService.getCreditsForProduct(product.id);
                    
                    return _buildCreditCard(product, credits, screenWidth, screenHeight);
                  },
                  childCount: iapService.products
                      .where((p) => IAPService.creditIds.contains(p.id))
                      .length,
                ),
              ),
            ),

            // Legal Section in body
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _launchUrl(_privacyUrl),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                            ),
                            child: const Text('Privacy Policy'),
                          ),
                          TextButton(
                            onPressed: () => _launchUrl(_termsUrl),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                            ),
                            child: const Text('Terms of Use'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: screenHeight * 0.05)),
          ],
        );
      },
    );
  }



  Widget _buildFAQTab(bool isDark, double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.w800,
              color: Colors.purple,
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          
          _buildFAQItem(
            'What are credits used for?',
            'Credits are consumed for AI processing including:\n• Homework help and explanations\n• Automatic note generation from images\n• Quiz creation and answers\n• AI-powered study assistance',
            Icons.auto_awesome,
            screenWidth,
            screenHeight,
            isDark,
          ),
          
          _buildFAQItem(
            'What does the subscription include?',
            'Premium subscription provides:\n• Ad-free experience across the app\n• Priority AI processing (faster responses)',
            Icons.star,
            screenWidth,
            screenHeight,
            isDark,
          ),

          
          _buildFAQItem(
            'Do credits expire?',
            'No, your credits never expire! Once purchased or earned, they remain in your account until you use them for AI features.',
            Icons.schedule,
            screenWidth,
            screenHeight,
            isDark,
          ),
          
          _buildFAQItem(
            'Can I cancel my subscription?',
            'Yes, you can cancel your subscription anytime through your device\'s app store settings. You\'ll continue to have premium access until the end of your billing period.',
            Icons.cancel,
            screenWidth,
            screenHeight,
            isDark,
          ),
          
          _buildFAQItem(
            'Is my payment information secure?',
            'Absolutely! All payments are processed securely through Apple App Store or Google Play Store. We never store your payment information.',
            Icons.security,
            screenWidth,
            screenHeight,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsCard(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade600,
            Colors.purple.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: screenWidth * 0.07,
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Credits',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                _isLoadingCredits
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '$_userCredits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white70,
                size: screenWidth * 0.05,
              ),
              const SizedBox(height: 4),
              Text(
                'Used for AI\nprocessing',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: screenWidth * 0.03,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(IAPService iapService, double screenWidth, double screenHeight) {
    final subscriptionProduct = iapService.products
        .where((p) => p.id == IAPService.subscriptionId)
        .firstOrNull;
    
    if (subscriptionProduct == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscription',
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          'Enjoy ad-free experience and priority AI processing',
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        _buildEnhancedSubscriptionCard(subscriptionProduct, iapService.isPro, screenWidth, screenHeight),
        SizedBox(height: screenHeight * 0.04),
      ],
    );
  }

  Widget _buildEnhancedSubscriptionCard(ProductDetails product, bool isPro, double screenWidth, double screenHeight) {
    return GestureDetector(
      onTap: isPro ? null : () async {
        setState(() => _showFullScreenLoading = true);
        
        bool purchaseCompleted = false;
        
        void purchaseListener() {
          if (!_iapService.isBuying && !purchaseCompleted) {
            purchaseCompleted = true;
            _iapService.removeListener(purchaseListener);
            
            if (mounted) {
              setState(() => _showFullScreenLoading = false);
              
              if (_iapService.isPro) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subscription activated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          }
        }
        
        _iapService.addListener(purchaseListener);
        
        try {
          await _iapService.buySubscription();
        } catch (e) {
          purchaseCompleted = true;
          _iapService.removeListener(purchaseListener);
          
          if (mounted) {
            setState(() => _showFullScreenLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Subscription failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        
        Future.delayed(const Duration(seconds: 30), () {
          if (!purchaseCompleted && mounted) {
            purchaseCompleted = true;
            _iapService.removeListener(purchaseListener);
            setState(() => _showFullScreenLoading = false);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.05),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPro 
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isPro ? Colors.green : Colors.orange).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPro ? Icons.check_circle : Icons.star,
                  color: Colors.white,
                  size: screenWidth * 0.08,
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPro ? 'Premium Active' : 'Premium Subscription',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPro ? 'You have premium access' : product.price + '/month',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Subscribe',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            
            // Benefits
            _buildSubscriptionBenefit(Icons.block, 'No ads throughout the app', screenWidth),
            _buildSubscriptionBenefit(Icons.flash_on, 'Priority AI processing', screenWidth),
            _buildSubscriptionBenefit(Icons.support_agent, 'Premium support', screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBenefit(IconData icon, String text, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: screenWidth * 0.04),
          SizedBox(width: screenWidth * 0.03),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(ProductDetails product, int credits, double screenWidth, double screenHeight) {
    return GestureDetector(
      onTap: () async {
        setState(() => _showFullScreenLoading = true);
        
        final initialCredits = _userCredits;
        bool purchaseCompleted = false;
        
        void creditsListener() {
          if (!_iapService.isBuying && !purchaseCompleted) {
            purchaseCompleted = true;
            _iapService.removeListener(creditsListener);
            
            if (mounted) {
              setState(() => _showFullScreenLoading = false);
              
              if (_userCredits > initialCredits) {
                final creditsAdded = _userCredits - initialCredits;
                _showSuccessDialog(product.title, creditsAdded);
              }
            }
          }
        }
        
        _iapService.addListener(creditsListener);
        
        try {
          await _iapService.buyCredits(product.id);
        } catch (e) {
          purchaseCompleted = true;
          _iapService.removeListener(creditsListener);
          
          if (mounted) {
            setState(() => _showFullScreenLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchase failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        
        Future.delayed(const Duration(seconds: 30), () {
          if (!purchaseCompleted && mounted) {
            purchaseCompleted = true;
            _iapService.removeListener(creditsListener);
            setState(() => _showFullScreenLoading = false);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Colors.purple,
                size: screenWidth * 0.08,
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              '$credits Credits',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              product.price,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'For AI processing',
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: screenWidth * 0.05),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, IconData icon, double screenWidth, double screenHeight, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.purple, size: screenWidth * 0.06),
        title: Text(
          question,
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

