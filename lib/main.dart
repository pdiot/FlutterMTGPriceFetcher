import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cardList.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class CardModel {
  String name;
  double eurPrice;
  double eurFoilPrice;
  String editionCode;
  int collectorNumber;

  CardModel(this.name, this.eurPrice, this.eurFoilPrice, this.editionCode, this.collectorNumber);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTG Card Pricer',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const CardDisplay(),
    );
  }
}

class CardDisplay extends StatefulWidget {
  const CardDisplay({Key? key}) : super(key: key);

  @override
  State<CardDisplay> createState() => _CardDisplayState();
}

class _CardDisplayState extends State<CardDisplay> {
  final _collectorNumberController = TextEditingController();
  final _extensionCodeController = TextEditingController();
  final _picturesToDisplay = <String>{};
  CardModel? _currentCard;

  @override
  void dispose() {
    _collectorNumberController.dispose();
    _extensionCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Card Pricer'),
          actions: [IconButton(icon: const Icon(Icons.list), onPressed: pushList, tooltip: 'Saved Cards')]),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card( // Carousel
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: 400.0,
                    enableInfiniteScroll: false,
                    autoPlay: false
                  ),
                  items: _picturesToDisplay.map((uri) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Image.network((uri))
                        );
                      },
                    );
                  }).toList()
                ),
              )
            ),
            Card( // Prices
              child: Padding (
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(child: _currentCard?.eurPrice != null ? Text('Non foil : ${_currentCard?.eurPrice} €') : const Text('No non foil price found')),
                    Expanded(child: _currentCard?.eurFoilPrice != null ? Text('Foil : ${_currentCard?.eurFoilPrice} €') : const Text('No foil price found')),
                  ],
                ),
              )            
            ),
            Card( // EditionCode
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter Edition Code',
                ),
                controller: _extensionCodeController,
              )
            ),
            Card( // CollectorNumber
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter Collector Number',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                controller: _collectorNumberController,
              )
            ),
            ButtonBar(children: [
              TextButton(onPressed: getCard, child: const Text('Get card')),
              TextButton(onPressed: saveCard, child: const Text('Save card'))
            ],)
          ],
        ),   
      )
    );
  }

  void getCard() async {
    final editionCode = _extensionCodeController.text.toString();
    final collectorNumber = _collectorNumberController.text.toString();
    final url = Uri.parse('https://api.scryfall.com/cards/${editionCode.toLowerCase()}/$collectorNumber');
    var response = await http.get(url);
    var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
    setState(() {
      _currentCard = CardModel(
        decodedResponse['name'],
        double.parse(decodedResponse['prices']['eur']),
        double.parse(decodedResponse['prices']['eur_foil']),
        decodedResponse['set'],
        int.parse(decodedResponse['collector_number']),
      );
      _picturesToDisplay.clear();
      if (decodedResponse['card_faces'] != null) {
        for (var face in (decodedResponse['card_faces'] as List<dynamic>)) { 
          _picturesToDisplay.add(face['image_uris']['png']);
        }
      } else {
        _picturesToDisplay.add(decodedResponse['image_uris']['png']);
      }
    });   
  }

  void saveCard() {
  }

  void pushList() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
      return Scaffold(appBar: AppBar(title: const Text('Saved Cards')), body: const CardList());
    }));
  }
}
