// Lightweight FR / AR localization for the livestock app.
//
// How it works
// ------------
// * The English texts written in the code are used as keys.
// * `Text` below shadows Flutter's `Text` widget: it looks the string up in
//   [_strings] and shows the French or Arabic version. Strings that are not
//   in the dictionary (usernames, tracker ids, chat messages...) are shown
//   unchanged.
// * Use `Text.raw(...)` when a text must NEVER be translated (chat messages).
// * Use `trf('Hello {name}', {'name': x})` for texts that contain values.
// * Use `tr('...')` for plain String parameters (labelText, tooltip, ...).
//
// To add a new text: add one line in [_strings]: 'English': ['Français', 'العربية'].

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Current language (saved on the phone)
// ---------------------------------------------------------------------------

class AppLocale extends ChangeNotifier {
  static const String _prefsKey = 'app_language';

  String _code = 'fr';

  String get code => _code;
  Locale get locale => Locale(_code);
  bool get isArabic => _code == 'ar';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'fr' || saved == 'ar') {
        _code = saved!;
      }
    } catch (_) {
      // Keep the default language if storage is unavailable.
    }
  }

  Future<void> setLanguage(String newCode) async {
    if (newCode != 'fr' && newCode != 'ar') return;
    if (newCode == _code) return;

    _code = newCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newCode);
    } catch (_) {
      // Not critical: the language just will not be remembered.
    }
  }
}

final AppLocale appLocale = AppLocale();

// ---------------------------------------------------------------------------
// Translation helpers
// ---------------------------------------------------------------------------

/// Translates [text] (an English key) to the current language.
String tr(String text) {
  final entry = _strings[text];
  if (entry != null) {
    return appLocale.isArabic ? entry[1] : entry[0];
  }

  final server = _translateServerMessage(text);
  return server ?? text;
}

/// Translates a template such as 'Expires: {date}' and fills in the values.
String trf(String template, Map<String, Object?> args) {
  var out = tr(template);
  args.forEach((key, value) {
    out = out.replaceAll('{$key}', '${value ?? ''}');
  });
  return out;
}

/// Drop-in replacement for Flutter's [Text] that translates its content.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : translate = true;

  /// Same as [Text] but the content is shown exactly as given.
  const Text.raw(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : translate = false;

  final String data;
  final bool translate;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return material.Text(
      translate ? tr(data) : data,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Language button (Français / العربية) to place in an AppBar or top bar.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, this.color});

  final Color? color;

  PopupMenuItem<String> _item(String code, String label) {
    final selected = appLocale.code == code;
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.language,
            size: 18,
            color: selected ? const Color(0xFF3867D6) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text.raw(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tr('Language'),
      icon: Icon(Icons.language, color: color),
      onSelected: (code) => appLocale.setLanguage(code),
      itemBuilder: (context) => [
        _item('fr', 'Français'),
        _item('ar', 'العربية'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alerts created by the Django backend are written in English.
// They are translated here with patterns.
// ---------------------------------------------------------------------------

String? _translateServerMessage(String text) {
  final ar = appLocale.isArabic;

  final failed = RegExp(r'^Request failed \((\d+)\)\.$').firstMatch(text);
  if (failed != null) {
    return ar
        ? 'فشل الطلب (${failed.group(1)}).'
        : 'La requête a échoué (${failed.group(1)}).';
  }

  if (!text.startsWith('Cow ') && !text.startsWith('Tracker ')) return null;

  var m = RegExp(
    r'^Cow (.+) has escaped the pasture! Distance: (.+)m from center\.$',
  ).firstMatch(text);
  if (m != null) {
    return ar
        ? 'البقرة ${m.group(1)} غادرت المرعى! المسافة: ${m.group(2)} م عن المركز.'
        : 'La vache ${m.group(1)} a quitté le pâturage ! '
            'Distance : ${m.group(2)} m du centre.';
  }

  m = RegExp(
    r'^Cow (.+) is rushing frantically! Speed: (.+) km/h, Activity: (.+)\.$',
  ).firstMatch(text);
  if (m != null) {
    return ar
        ? 'البقرة ${m.group(1)} تركض بشكل هستيري! السرعة: ${m.group(2)} كم/س، النشاط: ${m.group(3)}.'
        : 'La vache ${m.group(1)} court de façon frénétique ! '
            'Vitesse : ${m.group(2)} km/h, activité : ${m.group(3)}.';
  }

  m = RegExp(
    r'^Cow (.+) has stopped moving completely \(possible injury/illness\)\.$',
  ).firstMatch(text);
  if (m != null) {
    return ar
        ? 'البقرة ${m.group(1)} توقفت عن الحركة تمامًا (إصابة أو مرض محتمل).'
        : 'La vache ${m.group(1)} ne bouge plus du tout '
            '(blessure ou maladie possible).';
  }

  m = RegExp(
    r'^Tracker (.+) battery is low \((.+)%\)\.$',
  ).firstMatch(text);
  if (m != null) {
    return ar
        ? 'بطارية المتتبع ${m.group(1)} منخفضة (${m.group(2)}%).'
        : 'La batterie du traceur ${m.group(1)} est faible (${m.group(2)} %).';
  }

  return null;
}

// ---------------------------------------------------------------------------
// Dictionary: 'English': ['Français', 'العربية']
// ---------------------------------------------------------------------------

const Map<String, List<String>> _strings = {
  // --- Common ---
  'Language': ['Langue', 'اللغة'],
  'Retry': ['Réessayer', 'إعادة المحاولة'],
  'Cancel': ['Annuler', 'إلغاء'],
  'Done': ['Terminé', 'تم'],
  'Refresh': ['Actualiser', 'تحديث'],
  'Unknown': ['Inconnu', 'غير معروف'],
  'Never': ['Jamais', 'أبدًا'],
  'N/A': ['N/D', 'غير متاح'],
  'ACTIVE': ['ACTIF', 'نشط'],
  'DISABLED': ['DÉSACTIVÉ', 'معطّل'],
  'OWNER': ['PROPRIÉTAIRE', 'المالك'],
  'SHEPHERD': ['BERGER', 'الراعي'],
  '{v} km/h': ['{v} km/h', '{v} كم/س'],

  // --- Login ---
  'Enter your username and password.': [
    'Saisissez votre nom d\'utilisateur et votre mot de passe.',
    'أدخل اسم المستخدم وكلمة المرور.'
  ],
  'LIVESTOCK MONITOR': ['SUIVI DU BÉTAIL', 'مراقبة المواشي'],
  'Sign in to your farm account': [
    'Connectez-vous à votre compte de ferme',
    'سجّل الدخول إلى حساب مزرعتك'
  ],
  'Username': ['Nom d\'utilisateur', 'اسم المستخدم'],
  'Password': ['Mot de passe', 'كلمة المرور'],
  'SIGN IN': ['SE CONNECTER', 'تسجيل الدخول'],
  'JOIN A FARM': ['REJOINDRE UNE FERME', 'الانضمام إلى مزرعة'],
  'No active account found with the given credentials': [
    'Aucun compte actif trouvé avec ces identifiants',
    'لا يوجد حساب نشط بهذه البيانات'
  ],

  // --- Navigation / top bar ---
  'Overview': ['Aperçu', 'نظرة عامة'],
  'Map': ['Carte', 'الخريطة'],
  'Alerts': ['Alertes', 'التنبيهات'],
  'Chats': ['Discussions', 'المحادثات'],
  'Shepherds': ['Bergers', 'الرعاة'],
  'OVERVIEW': ['APERÇU', 'نظرة عامة'],
  'LIVESTOCK / OVERVIEW': ['BÉTAIL / APERÇU', 'المواشي / نظرة عامة'],
  'MAP': ['CARTE', 'الخريطة'],
  'LIVESTOCK / MAP': ['BÉTAIL / CARTE', 'المواشي / الخريطة'],
  'ALERTS': ['ALERTES', 'التنبيهات'],
  'LIVESTOCK / ALERTS': ['BÉTAIL / ALERTES', 'المواشي / التنبيهات'],
  'CHATS': ['DISCUSSIONS', 'المحادثات'],
  'LIVESTOCK / CHATS': ['BÉTAIL / DISCUSSIONS', 'المواشي / المحادثات'],
  'SHEPHERDS': ['BERGERS', 'الرعاة'],
  'LIVESTOCK / SHEPHERDS': ['BÉTAIL / BERGERS', 'المواشي / الرعاة'],
  'LOCATION ON': ['POSITION ACTIVÉE', 'الموقع مفعّل'],
  'LOCATION OFF': ['POSITION DÉSACTIVÉE', 'الموقع متوقف'],
  'API CONNECTED': ['API CONNECTÉE', 'الخادم متصل'],
  'API DISCONNECTED': ['API DÉCONNECTÉE', 'الخادم غير متصل'],
  'Refresh data': ['Actualiser les données', 'تحديث البيانات'],
  'Logout': ['Déconnexion', 'تسجيل الخروج'],

  // --- Overview ---
  'Farm Overview': ['Vue d\'ensemble de la ferme', 'نظرة عامة على المزرعة'],
  'Monitor your livestock, telemetry and AI-detected anomalies.': [
    'Surveillez votre bétail, la télémétrie et les anomalies détectées par l\'IA.',
    'راقب مواشيك والقياسات والحالات الشاذة التي يكشفها الذكاء الاصطناعي.'
  ],
  'Waiting for data': ['En attente de données', 'في انتظار البيانات'],
  'Last updated: {time}': [
    'Dernière mise à jour : {time}',
    'آخر تحديث: {time}'
  ],
  '5-second refresh interval': [
    'Actualisation toutes les 5 secondes',
    'التحديث كل 5 ثوانٍ'
  ],
  'TOTAL TRACKERS': ['TOTAL DES TRACEURS', 'إجمالي المتتبعات'],
  'Registered devices': ['Appareils enregistrés', 'الأجهزة المسجّلة'],
  'NORMAL': ['NORMAL', 'عادي'],
  'Normal predictions': ['Prédictions normales', 'التنبؤات العادية'],
  'ANOMALIES': ['ANOMALIES', 'الحالات الشاذة'],
  'Unusual readings': ['Mesures inhabituelles', 'قراءات غير معتادة'],
  'AI ENGINE': ['MOTEUR IA', 'محرك الذكاء الاصطناعي'],
  'Isolation Forest': ['Isolation Forest', 'Isolation Forest'],
  'Tracker Monitoring': ['Suivi des traceurs', 'مراقبة المتتبعات'],
  'Latest telemetry and anomaly predictions': [
    'Dernière télémétrie et prédictions d\'anomalies',
    'آخر القياسات وتنبؤات الحالات الشاذة'
  ],
  'MONITORING': ['SURVEILLANCE', 'قيد المراقبة'],
  'TRACKER': ['TRACEUR', 'المتتبع'],
  'SPEED': ['VITESSE', 'السرعة'],
  'ACTIVITY': ['ACTIVITÉ', 'النشاط'],
  'AI STATUS': ['STATUT IA', 'حالة الذكاء الاصطناعي'],
  'DECISION SCORE': ['SCORE DE DÉCISION', 'درجة القرار'],
  'ANOMALY': ['ANOMALIE', 'شاذ'],
  'Unable to load tracker data': [
    'Impossible de charger les données des traceurs',
    'تعذّر تحميل بيانات المتتبعات'
  ],
  'Unknown error': ['Erreur inconnue', 'خطأ غير معروف'],
  'Retry connection': ['Réessayer la connexion', 'إعادة محاولة الاتصال'],
  'AI Anomaly Detection': [
    'Détection d\'anomalies par IA',
    'كشف الحالات الشاذة بالذكاء الاصطناعي'
  ],
  'Tracker readings are analyzed using the Isolation Forest model. '
      'An anomaly indicates unusual data, not necessarily an emergency.': [
    'Les mesures des traceurs sont analysées avec le modèle Isolation Forest. '
        'Une anomalie signale des données inhabituelles, pas forcément une urgence.',
    'تُحلَّل قراءات المتتبعات باستخدام نموذج Isolation Forest. '
        'تشير الحالة الشاذة إلى بيانات غير معتادة وليست بالضرورة حالة طارئة.'
  ],
  'IoT Monitoring Platform': [
    'Plateforme de suivi IoT',
    'منصة المراقبة لإنترنت الأشياء'
  ],
  'LIVESTOCK': ['BÉTAIL', 'المواشي'],
  'MONITORING SYSTEM': ['SYSTÈME DE SUIVI', 'نظام المراقبة'],
  'WORKSPACE': ['ESPACE DE TRAVAIL', 'مساحة العمل'],
  'SYSTEM': ['SYSTÈME', 'النظام'],
  'Monitoring service': ['Service de surveillance', 'خدمة المراقبة'],
  'PROJECT VERSION 1.0': ['VERSION DU PROJET 1.0', 'إصدار المشروع 1.0'],
  'Speed': ['Vitesse', 'السرعة'],
  'Activity': ['Activité', 'النشاط'],
  'Latitude': ['Latitude', 'خط العرض'],
  'Longitude': ['Longitude', 'خط الطول'],
  'Decision score': ['Score de décision', 'درجة القرار'],
  'No tracker data available': [
    'Aucune donnée de traceur disponible',
    'لا توجد بيانات متتبعات'
  ],

  // --- Alerts ---
  'Monitoring events and livestock warnings': [
    'Événements de surveillance et avertissements sur le bétail',
    'أحداث المراقبة وتحذيرات المواشي'
  ],
  'Refresh alerts': ['Actualiser les alertes', 'تحديث التنبيهات'],
  'Try again': ['Réessayer', 'حاول مرة أخرى'],
  'No alerts yet': ['Aucune alerte pour le moment', 'لا توجد تنبيهات بعد'],
  'New monitoring alerts will appear here.': [
    'Les nouvelles alertes de surveillance apparaîtront ici.',
    'ستظهر تنبيهات المراقبة الجديدة هنا.'
  ],
  'Unexpected response from the server.': [
    'Réponse inattendue du serveur.',
    'استجابة غير متوقعة من الخادم.'
  ],
  'Date unavailable': ['Date indisponible', 'التاريخ غير متوفر'],
  'No details provided.': ['Aucun détail fourni.', 'لا توجد تفاصيل.'],
  'ALERT': ['ALERTE', 'تنبيه'],
  'INFO': ['INFO', 'معلومة'],
  'CRITICAL': ['CRITIQUE', 'حرج'],
  'WARNING': ['AVERTISSEMENT', 'تحذير'],
  'ESCAPE': ['FUITE', 'هروب'],
  'RUSH': ['COURSE', 'ركض'],
  'STILL': ['IMMOBILE', 'سكون'],
  'LOW BATTERY': ['BATTERIE FAIBLE', 'بطارية منخفضة'],

  // --- Chat ---
  'No contacts available yet.': [
    'Aucun contact disponible pour le moment.',
    'لا توجد جهات اتصال بعد.'
  ],
  'Write a message...': ['Écrire un message...', 'اكتب رسالة...'],

  // --- Invitation / activation ---
  'Scan Invitation': ['Scanner l\'invitation', 'مسح الدعوة'],
  'Point your camera at the invitation QR code.': [
    'Dirigez votre caméra vers le code QR de l\'invitation.',
    'وجّه الكاميرا نحو رمز QR الخاص بالدعوة.'
  ],
  'Please fill in both password fields.': [
    'Veuillez remplir les deux champs de mot de passe.',
    'يرجى ملء حقلي كلمة المرور.'
  ],
  'Passwords do not match.': [
    'Les mots de passe ne correspondent pas.',
    'كلمتا المرور غير متطابقتين.'
  ],
  'Account activated': ['Compte activé', 'تم تفعيل الحساب'],
  'Your account is ready. You can now sign in using '
      'the username provided by the farm owner and your new password.': [
    'Votre compte est prêt. Vous pouvez maintenant vous connecter avec '
        'le nom d\'utilisateur fourni par le propriétaire de la ferme et votre nouveau mot de passe.',
    'حسابك جاهز. يمكنك الآن تسجيل الدخول باستخدام '
        'اسم المستخدم الذي زوّدك به مالك المزرعة وكلمة المرور الجديدة.'
  ],
  'GO TO LOGIN': ['ALLER À LA CONNEXION', 'الذهاب إلى تسجيل الدخول'],
  'Activate Account': ['Activer le compte', 'تفعيل الحساب'],
  'Create your password': ['Créez votre mot de passe', 'أنشئ كلمة المرور'],
  'Choose a password for your shepherd account.': [
    'Choisissez un mot de passe pour votre compte de berger.',
    'اختر كلمة مرور لحساب الراعي الخاص بك.'
  ],
  'New password': ['Nouveau mot de passe', 'كلمة المرور الجديدة'],
  'Confirm password': ['Confirmer le mot de passe', 'تأكيد كلمة المرور'],
  'ACTIVATE ACCOUNT': ['ACTIVER LE COMPTE', 'تفعيل الحساب'],
  'Invitation activation failed.': [
    'Échec de l\'activation de l\'invitation.',
    'فشل تفعيل الدعوة.'
  ],

  // --- Map ---
  '{n} GPS points': ['{n} points GPS', '{n} نقطة GPS'],
  '{n} habitual zones detected': [
    '{n} zones habituelles détectées',
    'تم اكتشاف {n} مناطق معتادة'
  ],
  'MAP LEGEND': ['LÉGENDE DE LA CARTE', 'دليل الخريطة'],
  'Normal tracker': ['Traceur normal', 'متتبع عادي'],
  'Anomaly detected': ['Anomalie détectée', 'تم رصد حالة شاذة'],
  'Outside habitual zones': ['Hors des zones habituelles', 'خارج المناطق المعتادة'],
  'Habitual grazing zone': ['Zone de pâturage habituelle', 'منطقة الرعي المعتادة'],
  'Shepherd location': ['Position du berger', 'موقع الراعي'],
  'Zone circles are approximate 150m visuals.': [
    'Les cercles des zones sont des repères approximatifs de 150 m.',
    'دوائر المناطق تقريبية بنصف قطر 150 م.'
  ],
  'Grazing Zone': ['Zone de pâturage', 'منطقة رعي'],
  'Shepherd': ['Berger', 'الراعي'],

  // --- Shepherd management ---
  'Unexpected server response.': [
    'Réponse inattendue du serveur.',
    'استجابة غير متوقعة من الخادم.'
  ],
  'Add a shepherd': ['Ajouter un berger', 'إضافة راعٍ'],
  'Create an invitation for a new shepherd. '
      'They will choose their own password when '
      'activating their account.': [
    'Créez une invitation pour un nouveau berger. '
        'Il choisira son propre mot de passe lors de '
        'l\'activation de son compte.',
    'أنشئ دعوة لراعٍ جديد. '
        'سيختار كلمة المرور الخاصة به عند '
        'تفعيل حسابه.'
  ],
  'USERNAME': ['NOM D\'UTILISATEUR', 'اسم المستخدم'],
  'e.g. shepherd02': ['ex. berger02', 'مثال: shepherd02'],
  'Please enter a username.': [
    'Veuillez saisir un nom d\'utilisateur.',
    'يرجى إدخال اسم المستخدم.'
  ],
  'Create invitation': ['Créer l\'invitation', 'إنشاء دعوة'],
  'The server returned an invalid invitation response.': [
    'Le serveur a renvoyé une réponse d\'invitation invalide.',
    'أعاد الخادم استجابة دعوة غير صالحة.'
  ],
  'Could not create invitation: {error}': [
    'Impossible de créer l\'invitation : {error}',
    'تعذّر إنشاء الدعوة: {error}'
  ],
  'Invitation created': ['Invitation créée', 'تم إنشاء الدعوة'],
  'An invitation for "{username}" has been created.': [
    'Une invitation pour « {username} » a été créée.',
    'تم إنشاء دعوة للمستخدم «{username}».'
  ],
  'INVITATION TOKEN': ['JETON D\'INVITATION', 'رمز الدعوة'],
  'Scan to receive invitation token': [
    'Scannez pour recevoir le jeton d\'invitation',
    'امسح الرمز لاستلام رمز الدعوة'
  ],
  'Invitation token copied.': [
    'Jeton d\'invitation copié.',
    'تم نسخ رمز الدعوة.'
  ],
  'Copy invitation token': [
    'Copier le jeton d\'invitation',
    'نسخ رمز الدعوة'
  ],
  'Expires: {date}': ['Expire le : {date}', 'ينتهي في: {date}'],
  'Share this token securely with the shepherd. '
      'They will need it to activate their account. '
      'The invitation expires after 24 hours.': [
    'Partagez ce jeton de façon sécurisée avec le berger. '
        'Il en aura besoin pour activer son compte. '
        'L\'invitation expire après 24 heures.',
    'شارك هذا الرمز مع الراعي بطريقة آمنة. '
        'سيحتاجه لتفعيل حسابه. '
        'تنتهي صلاحية الدعوة بعد 24 ساعة.'
  ],
  'Revoke shepherd access?': [
    'Révoquer l\'accès du berger ?',
    'إلغاء صلاحية دخول الراعي؟'
  ],
  'Are you sure you want to disable {username}? '
      'This account will no longer be able to log in. '
      'Its existing records will be preserved.': [
    'Voulez-vous vraiment désactiver {username} ? '
        'Ce compte ne pourra plus se connecter. '
        'Ses données existantes seront conservées.',
    'هل أنت متأكد من تعطيل {username}؟ '
        'لن يتمكن هذا الحساب من تسجيل الدخول بعد الآن. '
        'ستبقى سجلاته الحالية محفوظة.'
  ],
  'Revoke access': ['Révoquer l\'accès', 'إلغاء الصلاحية'],
  'Access revoked for {username}.': [
    'Accès révoqué pour {username}.',
    'تم إلغاء صلاحية {username}.'
  ],
  'Could not revoke access: {error}': [
    'Impossible de révoquer l\'accès : {error}',
    'تعذّر إلغاء الصلاحية: {error}'
  ],
  'this shepherd': ['ce berger', 'هذا الراعي'],
  'No GPS position recorded': [
    'Aucune position GPS enregistrée',
    'لا يوجد موقع GPS مسجّل'
  ],
  'Account created: {date}': ['Compte créé le : {date}', 'تاريخ إنشاء الحساب: {date}'],
  'Last update: {date}': ['Dernière mise à jour : {date}', 'آخر تحديث: {date}'],
  'Lat: {v}': ['Lat : {v}', 'خط العرض: {v}'],
  'Lon: {v}': ['Lon : {v}', 'خط الطول: {v}'],
  'ACCOUNT INFORMATION': ['INFORMATIONS DU COMPTE', 'معلومات الحساب'],
  'LATEST GPS POSITION': ['DERNIÈRE POSITION GPS', 'آخر موقع GPS'],
  'Shepherd Management': ['Gestion des bergers', 'إدارة الرعاة'],
  'Manage your farm team and monitor their GPS positions.': [
    'Gérez l\'équipe de votre ferme et suivez leurs positions GPS.',
    'أدر فريق مزرعتك وتابع مواقعهم عبر GPS.'
  ],
  'Add Shepherd': ['Ajouter un berger', 'إضافة راعٍ'],
  'TOTAL SHEPHERDS': ['TOTAL DES BERGERS', 'إجمالي الرعاة'],
  'ACTIVE ACCOUNTS': ['COMPTES ACTIFS', 'الحسابات النشطة'],
  'Unable to load shepherds': [
    'Impossible de charger les bergers',
    'تعذّر تحميل الرعاة'
  ],
  'No shepherds yet': ['Aucun berger pour le moment', 'لا يوجد رعاة بعد'],
  'Create an invitation using the Add Shepherd button.': [
    'Créez une invitation avec le bouton « Ajouter un berger ».',
    'أنشئ دعوة باستخدام زر «إضافة راعٍ».'
  ],

  // --- Services (error messages shown on screen) ---
  'Not authenticated. Please log in.': [
    'Non authentifié. Veuillez vous connecter.',
    'غير مصرّح. يرجى تسجيل الدخول.'
  ],
  'Session expired. Please log in again.': [
    'Session expirée. Veuillez vous reconnecter.',
    'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.'
  ],
  'Request failed.': ['La requête a échoué.', 'فشل الطلب.'],
  'Login failed. Check your credentials.': [
    'Échec de la connexion. Vérifiez vos identifiants.',
    'فشل تسجيل الدخول. تحقق من بياناتك.'
  ],
  'No active session.': ['Aucune session active.', 'لا توجد جلسة نشطة.'],
  'Could not retrieve user information.': [
    'Impossible de récupérer les informations de l\'utilisateur.',
    'تعذّر جلب معلومات المستخدم.'
  ],
  'Please enable location services.': [
    'Veuillez activer les services de localisation.',
    'يرجى تفعيل خدمات الموقع.'
  ],
  'Location permission was denied.': [
    'L\'autorisation de localisation a été refusée.',
    'تم رفض إذن الموقع.'
  ],
};
