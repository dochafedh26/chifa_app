import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  AiService._internal();
  static AiService get instance => _instance;

  /// HTTP client for API requests.
  http.Client httpClient = http.Client();

  /// Core LLM query handler: Nvidia → OpenRouter → Gemini (last resort).
  /// Gemini is tried last because its prepaid credits may be depleted.
  Future<String> _queryLlm({
    required String prompt,
    String? systemInstruction,
  }) async {
    final geminiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    final openRouterKey = (dotenv.env['OPENROUTER_API_KEY'] ?? '').trim();
    final nvidiaKey = (dotenv.env['NVIDIA_API_KEY'] ?? '').trim();

    final errors = <String>[];

    // 1. Nvidia first (reliable, token-based, no quota depletion issues)
    if (nvidiaKey.isNotEmpty) {
      try {
        return await _queryNvidia(nvidiaKey, prompt, systemInstruction);
      } catch (e) {
        print('Nvidia request failed: $e');
        errors.add('Nvidia: $e');
      }
    }

    // 2. OpenRouter second
    if (openRouterKey.isNotEmpty) {
      try {
        print('Trying OpenRouter...');
        return await _queryOpenRouter(openRouterKey, prompt, systemInstruction);
      } catch (e) {
        print('OpenRouter request failed: $e');
        errors.add('OpenRouter: $e');
      }
    }

    // 3. Gemini as last resort
    if (geminiKey.isNotEmpty) {
      try {
        print('Trying Gemini as last resort...');
        return await _queryGemini(geminiKey, prompt, systemInstruction);
      } catch (e) {
        print('Gemini request failed: $e');
        errors.add('Gemini: $e');
      }
    }

    if (errors.isEmpty) {
      throw Exception(
          'Aucune clé API configurée dans le fichier .env (NVIDIA_API_KEY, OPENROUTER_API_KEY ou GEMINI_API_KEY).');
    }
    throw Exception(
        'Tous les fournisseurs IA ont échoué:\n${errors.join('\n')}');
  }

  /// Sends an HTTP POST with up to [maxAttempts] retries on timeout/network errors.
  Future<http.Response> _postWithRetry(
    Uri url, {
    required Map<String, String> headers,
    required Object body,
    int maxAttempts = 3,
    Duration timeoutDuration = const Duration(seconds: 90),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await httpClient
            .post(url, headers: headers, body: body)
            .timeout(timeoutDuration);
      } on TimeoutException {
        if (attempt < maxAttempts) {
          final delay = Duration(seconds: 2 * attempt);
          print(
              'Request timed out. Retry $attempt/$maxAttempts in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if ((e is http.ClientException ||
                errorStr.contains('socketexception') ||
                errorStr.contains('connection closed')) &&
            attempt < maxAttempts) {
          final delay = Duration(seconds: 2 * attempt);
          print(
              'Network error. Retry $attempt/$maxAttempts in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<String> _queryNvidia(
      String apiKey, String prompt, String? systemInstruction) async {
    const modelName = 'meta/llama-3.1-8b-instruct';
    const url = 'https://integrate.api.nvidia.com/v1/chat/completions';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final messages = <Map<String, String>>[];
    if (systemInstruction != null) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }
    messages.add({'role': 'user', 'content': prompt});

    final body = {
      'model': modelName,
      'messages': messages,
      'response_format': {'type': 'json_object'},
    };

    print('Querying Nvidia API ($modelName) for chifa_app...');
    final response = await _postWithRetry(
      Uri.parse(url),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final text =
          data['choices']?[0]?['message']?['content']?.toString() ?? '';
      return text;
    } else {
      throw Exception('Erreur Nvidia (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }
  }

  Future<String> _queryOpenRouter(
      String apiKey, String prompt, String? systemInstruction) async {
    // mistral-7b reliably supports json_object response format on OpenRouter
    const modelName = 'mistralai/mistral-7b-instruct:free';
    const url = 'https://openrouter.ai/api/v1/chat/completions';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://github.com/chifa',
      'X-Title': 'Chifa App',
    };

    final messages = <Map<String, String>>[];
    if (systemInstruction != null) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }
    messages.add({'role': 'user', 'content': prompt});

    final body = {
      'model': modelName,
      'messages': messages,
      'response_format': {'type': 'json_object'},
    };

    print('Querying OpenRouter API ($modelName) for chifa_app...');
    final response = await _postWithRetry(
      Uri.parse(url),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final text =
          data['choices']?[0]?['message']?['content']?.toString() ?? '';
      return text;
    } else {
      throw Exception(
          'Erreur OpenRouter (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }
  }

  Future<String> _queryGemini(
      String apiKey, String prompt, String? systemInstruction) async {
    const modelName = 'gemini-2.5-flash';
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey';
    final body = {
      'contents': [
        {
          'parts': [
            {'text': '${systemInstruction ?? ""}\n\n$prompt'}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      }
    };

    print('Querying Gemini API ($modelName) for chifa_app...');
    final response = await _postWithRetry(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString() ??
          '';
      return text;
    } else {
      throw Exception(
          'Erreur Gemini (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }
  }

  /// Extracts JSON object from LLM response text
  Map<String, dynamic>? _extractJson(String responseText) {
    try {
      var start = responseText.indexOf('{');
      var end = responseText.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonSub = responseText.substring(start, end + 1);
        return json.decode(jsonSub) as Map<String, dynamic>;
      }
      return json.decode(responseText) as Map<String, dynamic>;
    } catch (e) {
      print(
          'Error extracting JSON from LLM response: $e\nOriginal text: $responseText');
      return null;
    }
  }

  /// Structures raw Vidal pathology text into clear clinical categories
  Future<Map<String, dynamic>?> structurePathologyData(
      String matchedPathology, String rawScrapedText) async {
    final systemInstruction = '''
Vous êtes un expert médical chevronné. Votre rôle est d'analyser le texte brut extrait du site médical VIDAL pour la pathologie "$matchedPathology", de nettoyer le contenu et de le structurer proprement en 4 sections en français :
1. "definition": Définition claire, vulgarisée et précise de la maladie, ses causes générales et qui elle touche.
2. "symptomes": Les signes cliniques, symptômes révélateurs et manifestations physiques de la pathologie.
3. "diagnostic": Comment la maladie est diagnostiquée (examens cliniques, bilans sanguins, imagerie, etc.).
4. "traitements": Prise en charge thérapeutique complète (médicaments habituels, mesures hygiéno-diététiques, chirurgie si nécessaire, prévention).

Renvoyez impérativement et uniquement un objet JSON bien formé sous cette forme exacte, sans code markdown d'encapsulation autre que le JSON lui-même :
{
  "definition": "Texte de la définition...",
  "symptomes": "Texte des symptômes...",
  "diagnostic": "Texte du diagnostic...",
  "traitements": "Texte des traitements..."
}
Note :
- Soignez la mise en forme (utilisez des paragraphes clairs et des listes à puces si nécessaire).
- Conservez les informations médicales cruciales.
- Rédigez en français correct et professionnel.
- Ne mentionnez pas les détails inutiles comme les cookies du site, les publicités, ou les liens de navigation.
- Si une section n'est pas du tout mentionnée dans le texte brut, laissez-la vide (chaîne vide "").
''';

    final prompt = '''
Voici le texte brut extrait de Vidal pour la pathologie "$matchedPathology" :
-------------------------
$rawScrapedText
-------------------------

Analyse ce texte brut et génère la structure JSON demandée.
''';

    final responseText =
        await _queryLlm(prompt: prompt, systemInstruction: systemInstruction);
    return _extractJson(responseText);
  }

  /// Checks if AI is active (configured with at least one API key)
  bool isAiActive() {
    final geminiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    final openRouterKey = (dotenv.env['OPENROUTER_API_KEY'] ?? '').trim();
    final nvidiaKey = (dotenv.env['NVIDIA_API_KEY'] ?? '').trim();
    return geminiKey.isNotEmpty ||
        openRouterKey.isNotEmpty ||
        nvidiaKey.isNotEmpty;
  }

  /// Generates a structured clinical guide for a pathology directly using LLM knowledge,
  /// formatting the treatments section like an official medical prescription (ordonnance).
  /// If [localContext] is provided (e.g. from Google Drive PDFs), it is prioritized.
  Future<Map<String, dynamic>?> generatePathologyGuide(String pathologyName,
      {String? localContext}) async {
    final systemInstruction = '''
Vous êtes un médecin chef de service et pharmacologue clinicien expert. Votre rôle est de faire office d'assistant médical IA et de générer un guide clinique pratique et structuré pour la pathologie suivante : "$pathologyName".
Vous devez baser vos informations sur les recommandations et guides de pratique clinique internationaux les plus récents (OMS, HAS, ESC/EAS, GINA, GOLD, etc.). N'utilisez pas le Vidal comme source de référence car il est considéré comme obsolète.

Renvoyez impérativement et uniquement un objet JSON bien formé en français sous cette forme exacte, sans code markdown d'encapsulation autre que le JSON lui-même :
{
  "matched_pathology": "Nom normalisé de la pathologie (ex: Diabète de type 2, Accident Vasculaire Cérébral)",
  "definition": "Définition clinique claire, causes physiopathologiques et facteurs de risque en quelques phrases.",
  "symptomes": "Signes cliniques, symptômes typiques et critères de gravité.",
  "diagnostic": "Critères de diagnostic (examens physiques, bilans biologiques recommandés, imagerie ou tests cliniques de référence).",
  "traitements": "Ligne 1 de médicament\\nLigne 2 de médicament\\n\\nConseils hygiéno-diététiques..."
}

CONSIGNES DE FORMATTAGE CRITIQUES POUR LA SECTION "traitements" (Ordonnance Type) :
- Vous devez rédiger les traitements exactement sous la forme d'une ordonnance médicale standard.
- Chaque médicament prescrit doit occuper une ligne et respecter SCRUPULEUSEMENT le format textuel suivant (avec des points de suspension reliant la posologie à la durée/boîtes) :
  NOM_MEDICAMENT dosage, posologie détaillée ........ durée (ex: 05J, 10J) ou quantité (ex: 01 BTE, 02 BTE)
- Exemple de lignes de traitement conformes :
  AMOXICILLINE 1G, 1 gélule 3 fois par jour au milieu des repas ........ 07J
  LOMAC 20MG, 1 gélule 15 minutes avant le petit-déjeuner ........ 01 BTE
  DOLIPRANE 1G, 1 comprimé en cas de fièvre ou douleur (max 3g/j) ........ 01 BTE
- Après la liste des médicaments prescrits (sauter une ligne), ajoutez des conseils pratiques et mesures hygiéno-diététiques pertinents pour le patient (ex: arrêt du tabac, régime pauvre en sel, hydratation).
''';

    var prompt =
        'Génère le guide clinique complet et l\'ordonnance type pour la pathologie suivante : "$pathologyName"';
    if (localContext != null && localContext.trim().isNotEmpty) {
      prompt +=
          '\n\nCONSIGNE IMPORTANTE : Vous devez baser vos explications et votre ordonnance PRIORITAIREMENT sur ces extraits de protocoles de soins locaux récupérés depuis notre Google Drive :\n$localContext\n\nIntégrez les traitements décrits ci-dessus dans l\'ordonnance finale en respectant le format standard imposé.';
    }

    final responseText = await _queryLlm(
      prompt: prompt,
      systemInstruction: systemInstruction,
    );

    return _extractJson(responseText);
  }
}
