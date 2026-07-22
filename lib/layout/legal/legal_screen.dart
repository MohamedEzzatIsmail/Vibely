import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalType.terms;
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).surface,
        title: Text(isTerms ? s.termsOfService : s.privacyPolicy,
          style: TextStyle(color: AppColors.of(context).text, fontSize: 17, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.of(context).isDark ? Colors.white : const Color(0xFFe5c687)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isTerms ? _TermsContent(s: s) : _PrivacyContent(s: s),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  final AppStrings s;
  const _TermsContent({required this.s});
  @override
  Widget build(BuildContext context) => _LegalBody(
    lastUpdated: 'July 11, 2026',
    lastUpdatedLabel: s.lastUpdated,
    sections: [
      _Section(s.termsSection1Title, s.termsSection1Body),
      _Section(s.termsSection2Title, s.termsSection2Body),
      _Section(s.termsSection3Title, s.termsSection3Body),
      _Section(s.termsSection4Title, s.termsSection4Body),
      _Section(s.termsSection5Title, s.termsSection5Body),
      _Section(s.termsSection6Title, s.termsSection6Body),
      _Section(s.termsSection7Title, s.termsSection7Body),
      _Section(s.termsSection8Title, s.termsSection8Body),
      _Section(s.termsSection9Title, s.termsSection9Body),
    ],
  );
}

class _PrivacyContent extends StatelessWidget {
  final AppStrings s;
  const _PrivacyContent({required this.s});
  @override
  Widget build(BuildContext context) => _LegalBody(
    lastUpdated: 'July 11, 2026',
    lastUpdatedLabel: s.lastUpdated,
    sections: [
      _Section(s.privacySection1Title, s.privacySection1Body),
      _Section(s.privacySection2Title, s.privacySection2Body),
      _Section(s.privacySection3Title, s.privacySection3Body),
      _Section(s.privacySection4Title, s.privacySection4Body),
      _Section(s.privacySection5Title, s.privacySection5Body),
      _Section(s.privacySection6Title, s.privacySection6Body),
      _Section(s.privacySection7Title, s.privacySection7Body),
      _Section(s.privacySection8Title, s.privacySection8Body),
      _Section(s.privacySection9Title, s.privacySection9Body),
    ],
  );
}

class _LegalBody extends StatelessWidget {
  final String lastUpdated;
  final String lastUpdatedLabel;
  final List<_Section> sections;
  const _LegalBody({required this.lastUpdated, required this.lastUpdatedLabel, required this.sections});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$lastUpdatedLabel: $lastUpdated',
          style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
      const SizedBox(height: 20),
      ...sections.map((s) => _SectionWidget(section: s)),
      const SizedBox(height: 40),
    ],
  );
}

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(section.title, style: const TextStyle(color: Color(0xFFe5c687), fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(section.body, style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13, height: 1.6)),
    ]),
  );
}
