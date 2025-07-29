import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

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
          'Privacy Policy',
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
              Text(
                'Bhargavi Enterprises Application\nEffective Date: 13-5-2025\n',
                style: TextStyle(fontSize: 14),
              ),
              SectionTitle('1. Introduction'),
              ParagraphText(
                  'Bhargavi Enterprises ("Company", "we", "us", or "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use the Bhargavi Enterprises Application ("Bhargavi Enterprises").'),

              SizedBox(height: 12),
              SectionTitle('2. Information We Collect'),
              ParagraphText('We may collect and process the following types of information:'),
              BulletText('Personal Information: Name, email address, phone number, mailing address, and other contact details.'),
              BulletText('Usage Data: IP address, device information, browser type, operating system, and app usage statistics.'),
              BulletText('Location Data: If permitted, we may collect your geographic location for relevant services.'),
              BulletText('Transaction Information: If applicable, payment details for orders.'),
              BulletText('Third-Party Information: Data obtained from third-party integrations or linked accounts.'),

              SizedBox(height: 12),
              SectionTitle('3. How We Use Your Information'),
              ParagraphText('We use the collected data to:'),
              BulletText('Provide and operate the Application.'),
              BulletText('Personalize user experiences.'),
              BulletText('Process transactions and manage orders.'),
              BulletText('Send updates, promotional materials, and customer support responses.'),
              BulletText('Ensure fraud detection, prevention, and compliance with legal obligations.'),

              SizedBox(height: 12),
              SectionTitle('4. Sharing Your Information'),
              ParagraphText('We may share information with:'),
              BulletText('Service Providers: Third-party vendors assisting in Application functionality.'),
              BulletText('Legal Authorities: When required by law or to protect our rights.'),
              BulletText('Business Transfers: In case of merger, sale, or acquisition.'),

              SizedBox(height: 12),
              SectionTitle('5. Data Security'),
              ParagraphText(
                  'We implement industry-standard security measures to protect your data. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.'),
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
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    );
  }
}

class ParagraphText extends StatelessWidget {
  final String text;
  const ParagraphText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.5),
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
      padding: const EdgeInsets.only(top: 4),
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
