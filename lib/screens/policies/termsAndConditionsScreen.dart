import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFE4F5DE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('General Terms'),
              BulletText('Bhargavi Oil reserves the right to modify or update these Terms at any time without prior notice.'),
              BulletText('Users must be at least 18 years old to place orders.'),
              BulletText('By using this website, you agree to comply with all applicable local, state, and federal laws.'),

              SizedBox(height: 16),
              SectionTitle('Shipping and Return Policy'),
              NumberedText(1, 'If a cancellation request is received before the order is processed/approved, we will cancel the order and refund the full amount.'),
              NumberedText(2, 'A ₹50 deduction will be applied for cancellations or returns of orders that have left the shipping warehouse.'),
              NumberedText(3, 'In case of any damage, we require customers to record an unboxing video of the received order in case any discrepancies arise. This will help us address any issues effectively and provide suitable solutions.'),

              SizedBox(height: 16),
              SectionTitle('5. Bulk Order Information'),
              BulletText('For bulk orders, retailing, or corporate gifting, contact us at 9566230018.'),
              BulletText('A 4% to 8% discount will be offered for bulk orders, corporate gifting, and retailing.'),
              BulletText('Full payment is required before order processing.'),

              SizedBox(height: 16),
              SectionTitle('6. Product Quality and Disclaimer'),
              BulletText('We ensure our products meet high-quality standards, but results may vary from person to person.'),
              BulletText('Bhargavi Oil is not responsible for any adverse reactions caused by product usage.'),
              BulletText('Customers should read ingredient lists carefully before use, especially if they have allergies.'),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }
}

class BulletText extends StatelessWidget {
  final String text;

  const BulletText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class NumberedText extends StatelessWidget {
  final int number;
  final String text;

  const NumberedText(this.number, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ', style: const TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
