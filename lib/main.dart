import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ImageRecognitionApp extends StatefulWidget {
  const ImageRecognitionApp({Key? key}) : super(key: key);

  @override
  State<ImageRecognitionApp> createState() => _ImageRecognitionAppState();
}

class _ImageRecognitionAppState extends State<ImageRecognitionApp> {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;
  late List<String> _labels = [];
  late List<dynamic> _outputs = [];
  final ImagePicker _imagePicker = ImagePicker();
  File? _image;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  void loadModel() async {
    try {
      String modelPath = 'model_unquant.tflite';
      String labelsPath = 'labels.txt';

      _interpreter = await Interpreter.fromAsset(modelPath);
      print('Interpreter loaded successfully');

      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();

      print('Input tensors: $inputTensors');
      print('Output tensors: $outputTensors');

      String labelsContent = await rootBundle.loadString('assets/$labelsPath');
      _labels = labelsContent.split('\n');
      print(_labels);
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print('Échec du chargement du modèle : $e');
    }
  }

  void runModelOnImage(File imageFile) async {
    if (!_isModelLoaded) {
      return;
    }
    print('Image file path: ${imageFile.path}');

    try {
     
      img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
      print('Image size: ${image?.width} x ${image?.height}');

     
      int targetSize = 224; 
      img.Image resizedImage =
          img.copyResize(image!, width: targetSize, height: targetSize);
      print('Resized image size: ${resizedImage.width} x ${resizedImage.height}');

      List<List<List<double>>> input = [];

      for (int y = 0; y < resizedImage.height; y++) {
        List<List<double>> row = [];
        for (int x = 0; x < resizedImage.width; x++) {
          img.Pixel pixel = resizedImage.getPixel(x, y);
          double red = pixel.r / 255.0;
          double green = pixel.g / 255.0;
          double blue = pixel.b / 255.0;
          row.add([red, green, blue]);
        }
        input.add(row);
      }

      print('Input size: ${input.length} x ${input[0].length}');
      print('Input: $input');

      var reshapedInput = input.reshape([1, input.length, input[0].length, 3]);
      print('Reshaped input: $reshapedInput');


      var output = List.filled(1 * 6, 0).reshape([1, 6]);

      _interpreter.run(reshapedInput, output);

      print('Output: $output');

      setState(() {
        _outputs = output;
        _image = imageFile;
      });
    } catch (e) {
      print('Failed to run the model on the image: $e');
    }
  }

 Future<void> pickImage(ImageSource source) async {
    var image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      File imageFile = File(image.path);
      runModelOnImage(imageFile);
    }
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Recognition'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.1,
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => pickImage(ImageSource.gallery),
                    child: const Text('Select Image'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => pickImage(ImageSource.camera),
                    child: const Text('Take Photo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getMaxLabel(),
            style: const TextStyle(fontSize: 20),
          ),
          if (_image != null)
            Expanded(
              child: Center(
                child: Image.file(_image!),
              ),
            ),
        ],
      ),
    );
  }



  String _getMaxLabel() {
    if (_outputs.isNotEmpty) {
      double maxValue = double.negativeInfinity;
      int maxIndex = -1;
      for (int i = 0; i < _outputs[0].length; i++) {
        double currentValue = _outputs[0][i];
        if (currentValue > maxValue) {
          maxValue = currentValue;
          maxIndex = i;
        }
      }
      if (maxIndex != -1) {
        return _labels[maxIndex];
      }
    }
    return '';
  }
}

void main() {
  runApp(const MaterialApp(
    home: ImageRecognitionApp(),
  ));
}
