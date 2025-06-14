import 'dart:io';
import 'dart:convert';

// This is a simple base64 encoded PNG icon (64x64 purple touchpad icon)
const String base64Icon = '''
iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAdgAAAHYBTnsmCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAOdSURBVHic7ZtNbBNXFIafM7aTOHHi2EmcxHFCQqAJBdqqSKWCCrVIXbSqUBddtKtWXXTRVVftpquuWnXRRVft
okuqqhVSW1WlaqVSqVSpVFpVqVAqIFASSEhISOzEceLEjmPHdjxzuxi7Y8eZGc/4x3by8e28c8973/nO/c65554ZA4ZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGMb/gf8rAEVRXgOOA3uBZmA9sApYAKaBy8Bl4CPgG8dxFv5Xf2VZNoCyLLsQ
+BrwKrAd2Aa0AU3AGmAJmAOmgAngCvA98AVwzHGcuXICVGS5twmALMtNwNvAG8A2YCPQCKwGqoAg4APmgQngV+Ar4BPgW8dxpv9tAGRZbgfeA94ENgGtwFqgDqgBqoEqIA5EgSngBvAjcAo47jjO3f9NgCzLe4D3gd3Ae4gKbQHWAfVALVADhIEw4AciwCQwCvwCfA4ccxznzt8
tAFmW9wGHgIPAa8AGoAVoQ1RoDaJCK4Eq4C4wBpwHfnMc5/e/SwCyLL8MvAO8AmwHthKv0KvABqAJaEKcAyKAF7gNXAOOAp84jjP2txtAluWdwGHEq66uUCNwEHgOeBl4EdgJdAHNQC3iBjgKfA58BPzgOM7s3yIAWZabgdeB14CXgB2IF
+oahABeAtqB54HnEK/Agdl2wDfAMeBz4JLjOKO/lwBkWQ4A+4C3gFeBvcAWxAu1HnEL3JNdgBfAN8CnwDeO4/z2ewlAluU2xAv1DcTLdCfQibgNbkH0/i4wCZwBjgLfOo4z8rsIQJblTcBB4C3gEOLV14l4oTYizgOAF/gdOAF85jjOtf
+FAGRZ7gAOA28Dr5C6BQamgDPAZ47jXP6fBSDLciswALwJvI64BTYiusBuRBeYJLULnHIc58r/JgBZlpuA14G3gVeA7YgroA5RoQJFKxxKdIEfEQP0J47jjK2IAGRZrkJ0fweAA8B+oBcxAHUjusIgogvkKtKhRBf4ETjhOM7NsgWg
qqovyzJAN2IA6gUGgF7EKZsKh8Ae0gBT2BwQA5JnUxXCZfxNOo7TXLFfYJgLEIRhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZhGIZ
hGEb/AQOtKl1lXJ3tAAAAAElFTkSuQmCC
''';

void main() async {
  // Decode base64 to bytes
  final bytes = base64Decode(
    base64Icon.replaceAll('\n', '').replaceAll(' ', ''),
  );

  // Create PNG file
  final file = File('assets/icons/app_icon.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);

  print('Created app icon: ${file.path}');
}
