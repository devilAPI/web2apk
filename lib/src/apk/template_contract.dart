/// Constants shared between the template APK and the patcher.
const kTemplatePackage = 'de.devilapi.web2apk.template';
const kTemplateLabel = 'WEB2APK_TEMPLATE_LABEL';
const kConfigPath = 'assets/config.json';
const kManifestPath = 'AndroidManifest.xml';
final kIconPath = RegExp(
  r'^res/mipmap-(mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)(-v4)?/ic_launcher\.png$',
);
const kIconSizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};
