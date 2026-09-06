import 'package:flutter/material.dart';
import 'login_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Us',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Speech Emotion Detection',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // App Description
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('About the App'),
                  const SizedBox(height: 10),
                  _buildParagraph(
                    'Speech Emotion Detection is an innovative application that uses advanced machine learning algorithms to detect emotions from your voice recordings. This app analyzes speech patterns, tone variations, and vocal characteristics to identify the emotional state of the speaker.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('How It Works'),
                  const SizedBox(height: 10),
                  _buildParagraph(
                    'When you record your voice, our app processes the audio using specialized neural networks trained on thousands of emotional speech samples. The analysis identifies patterns associated with different emotions and provides a breakdown of the detected emotional states.',
                  ),
                  const SizedBox(height: 10),

                  _buildFeatureList([
                    'Record voice samples of any duration',
                    'Analyze emotional content in real-time',
                    'View detailed emotion breakdowns',
                    'Track emotional patterns over time',
                    'Save and revisit previous recordings',
                  ]),
                  const SizedBox(height: 20),

                  _buildSectionTitle('Privacy'),
                  const SizedBox(height: 10),
                  _buildParagraph(
                    'We value your privacy. All voice processing happens locally on your device or through our secure server. Your recordings are never shared with third parties without your explicit consent.',
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('Contact Us'),
                  const SizedBox(height: 10),
                  _buildContactInfo(
                    'Email',
                    'support@speechemotiondetection.app',
                    Icons.email_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildContactInfo(
                    'Website',
                    'www.speechemotiondetection.app',
                    Icons.language_outlined,
                  ),
                  const SizedBox(height: 40),

                  // Copyright
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} Speech Emotion Detection',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
      ),
    );
  }

  Widget _buildFeatureList(List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContactInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
