import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/ai_generated_activity.dart';
import '../models/processed_material.dart';

class GeminiService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<AiGeneratedActivity> generateActivitiesFromMaterials({
    required List<ProcessedMaterial> materials,
  }) async {
    final importedText = _buildLimitedContext(materials);

    final prompt = '''
Ets un generador d'activitats d'estudi per una app de repetició espaiada.

Normes obligatòries:
- Utilitza NOMÉS el contingut importat.
- No afegeixis coneixement extern per generar preguntes, resums o flashcards.
- No inventis dades.
- Respon només amb JSON vàlid.
- No escriguis Markdown.
- Escriu-ho tot en català.

Has de generar:
- summary: resum general de tots els documents.
- documentSummaries: un resum separat per cada fitxer importat.
- flashcards: 12.
- multipleChoiceQuestions: 10 preguntes tipus test amb exactament 4 opcions.
- openQuestions: 8.
- exercises: NOMÉS si detectes que algun fitxer importat conté exercicis reals.

Regles molt importants per a exercises:
- NO generis exercicis nous.
- L'apartat exercises només pot contenir exercicis que apareguin als fitxers importats.
- Si cap fitxer conté exercicis, retorna "exercises": [].
- Cada exercise ha de ser l'enunciat real detectat al fitxer.
- sourceFileName ha de ser el nom exacte del fitxer on apareix l'exercici.
- Si el fitxer inclou solució o resposta de l'exercici, copia-la a solution i posa solutionGeneratedByAi=false.
- Si el fitxer conté l'exercici però NO conté la solució, llavors pots generar la solució amb IA i has de posar solutionGeneratedByAi=true.
- Si tens dubtes sobre si una cosa és exercici, no l'incloguis.

Format JSON exacte:

{
  "summary": "resum general de tots els documents",
  "documentSummaries": [
    {
      "fileName": "nom exacte del fitxer",
      "summary": "resum d'aquest document concret"
    }
  ],
  "flashcards": [
    {
      "question": "pregunta de flashcard",
      "answer": "resposta basada només en el contingut"
    }
  ],
  "multipleChoiceQuestions": [
    {
      "question": "pregunta tipus test",
      "options": ["opció A", "opció B", "opció C", "opció D"],
      "correctAnswer": "una de les opcions exactes"
    }
  ],
  "openQuestions": [
    {
      "question": "pregunta oberta",
      "suggestedAnswer": "resposta suggerida basada només en el contingut"
    }
  ],
  "exercises": [
    {
      "sourceFileName": "nom exacte del fitxer",
      "exercise": "enunciat real de l'exercici detectat al fitxer",
      "solution": "solució del fitxer o solució generada si el fitxer no en té",
      "solutionGeneratedByAi": false
    }
  ]
}

<contingut_importat>
$importedText
</contingut_importat>
''';

    final uri = Uri.parse(
      '$_baseUrl/$_model:generateContent?key=${ApiKeys.geminiApiKey}',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error Gemini ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];

    if (text == null || text.toString().trim().isEmpty) {
      throw Exception('Gemini no ha retornat cap resposta.');
    }

    final json = jsonDecode(text);

    return AiGeneratedActivity.fromJson(
      Map<String, dynamic>.from(json),
    );
  }

  String _buildLimitedContext(List<ProcessedMaterial> materials) {
    final buffer = StringBuffer();

    for (final material in materials) {
      buffer.writeln('FITXER: ${material.fileName}');
      buffer.writeln(material.extractedText);
      buffer.writeln('\n---\n');
    }

    final fullText = buffer.toString();
    const maxCharacters = 60000;

    if (fullText.length <= maxCharacters) {
      return fullText;
    }

    return fullText.substring(0, maxCharacters);
  }
}