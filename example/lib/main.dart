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
      title: 'SwahiliNFC Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NFCHomePage(),
    );
  }
}

class NFCHomePage extends StatefulWidget {
  const NFCHomePage({Key? key}) : super(key: key);

  @override
  State<NFCHomePage> createState() => _NFCHomePageState();
}

class _NFCHomePageState extends State<NFCHomePage> {
  bool _isNfcAvailable = false;
  String _statusMessage = 'Checking NFC availability...';
  BusinessCardData? _lastScannedCard;
  double _activationProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    try {
      bool isAvailable = await SwahiliNFC.isAvailable();
      setState(() {
        _isNfcAvailable = isAvailable;
        _statusMessage = isAvailable
            ? 'NFC is available. Ready to scan.'
            : 'NFC is not available on this device.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking NFC: ${e.toString()}';
      });
    }
  }

  Future<void> _readTag() async {
    try {
      setState(() {
        _statusMessage = 'Place NFC card near device...';
      });

      BusinessCardData cardData = await SwahiliNFC.readTag();

      setState(() {
        _lastScannedCard = cardData;
        _statusMessage = 'Card read successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error reading card: ${e.toString()}';
      });
    }
  }

  Future<void> _writeTag() async {
    try {
      setState(() {
        _statusMessage = 'Place writable NFC card near device...';
      });

      // Create sample business card data for writing
      BusinessCardData newCardData = BusinessCardData(
        name: 'John Doe',
        company: 'SwahiliTech',
        position: 'Software Engineer',
        email: 'john@example.com',
        phone: '+25571234567',
        social: {
          'linkedin': 'johndoe',
          'twitter': '@johndoe',
        },
        custom: {
          'website': 'example.com',
        },
      );

      bool success = await SwahiliNFC.writeTag(
        data: newCardData,
        verifyAfterWrite: true,
      );

      setState(() {
        _statusMessage =
            success ? 'Card written successfully!' : 'Failed to write to card.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error writing card: ${e.toString()}';
      });
    }
  }

  void _startCardActivation() {
    try {
      // Create sample business card data
      BusinessCardData cardData = BusinessCardData(
        name: 'Jane Smith',
        company: 'SwahiliConnect',
        position: 'Product Manager',
        email: 'jane@example.com',
        phone: '+25579876543',
        social: {
          'linkedin': 'janesmith',
          'twitter': '@janesmith',
        },
      );

      // Configure security options
      SecurityOptions securityOptions = SecurityOptions(
        level: SecurityLevel.enhanced,
        password: '1234',
        expiry: DateTime.now().add(const Duration(days: 365)),
      );

      setState(() {
        _statusMessage = 'Starting card activation...';
        _activationProgress = 0.0;
      });

      // Start activation process
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
            _activationProgress = progress;
            _statusMessage =
                'Activation in progress: ${(progress * 100).toInt()}%';
          });
        },
        onActivationComplete: (cardId) {
          setState(() {
            _statusMessage = 'Card activated successfully! Card ID: $cardId';
            _activationProgress = 0.0;
          });
        },
        onError: (error) {
          setState(() {
            _statusMessage = 'Activation failed: ${error.message}';
            _activationProgress = 0.0;
          });
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting activation: ${e.toString()}';
        _activationProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SwahiliNFC Example'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'NFC Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isNfcAvailable ? Icons.check_circle : Icons.error,
                          color: _isNfcAvailable ? Colors.green : Colors.red,
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
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_activationProgress > 0 && _activationProgress < 1)
              Column(
                children: [
                  LinearProgressIndicator(value: _activationProgress),
                  const SizedBox(height: 16),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _isNfcAvailable ? _readTag : null,
              icon: const Icon(Icons.nfc),
              label: const Text('Read NFC Card'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isNfcAvailable ? _writeTag : null,
              icon: const Icon(Icons.edit),
              label: const Text('Write NFC Card'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isNfcAvailable ? _startCardActivation : null,
              icon: const Icon(Icons.add_circle),
              label: const Text('Activate New Card'),
            ),
            const SizedBox(height: 16),
            if (_lastScannedCard != null) ...[
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Scanned Card',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildCardInfoRow(
                          Icons.person, 'Name', _lastScannedCard!.name),
                      if (_lastScannedCard!.company != null)
                        _buildCardInfoRow(Icons.business, 'Company',
                            _lastScannedCard!.company!),
                      if (_lastScannedCard!.position != null)
                        _buildCardInfoRow(Icons.work, 'Position',
                            _lastScannedCard!.position!),
                      if (_lastScannedCard!.email != null)
                        _buildCardInfoRow(
                            Icons.email, 'Email', _lastScannedCard!.email!),
                      if (_lastScannedCard!.phone != null)
                        _buildCardInfoRow(
                            Icons.phone, 'Phone', _lastScannedCard!.phone!),
                      const SizedBox(height: 8),
                      const Divider(),
                      _buildCardInfoRow(
                          Icons.vpn_key, 'Card ID', _lastScannedCard!.cardId),
                      _buildCardInfoRow(
                        Icons.security,
                        'Security Level',
                        _lastScannedCard!.securityLevel
                            .toString()
                            .split('.')
                            .last,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
