import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late Razorpay _razorpay;

  // Callbacks
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;
  VoidCallback? _onPaymentStart;
  VoidCallback? _onPaymentComplete;

  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  // Amount validation method
  bool _isValidAmount(double amount) {
    return amount > 0 && amount <= 500000; // Max 5 lakh rupees
  }

  void startPayment({
    required double amount,
    required String productName,
    required String description,
    String? userEmail,
    String? userPhone,
    Function(PaymentSuccessResponse)? onPaymentSuccess,
    Function(PaymentFailureResponse)? onPaymentError,
    Function(ExternalWalletResponse)? onExternalWallet,
    VoidCallback? onPaymentStart,
    VoidCallback? onPaymentComplete,
  }) {
    // Add amount validation
    if (!_isValidAmount(amount)) {
      onPaymentError?.call(PaymentFailureResponse(
        3,
        'Invalid amount. Amount should be between ₹1 and ₹5,00,000',
        null,
      ));
      onPaymentComplete?.call();
      return;
    }

    // Store callbacks
    _onPaymentSuccess = onPaymentSuccess;
    _onPaymentError = onPaymentError;
    _onExternalWallet = onExternalWallet;
    _onPaymentStart = onPaymentStart;
    _onPaymentComplete = onPaymentComplete;

    // Call payment start callback
    _onPaymentStart?.call();

    var options = {
      'key': 'rzp_test_R7UPBngujLJbvt', // Only key_id - FIXED SECURITY ISSUE
      'amount': (amount * 100).toInt(), // Amount in paise (multiply by 100)
      'name': 'Bharghavi Store',
      'description': description,
      'prefill': {
        'contact': userPhone ?? '9876543210',
        'email': userEmail ?? 'customer@example.com'
      },
      'theme': {
        'color': '#4A7C59' // Your app theme color
      },
      'currency': 'INR', // Add currency
      'payment_capture': 1, // Auto capture
    };

    try {
      print('Opening Razorpay with amount: ₹$amount');
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      String errorMessage = 'Failed to open payment gateway';
      if (e.toString().contains('key')) {
        errorMessage = 'Invalid payment configuration';
      }
      _onPaymentError?.call(PaymentFailureResponse(
        1, // Error code
        errorMessage,
        null,
      ));
      _onPaymentComplete?.call();
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId ?? 'unknown';
    print('Payment Success: $paymentId');
    if (paymentId != 'unknown') {
      _onPaymentSuccess?.call(response);
    } else {
      _onPaymentError?.call(PaymentFailureResponse(
        2,
        'Payment ID not received',
        null,
      ));
    }
    _onPaymentComplete?.call();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    _onPaymentError?.call(response);
    _onPaymentComplete?.call();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }
}

// Mixin to be used with your StatefulWidgets
mixin PaymentMixin<T extends StatefulWidget> on State<T> {
  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _paymentService.initialize();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void startPayment({
    required double amount,
    required String productName,
    required String description,
    String? userEmail,
    String? userPhone,
    VoidCallback? onPaymentStart,
    Function(String paymentId)? onPaymentSuccess,
    Function(String error)? onPaymentError,
    VoidCallback? onPaymentComplete,
  }) {
    _paymentService.startPayment(
      amount: amount,
      productName: productName,
      description: description,
      userEmail: userEmail,
      userPhone: userPhone,
      onPaymentStart: onPaymentStart,
      onPaymentSuccess: (response) {
        onPaymentSuccess?.call(response.paymentId ?? '');
      },
      onPaymentError: (response) {
        onPaymentError?.call(response.message ?? 'Payment failed');
      },
      onPaymentComplete: onPaymentComplete,
    );
  }

  void showPaymentSuccess(String paymentId) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment Successful! Payment ID: $paymentId',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showPaymentError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment Failed: $error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}