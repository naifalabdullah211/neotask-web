import {execFileSync} from 'node:child_process';
import fs from 'node:fs';

const files = execFileSync(
    'git',
    ['ls-files', '-co', '--exclude-standard'],
    {encoding: 'utf8'},
).trim().split('\n').filter(Boolean);

const generatedOrPublicFirebaseConfig = new Set([
  'android/app/google-services.json',
  'ios/Runner/GoogleService-Info.plist',
  'lib/firebase_options.dart',
  'web/index.html',
  'web/firebase-messaging-sw.js',
]);

const sourceExtension = /\.(dart|js|json|ya?ml|html)$/i;
const secretChecks = [
  ['private key material', /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/],
  ['service-account private key', /["']private_key["']\s*:/],
  ['OpenAI-style secret', /\bsk-[A-Za-z0-9_-]{20,}\b/],
  ['hard-coded setup key', /\b(?:_?setupKey|managerSetupKey)\s*=\s*["'][^"']{6,}["']/],
  ['hard-coded server secret', /\b(?:apiSecret|clientSecret|serviceAccountKey|privateKey)\s*[:=]\s*["'][^"']{8,}["']/i],
];

const failures = [];
for (const file of files) {
  if (!sourceExtension.test(file) || file.endsWith('package-lock.json') ||
      file === 'scripts/security_check.js' ||
      file.startsWith('web/firebase-sdk/')) {
    continue;
  }
  const content = fs.readFileSync(file, 'utf8');
  for (const [label, pattern] of secretChecks) {
    if (pattern.test(content)) failures.push(`${file}: ${label}`);
  }
  if (!generatedOrPublicFirebaseConfig.has(file) &&
      /\bAIza[0-9A-Za-z_-]{30,}\b/.test(content)) {
    failures.push(`${file}: Firebase client key outside the approved config files`);
  }
}

const executableMarkupSinks = [
  ['lib', /\b(?:HtmlElementView|setInnerHtml|innerHtml)\b/],
  ['pubspec.yaml', /\b(?:flutter_html|webview_flutter)\b/],
  ['web/index.html', /\b(?:innerHTML|outerHTML|insertAdjacentHTML|document\.write)\b/],
];
for (const [target, pattern] of executableMarkupSinks) {
  const targets = files.filter((file) =>
    target === 'lib' ? file.startsWith('lib/') : file === target,
  );
  for (const file of targets) {
    if (pattern.test(fs.readFileSync(file, 'utf8'))) {
      failures.push(`${file}: executable HTML sink requires security review`);
    }
  }
}

if (failures.length) {
  console.error('Security regression check failed:\n' + failures.join('\n'));
  process.exit(1);
}

console.log('Security regression check passed: no embedded server secrets or executable HTML sinks.');
