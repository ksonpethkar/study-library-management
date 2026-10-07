import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<String> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.trim().isEmpty) {
        throw Exception('No text found in the image. Please try again with a clearer image.');
      }
      
      return recognizedText.text;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('We couldn\'t process the image due to poor quality. Please ensure it is well-lit and not blurry.');
    } finally {
      textRecognizer.close();
    }
  }
}
