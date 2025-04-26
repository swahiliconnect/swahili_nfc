import 'dart:math';

import 'package:flutter/material.dart';
import 'package:swahili_nfc/swahili_nfc.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter/services.dart';

void main() {
  // Enable NFC debugging for development
  SwahiliNFC.enableDebugLogging(true);
  runApp(const SwahiliNFCApp());
}

class SwahiliNFCApp extends StatefulWidget {
  const SwahiliNFCApp({Key? key}) : super(key: key);

  @override
  State<SwahiliNFCApp> createState() => _SwahiliNFCAppState();
}

class _SwahiliNFCAppState extends State<SwahiliNFCApp> {
  // Theme mode state
  ThemeMode _themeMode = ThemeMode.system;

  // Toggle theme between light and dark
  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwahiliNFC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF079F71),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Light mode specific settings
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF079F71), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF079F71),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Dark mode specific settings
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF07C78A), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      themeMode: _themeMode,
      home: NFCHomePage(toggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class NFCHomePage extends StatefulWidget {
  final Function toggleTheme;
  final ThemeMode themeMode;

  const NFCHomePage({
    Key? key,
    required this.toggleTheme,
    required this.themeMode,
  }) : super(key: key);

  @override
  State<NFCHomePage> createState() => _NFCHomePageState();
}

class _NFCHomePageState extends State<NFCHomePage> with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;
  
  // NFC Status
  bool _isNfcAvailable = false;
  String _statusMessage = 'Initializing...';
  bool _isOperationInProgress = false;
  
  // Read data
  BusinessCardData? _lastScannedCard;
  String _rawNfcData = "No data";
  
  // Write selection
  String _selectedWriteOption = 'contact'; // 'contact' or 'link'
  
  // Contact form controllers
  final _contactFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Link form controllers
  final _linkFormKey = GlobalKey<FormState>();
  final _linkTitleController = TextEditingController();
  final _linkUrlController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Check NFC availability when the app starts
    _checkNfcAvailability();
  }
  
  void _handleTabChange() {
    // Close keyboard when switching tabs
    FocusScope.of(context).unfocus();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    
    // Dispose of all controllers
    _nameController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkTitleController.dispose();
    _linkUrlController.dispose();
    
    super.dispose();
  }

  // Check if NFC is available on the device
  Future<void> _checkNfcAvailability() async {
    try {
      setState(() {
        _statusMessage = 'Checking NFC availability...';
      });
      
      // Call the SwahiliNFC API to check availability
      final isAvailable = await SwahiliNFC.isAvailable();
      
      setState(() {
        _isNfcAvailable = isAvailable;
        _statusMessage = isAvailable
            ? 'NFC is available. Ready to use.'
            : 'NFC is not available on this device.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking NFC: ${e.toString()}';
      });
      _showErrorSnackBar('Failed to check NFC availability');
    }
  }
  
  // Open NFC operation bottom sheet
  void _showNfcOperationSheet({required bool isRead}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NFCOperationSheet(
        isRead: isRead,
        statusMessage: _statusMessage,
        onCancel: () {
          Navigator.pop(context);
          setState(() {
            _isOperationInProgress = false;
          });
        },
      ),
    );
  }

  // Read data from an NFC tag
  Future<void> _readTag() async {
    if (_isOperationInProgress) return;
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place NFC card near device...';
      _rawNfcData = "Reading...";
    });
    
    // Show the NFC operation sheet
    _showNfcOperationSheet(isRead: true);
    
    try {
      // Try to get raw data first for debugging
      String rawData = "";
      try {
        rawData = await SwahiliNFC.dumpTagRawData();
      } catch (e) {
        rawData = "Error getting raw data: ${e.toString()}";
      }
      
      // Call the SwahiliNFC API to read a tag
      final cardData = await SwahiliNFC.readTag();
      
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _lastScannedCard = cardData;
        _rawNfcData = rawData;
        _statusMessage = 'Card read successfully!';
        _isOperationInProgress = false;
        
        // Switch to the Read tab to show results
        _tabController.animateTo(1);
      });
      
      _showSuccessDialog('Success', 'Card read successfully');
    } catch (e) {
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _statusMessage = 'Error reading card: ${e.toString()}';
        _isOperationInProgress = false;
      });
      
      if (e is NFCError) {
        _showErrorDialog('NFC Read Error', e);
      } else {
        _showErrorSnackBar('Failed to read NFC card: ${e.toString()}');
      }
    }
  }

  // Write link to an NFC tag
  Future<void> _writeLink() async {
    if (!_linkFormKey.currentState!.validate() || _isOperationInProgress) {
      return;
    }
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place writable NFC card near device...';
    });
    
    // Show the NFC operation sheet
    _showNfcOperationSheet(isRead: false);
    
    try {
      // Create business card data with link information
      final cardData = BusinessCardData(
        name: _linkTitleController.text.trim(),
        custom: {
          'type': 'link',
          'url': _linkUrlController.text.trim(),
        },
      );
      
      // Write to tag with verification
      final success = await SwahiliNFC.writeTag(
        data: cardData,
        verifyAfterWrite: true,
      );
      
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _statusMessage = success 
            ? 'Link written successfully!' 
            : 'Failed to write to card.';
        _isOperationInProgress = false;
      });
      
      if (success) {
        _showSuccessDialog('Success', 'Link written successfully to card');
        
        // Clear form on success
        _linkTitleController.clear();
        _linkUrlController.clear();
      } else {
        _showErrorSnackBar('Failed to write to card');
      }
    } catch (e) {
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _statusMessage = 'Error writing link: ${e.toString()}';
        _isOperationInProgress = false;
      });
      
      if (e is NFCError) {
        _showErrorDialog('NFC Write Error', e);
      } else {
        _showErrorSnackBar('Failed to write to NFC card: ${e.toString()}');
      }
    }
  }

  // Write contact information to an NFC tag
  Future<void> _writeContact() async {
    if (!_contactFormKey.currentState!.validate() || _isOperationInProgress) {
      return;
    }
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place writable NFC card near device...';
    });
    
    // Show the NFC operation sheet
    _showNfcOperationSheet(isRead: false);
    
    try {
      // Create business card data with contact information
      final cardData = BusinessCardData(
        name: _nameController.text.trim(),
        company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        position: _positionController.text.trim().isNotEmpty ? _positionController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        custom: {
          'type': 'contact'
        },
      );
      
      // Write to tag with verification
      final success = await SwahiliNFC.writeTag(
        data: cardData,
        verifyAfterWrite: true,
      );
      
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _statusMessage = success 
            ? 'Contact written successfully!' 
            : 'Failed to write to card.';
        _isOperationInProgress = false;
      });
      
      if (success) {
        _showSuccessDialog('Success', 'Contact information written successfully to card');
        
        // Clear form on success
        _nameController.clear();
        _companyController.clear();
        _positionController.clear();
        _emailController.clear();
        _phoneController.clear();
      } else {
        _showErrorSnackBar('Failed to write to card');
      }
    } catch (e) {
      // Pop the bottom sheet
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      setState(() {
        _statusMessage = 'Error writing contact: ${e.toString()}';
        _isOperationInProgress = false;
      });
      
      if (e is NFCError) {
        _showErrorDialog('NFC Write Error', e);
      } else {
        _showErrorSnackBar('Failed to write to NFC card: ${e.toString()}');
      }
    }
  }
  
  // Share contact as VCF or text
  void _shareContact(BusinessCardData contact) {
    // In a complete implementation, this would create and share a VCF file
    // For this example, we'll just show a dialog with the contact info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Contact'),
        content: const Text('In a full implementation, this would share the contact as a VCF file or via other sharing methods.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Open URL from link card
  Future<void> _openUrl(String url) async {
    if (url.isEmpty) {
      _showErrorSnackBar('No URL available');
      return;
    }
    
    // Add http:// prefix if missing
    String formattedUrl = url;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    
    try {
      final uri = Uri.parse(formattedUrl);
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      } else {
        _showErrorSnackBar('Could not open URL: $formattedUrl');
      }
    } catch (e) {
      _showErrorSnackBar('Invalid URL: $formattedUrl');
    }
  }

  // Show a success dialog
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show a success SnackBar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show an error SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show a detailed error dialog for NFC errors
  void _showErrorDialog(String title, NFCError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${error.message}'),
              const SizedBox(height: 16),
              const Text('Troubleshooting Tips:', 
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...error.troubleshootingTips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(tip)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/swahilicard_logo.png', height: 24),
            const SizedBox(width: 8),
            const Text('SwahiliNFC'),
          ],
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark 
                ? Icons.light_mode 
                : Icons.dark_mode,
            ),
            onPressed: () => widget.toggleTheme(),
          ),
          // Refresh NFC status button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkNfcAvailability,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Write'),
            Tab(icon: Icon(Icons.contactless), text: 'Read'),
            Tab(icon: Icon(Icons.info), text: 'Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // WRITE TAB
          _buildWriteTab(theme),
          
          // READ TAB
          _buildReadTab(theme),
          
          // STATUS TAB
          _buildStatusTab(theme),
        ],
      ),
    );
  }
  
  // Write Tab UI
  Widget _buildWriteTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Write type selector
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What would you like to write?',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildOptionCard(
                        theme: theme,
                        title: 'Contact',
                        icon: Icons.person,
                        isSelected: _selectedWriteOption == 'contact',
                        onTap: () => setState(() => _selectedWriteOption = 'contact'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOptionCard(
                        theme: theme,
                        title: 'Link',
                        icon: Icons.link,
                        isSelected: _selectedWriteOption == 'link',
                        onTap: () => setState(() => _selectedWriteOption = 'link'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Conditional form based on selection
        _selectedWriteOption == 'contact'
            ? _buildContactForm(theme)
            : _buildLinkForm(theme),
      ],
    );
  }
  
  // Build option card for write type selection
  Widget _buildOptionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Contact Form UI
  Widget _buildContactForm(ThemeData theme) {
    return Form(
      key: _contactFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic information card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Personal Information',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Name Field (Required)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Company Field
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      prefixIcon: Icon(Icons.business),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  
                  // Position Field
                  TextFormField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position',
                      prefixIcon: Icon(Icons.work),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ),
          
          // Contact information card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_phone, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Contact Information',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        // Simple email validation
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
          ),
          
          // Write button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isNfcAvailable && !_isOperationInProgress 
                  ? _writeContact 
                  : null,
              icon: const Icon(Icons.contactless),
              label: const Text('WRITE CONTACT TO NFC CARD', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  // Link Form UI
  Widget _buildLinkForm(ThemeData theme) {
    return Form(
      key: _linkFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Link information card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Link Information',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Link Title Field (Required)
                  TextFormField(
                    controller: _linkTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Link Title *',
                      prefixIcon: Icon(Icons.title),
                      hintText: 'e.g., My Website, GitHub Profile',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // URL Field (Required)
                  TextFormField(
                    controller: _linkUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL *',
                      prefixIcon: Icon(Icons.language),
                      hintText: 'e.g., https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'URL is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Write button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isNfcAvailable && !_isOperationInProgress 
                  ? _writeLink
                  : null,
              icon: const Icon(Icons.contactless),
              label: const Text('WRITE LINK TO NFC CARD', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  // Read Tab UI
  Widget _buildReadTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Read button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isNfcAvailable && !_isOperationInProgress 
                  ? _readTag 
                  : null,
              icon: const Icon(Icons.contactless),
              label: const Text('READ NFC CARD', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Last scanned card display
          if (_lastScannedCard != null)
            _buildScannedCardDisplay(theme)
          else
            _buildEmptyScannedCardPlaceholder(theme),
        ],
      ),
    );
  }
  
  // Scanned Card Display
  Widget _buildScannedCardDisplay(ThemeData theme) {
    final card = _lastScannedCard!;
    final isLink = card.custom.containsKey('type') && card.custom['type'] == 'link';
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLink ? Icons.link : Icons.person,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isLink ? 'Link Card' : 'Contact Card',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                if (isLink)
                  IconButton(
                    onPressed: () => _openUrl(card.custom['url'] ?? ''),
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open URL',
                  )
                else
                  IconButton(
                    onPressed: () => _shareContact(card),
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Contact',
                  ),
              ],
            ),
            const Divider(),
            
            if (isLink) ...[
              // Link card display
              _buildInfoRow(theme, 'Title', card.name),
              if (card.custom.containsKey('url'))
                _buildInfoRow(theme, 'URL', card.custom['url']!),
              
              // Action button for link
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(card.custom['url'] ?? ''),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('OPEN LINK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ] else ...[
              // Contact card display
              _buildInfoRow(theme, 'Name', card.name),
              if (card.company != null)
                _buildInfoRow(theme, 'Company', card.company!),
              if (card.position != null)
                _buildInfoRow(theme, 'Position', card.position!),
              
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              if (card.email != null)
                _buildContactRow(
                  theme,
                  'Email',
                  card.email!,
                  Icons.email,
                  () => _launchEmail(card.email!),
                ),
              if (card.phone != null)
                _buildContactRow(
                  theme,
                  'Phone',
                  card.phone!,
                  Icons.phone,
                  () => _launchPhone(card.phone!),
                ),
              
              // Social media links if available
              if (card.social.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                
                Text(
                  'Social Profiles',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                
                ...card.social.entries.map((entry) => 
                  _buildSocialRow(
                    theme, 
                    entry.key, 
                    entry.value,
                    () => _openUrl(entry.value),
                  )
                ),
              ],
              
              // Action buttons for contact
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: card.phone != null ? () => _launchPhone(card.phone!) : null,
                      icon: const Icon(Icons.phone),
                      label: const Text('CALL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: card.email != null ? () => _launchEmail(card.email!) : null,
                      icon: const Icon(Icons.email),
                      label: const Text('EMAIL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareContact(card),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('SAVE CONTACT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Launch email app
  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
    );
    
    try {
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      } else {
        _showErrorSnackBar('Could not launch email app');
      }
    } catch (e) {
      _showErrorSnackBar('Error launching email app: ${e.toString()}');
    }
  }
  
  // Launch phone app
  Future<void> _launchPhone(String phone) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    
    try {
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      } else {
        _showErrorSnackBar('Could not launch phone app');
      }
    } catch (e) {
      _showErrorSnackBar('Error launching phone app: ${e.toString()}');
    }
  }
  
  // Build contact row with action
  Widget _buildContactRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build social media row
  Widget _buildSocialRow(
    ThemeData theme,
    String platform,
    String handle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(_getSocialIcon(platform), size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPlatformName(platform),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      handle,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Format platform name for display
  String _formatPlatformName(String platform) {
    // Capitalize first letter of each word
    return platform.split('_').map((word) => 
      word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
  }
  
  // Build information row
  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
  
  // Empty Scanned Card Placeholder
  Widget _buildEmptyScannedCardPlaceholder(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contactless_outlined, 
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No card scanned yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Press "READ NFC CARD" and place an NFC card near your device',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Status Tab UI
  Widget _buildStatusTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _checkNfcAvailability,
      color: theme.colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NFC Status Card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.nfc,
                      size: 64,
                      color: _isNfcAvailable ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NFC Status',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 8
                      ),
                      decoration: BoxDecoration(
                        color: _isNfcAvailable 
                            ? theme.colorScheme.primary.withOpacity(0.1) 
                            : theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isNfcAvailable ? theme.colorScheme.primary : theme.colorScheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isNfcAvailable ? Icons.check_circle : Icons.error,
                            color: _isNfcAvailable ? theme.colorScheme.primary : theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isNfcAvailable ? 'Available' : 'Not Available',
                            style: TextStyle(
                              color: _isNfcAvailable ? theme.colorScheme.primary : theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _checkNfcAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh NFC Status'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            // Troubleshooting card
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Troubleshooting',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTroubleshootingTip(
                      theme,
                      'NFC Not Working?',
                      'Ensure NFC is enabled in your device settings. Go to Settings > Connected Devices > Connection preferences > NFC',
                    ),
                    const SizedBox(height: 12),
                    _buildTroubleshootingTip(
                      theme,
                      'Card Not Detected',
                      'Try moving the card around the back of your phone. Different phones have the NFC antenna in different positions.',
                    ),
                    const SizedBox(height: 12),
                    _buildTroubleshootingTip(
                      theme,
                      'Write Failed',
                      'Make sure your NFC tag is writable and not locked. Try writing with minimal data first (just title and URL for links).',
                    ),
                    const SizedBox(height: 12),
                    _buildTroubleshootingTip(
                      theme,
                      'App Features',
                      'This app allows you to write contacts or links to NFC cards. When read back, appropriate actions can be taken (like calling, emailing, or opening links).',
                    ),
                  ],
                ),
              ),
            ),
            
            // About SwahiliNFC card
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'About SwahiliNFC',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SwahiliNFC is a comprehensive Flutter package for NFC business card applications with a focus on secure contact exchange.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Key Features:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem(theme, 'Simplified Tag Operations'),
                    _buildFeatureItem(theme, 'Advanced Security Model'),
                    _buildFeatureItem(theme, 'Multi-Device Management'),
                    _buildFeatureItem(theme, 'Analytics & Insights'),
                    _buildFeatureItem(theme, 'Offline Capabilities'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to build feature item
  Widget _buildFeatureItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper to build troubleshooting tips
  Widget _buildTroubleshootingTip(ThemeData theme, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lightbulb_outline,
          color: theme.colorScheme.secondary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
  
  // Get appropriate icon for social media
  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitter':
      case 'x':
        return Icons.alternate_email;
      case 'linkedin':
        return Icons.business_center;
      case 'facebook':
        return Icons.thumb_up;
      case 'instagram':
        return Icons.camera_alt;
      case 'github':
        return Icons.code;
      case 'website':
      case 'web':
        return Icons.language;
      case 'tiktok':
        return Icons.music_video;
      case 'youtube':
        return Icons.play_circle_filled;
      case 'snapchat':
        return Icons.chat_bubble;
      default:
        return Icons.link;
    }
  }
}

// Bottom sheet for NFC operation
class NFCOperationSheet extends StatelessWidget {
  final bool isRead;
  final String statusMessage;
  final VoidCallback onCancel;

  const NFCOperationSheet({
    Key? key,
    required this.isRead,
    required this.statusMessage,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRead ? 'Reading NFC Card...' : 'Writing to NFC Card...',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: NFCWavePainter(
                      color: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                  ),
                ),
                Icon(
                  Icons.contactless,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hold your device near the NFC card',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the card still until the operation completes',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CANCEL'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Custom painter for NFC waves animation
class NFCWavePainter extends CustomPainter {
  final Color color;
  
  NFCWavePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final center = Offset(size.width / 2, size.height / 2);
    
    for (int i = 1; i <= 3; i++) {
      final radius = 20.0 + (i * 10) + (sin((now * 2) + i) * 5);
      final opacity = 0.8 - (i * 0.2);
      
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}