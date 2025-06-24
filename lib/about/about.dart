import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
    lookupVersionNumber();
  }

  final versionNotifier = ValueNotifier<String>('');

  Future<void> lookupVersionNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    versionNotifier.value = packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.about)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 10, width: double.infinity),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppLocalizations.of(context)!.appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: versionNotifier,
                builder: (context, version, child) {
                  return Text(version);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://globalbibletools.com');
                    if (await canLaunchUrl(url)) {
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('GlobalBibleTools.com'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://github.com/globalbibletools/study-app',
                    );
                    if (await canLaunchUrl(url)) {
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.sourceCode),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: 'contact@ethnos.dev'),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email copied to clipboard'),
                      ),
                    );
                  },
                  child: const Text('contact@ethnos.dev'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
