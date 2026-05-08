import 'dart:math';
import 'dart:typed_data';

double cosineSimilarity(Float32List vectorA, Float32List vectorB) {
  if (vectorA.length != vectorB.length) {
    throw ArgumentError('Vectors must be of the same length');
  }

  double dotProduct = 0.0;
  double magnitudeA = 0.0;
  double magnitudeB = 0.0;

  for (int i = 0; i < vectorA.length; i++) {
    dotProduct += vectorA[i] * vectorB[i];
    magnitudeA += vectorA[i] * vectorA[i];
    magnitudeB += vectorB[i] * vectorB[i];
  }

  if (magnitudeA == 0 || magnitudeB == 0) {
    return 0.0; // Avoid division by zero
  }

  return dotProduct / (sqrt(magnitudeA) * sqrt(magnitudeB));
}
