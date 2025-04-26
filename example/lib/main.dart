import 'package:flutter/material.dart';
import 'package:swahili_nfc/swahili_nfc.dart';

void main() {
  // Enable NFC debugging
  SwahiliNFC.enableDebugLogging(true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwahiliNFC Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const NFCHomePage(),
    );
  }
}

class NFCHomePage extends StatefulWidget {
  const NFCHomePage({Key? key}) : super(key: key);

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
  
  // Write form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Check NFC availability when the app starts
    _checkNfcAvailability();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

  // Read data from an NFC tag
  Future<void> _readTag() async {
    if (_isOperationInProgress) return;
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place NFC card near device...';
      _rawNfcData = "Reading...";
    });
    
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
      
      setState(() {
        _lastScannedCard = cardData;
        _rawNfcData = rawData;
        _statusMessage = 'Card read successfully!';
        _isOperationInProgress = false;
        
        // Switch to the Read tab to show results
        _tabController.animateTo(1);
      });
      
      _showSuccessSnackBar('Card read successfully');
    } catch (e) {
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

  // Write basic card data to an NFC tag
  Future<void> _writeBasicCard() async {
    if (!_formKey.currentState!.validate() || _isOperationInProgress) {
      return;
    }
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place writable NFC card near device...';
    });
    
    try {
      // Create business card data with minimal fields for reliability
      final cardData = BusinessCardData(
        name: _nameController.text.trim(),
        company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        position: _positionController.text.trim().isNotEmpty ? _positionController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );
      
      // Write to tag with verification
      final success = await SwahiliNFC.writeTag(
        data: cardData,
        verifyAfterWrite: true,
      );
      
      setState(() {
        _statusMessage = success 
            ? 'Card written successfully!' 
            : 'Failed to write to card.';
        _isOperationInProgress = false;
      });
      
      if (success) {
        _showSuccessSnackBar('Card written successfully');
      } else {
        _showErrorSnackBar('Failed to write to card');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error writing card: ${e.toString()}';
        _isOperationInProgress = false;
      });
      
      if (e is NFCError) {
        _showErrorDialog('NFC Write Error', e);
      } else {
        _showErrorSnackBar('Failed to write to NFC card: ${e.toString()}');
      }
    }
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
        title: Text(title),
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SwahiliNFC Demo'),
        backgroundColor: theme.colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
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
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Basic information card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Name Field (Required)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Company Field
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Position Field
                  TextFormField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
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
                  Text(
                    'Contact Information',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
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
                  const SizedBox(height: 12),
                  
                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
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
                  ? _writeBasicCard 
                  : null,
              icon: const Icon(Icons.nfc),
              label: const Text('WRITE TO NFC CARD', style: TextStyle(fontSize: 16)),
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
              icon: const Icon(Icons.nfc),
              label: const Text('READ NFC CARD', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Debug Raw NFC Data
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raw NFC Data (Debug)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Text(
                        _rawNfcData,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Last scanned card display
          if (_lastScannedCard != null)
            Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contactless, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Scanned Card',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Personal Information Section
                    _buildSectionTitle('Personal Information', Icons.person, theme),
                    _buildCardInfoRow(Icons.person, 'Name', _lastScannedCard!.name),
                    if (_lastScannedCard!.company != null)
                      _buildCardInfoRow(Icons.business, 'Company', _lastScannedCard!.company!),
                    if (_lastScannedCard!.position != null)
                      _buildCardInfoRow(Icons.work, 'Position', _lastScannedCard!.position!),
                    
                    const SizedBox(height: 12),
                    
                    // Contact Information Section
                    _buildSectionTitle('Contact Information', Icons.contact_mail, theme),
                    if (_lastScannedCard!.email != null)
                      _buildCardInfoRow(Icons.email, 'Email', _lastScannedCard!.email!),
                    if (_lastScannedCard!.phone != null)
                      _buildCardInfoRow(Icons.phone, 'Phone', _lastScannedCard!.phone!),
                    
                    // Social Media Section
                    if (_lastScannedCard!.social.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle('Social Media', Icons.share, theme),
                      ..._lastScannedCard!.social.entries.map((entry) => 
                        _buildCardInfoRow(
                          _getSocialIcon(entry.key), 
                          entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1),
                          entry.value,
                        ),
                      ),
                    ],
                    
                    // Custom Fields Section
                    if (_lastScannedCard!.custom.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle('Additional Information', Icons.more_horiz, theme),
                      ..._lastScannedCard!.custom.entries.map((entry) => 
                        _buildCardInfoRow(
                          Icons.label_outline,
                          entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1),
                          entry.value,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // Card Metadata Section
                    _buildSectionTitle('Card Details', Icons.info_outline, theme),
                    _buildCardInfoRow(Icons.vpn_key, 'Card ID', _lastScannedCard!.cardId),
                    _buildCardInfoRow(
                      Icons.security,
                      'Security Level',
                      _lastScannedCard!.securityLevel.toString().split('.').last.substring(0, 1).toUpperCase() +
                      _lastScannedCard!.securityLevel.toString().split('.').last.substring(1),
                    ),
                    _buildCardInfoRow(
                      Icons.calendar_today,
                      'Created',
                      _formatDate(_lastScannedCard!.createdAt),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
            ),
        ],
      ),
    );
  }
  
  // Status Tab UI
  Widget _buildStatusTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _checkNfcAvailability,
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
                      _isNfcAvailable ? Icons.nfc : Icons.nfc,
                      size: 64,
                      color: _isNfcAvailable ? theme.colorScheme.primary : Colors.red,
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
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isNfcAvailable ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isNfcAvailable ? Icons.check_circle : Icons.error,
                            color: _isNfcAvailable ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isNfcAvailable ? 'Available' : 'Not Available',
                            style: TextStyle(
                              color: _isNfcAvailable ? Colors.green : Colors.red,
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
                    TextButton.icon(
                      onPressed: _checkNfcAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh NFC Status'),
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
                    Text(
                      'Troubleshooting',
                      style: theme.textTheme.titleLarge,
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
                      'Make sure your NFC tag is writable and not locked. Try writing with minimal data first (just name and email).',
                    ),
                    const SizedBox(height: 12),
                    _buildTroubleshootingTip(
                      theme,
                      'Testing with Simple Data',
                      'When testing NFC, start with just basic fields. This app has been configured to use a simplified approach for better compatibility.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to build section titles
  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            icon, 
            size: 18, 
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build card info rows
  Widget _buildCardInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
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
          color: theme.colorScheme.primary,
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
                  color: theme.colorScheme.primary,
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
      default:
        return Icons.link;
    }
  }
  
  // Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 2) {
      return 'Yesterday at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }
}