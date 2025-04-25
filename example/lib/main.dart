import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swahili_nfc/swahili_nfc.dart';

void main() {
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
  
  // Write form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Social media fields
  final List<Map<String, TextEditingController>> _socialFields = [
    {'platform': TextEditingController(), 'value': TextEditingController()}
  ];
  
  // Custom fields
  final List<Map<String, TextEditingController>> _customFields = [
    {'key': TextEditingController(), 'value': TextEditingController()}
  ];
  
  // Security level selection
  SecurityLevel _securityLevel = SecurityLevel.open;
  
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
    _passwordController.dispose();
    
    for (var field in _socialFields) {
      field['platform']!.dispose();
      field['value']!.dispose();
    }
    
    for (var field in _customFields) {
      field['key']!.dispose();
      field['value']!.dispose();
    }
    
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
    });
    
    try {
      // Call the SwahiliNFC API to read a tag
      final cardData = await SwahiliNFC.readTag();
      
      setState(() {
        _lastScannedCard = cardData;
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

  // Write form data to an NFC tag
  Future<void> _writeCustomTag() async {
    if (!_formKey.currentState!.validate() || _isOperationInProgress) {
      return;
    }
    
    setState(() {
      _isOperationInProgress = true;
      _statusMessage = 'Place writable NFC card near device...';
    });
    
    try {
      // Build social media map
      final social = <String, String>{};
      for (var field in _socialFields) {
        final platform = field['platform']!.text.trim();
        final value = field['value']!.text.trim();
        if (platform.isNotEmpty && value.isNotEmpty) {
          social[platform.toLowerCase()] = value;
        }
      }
      
      // Build custom fields map
      final custom = <String, String>{};
      for (var field in _customFields) {
        final key = field['key']!.text.trim();
        final value = field['value']!.text.trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          custom[key.toLowerCase()] = value;
        }
      }
      
      // Create business card data
      final cardData = BusinessCardData(
        name: _nameController.text.trim(),
        company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        position: _positionController.text.trim().isNotEmpty ? _positionController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        social: social,
        custom: custom,
        securityLevel: _securityLevel,
      );
      
      bool success;
      
      // Check if we need to handle security
      if (_securityLevel != SecurityLevel.open && _passwordController.text.isNotEmpty) {
        // For secure cards, use the card activation flow
        final securityOptions = SecurityOptions(
          level: _securityLevel,
          password: _passwordController.text,
          expiry: DateTime.now().add(const Duration(days: 365)),
        );
        
        // Create a completer to handle the async result
        final completer = Completer<bool>();
        
        // Start activation with security
        SwahiliNFC.startCardActivation(
          cardData: cardData,
          security: securityOptions,
          deviceType: NFCDeviceType.card,
          onActivationStarted: () {
            setState(() {
              _statusMessage = 'Please hold your card near the device';
            });
          },
          onProgress: (progress) {
            setState(() {
              _statusMessage = 'Writing in progress: ${(progress * 100).toInt()}%';
            });
          },
          onActivationComplete: (cardId) {
            completer.complete(true);
          },
          onError: (error) {
            completer.completeError(error);
          },
        );
        
        // Wait for the result
        success = await completer.future;
        
      } else {
        // For open cards, use the direct write method
        success = await SwahiliNFC.writeTag(
          data: cardData,
          verifyAfterWrite: true,
        );
      }
      
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

  // Add a new social media field
  void _addSocialField() {
    setState(() {
      _socialFields.add({
        'platform': TextEditingController(),
        'value': TextEditingController()
      });
    });
  }

  // Remove a social media field
  void _removeSocialField(int index) {
    if (_socialFields.length > 1) {
      setState(() {
        _socialFields[index]['platform']!.dispose();
        _socialFields[index]['value']!.dispose();
        _socialFields.removeAt(index);
      });
    }
  }

  // Add a new custom field
  void _addCustomField() {
    setState(() {
      _customFields.add({
        'key': TextEditingController(),
        'value': TextEditingController()
      });
    });
  }

  // Remove a custom field
  void _removeCustomField(int index) {
    if (_customFields.length > 1) {
      setState(() {
        _customFields[index]['key']!.dispose();
        _customFields[index]['value']!.dispose();
        _customFields.removeAt(index);
      });
    }
  }

  // Show a success SnackBar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 3),
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
          
          // Social media card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Social Media',
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _addSocialField,
                        tooltip: 'Add social media',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Dynamic social media fields
                  ..._socialFields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final field = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Platform field
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: field['platform'],
                              decoration: const InputDecoration(
                                labelText: 'Platform',
                                border: OutlineInputBorder(),
                                hintText: 'LinkedIn',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Value field
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: field['value'],
                              decoration: const InputDecoration(
                                labelText: 'Value',
                                border: OutlineInputBorder(),
                                hintText: 'username',
                              ),
                            ),
                          ),
                          
                          // Remove button
                          if (_socialFields.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeSocialField(index),
                              tooltip: 'Remove',
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          
          // Custom fields card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Fields',
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _addCustomField,
                        tooltip: 'Add custom field',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Dynamic custom fields
                  ..._customFields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final field = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Key field
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: field['key'],
                              decoration: const InputDecoration(
                                labelText: 'Field Name',
                                border: OutlineInputBorder(),
                                hintText: 'Website',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Value field
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: field['value'],
                              decoration: const InputDecoration(
                                labelText: 'Value',
                                border: OutlineInputBorder(),
                                hintText: 'example.com',
                              ),
                            ),
                          ),
                          
                          // Remove button
                          if (_customFields.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeCustomField(index),
                              tooltip: 'Remove',
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          
          // Security settings card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Settings',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  
                  // Security level dropdown
                  DropdownButtonFormField<SecurityLevel>(
                    decoration: const InputDecoration(
                      labelText: 'Security Level',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    value: _securityLevel,
                    items: SecurityLevel.values.map((level) {
                      String levelName = level.toString().split('.').last;
                      levelName = levelName[0].toUpperCase() + levelName.substring(1);
                      
                      return DropdownMenuItem<SecurityLevel>(
                        value: level,
                        child: Text(levelName),
                      );
                    }).toList(),
                    onChanged: (SecurityLevel? value) {
                      if (value != null) {
                        setState(() {
                          _securityLevel = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Show password field for higher security levels
                  if (_securityLevel != SecurityLevel.open)
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Security Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.password),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (_securityLevel != SecurityLevel.open && 
                            (value == null || value.trim().isEmpty)) {
                          return 'Password is required for secure cards';
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
                  ? _writeCustomTag 
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
                  ],
                ),
              ),
            ),
            
            // Info card
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About NFC',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      theme,
                      'What is NFC?',
                      'Near Field Communication is a short-range wireless technology that enables communication between devices.',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      theme,
                      'How to Use',
                      'Hold your NFC-enabled device close to an NFC tag or card. The optimal distance is around 4cm (1.5 inches).',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      theme,
                      'Security Levels',
                      'This app supports multiple security levels for NFC cards, from open access to premium security with encryption.',
                    ),
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
                      'Make sure your NFC tag is writable and not locked. Some tags come pre-locked and cannot be written to.',
                    ),
                  ],
                ),
              ),
            ),
            
            // App info
            Card(
              elevation: 1,
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'SwahiliNFC Demo App',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh NFC status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
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
  
  // Helper to build info rows
  Widget _buildInfoRow(ThemeData theme, String title, String description) {
    return Column(
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