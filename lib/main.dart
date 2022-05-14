// ignore_for_file: prefer_if_null_operators

import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const MyApp());
}

class CardModel {
  String name;
  String eurPrice;
  String eurFoilPrice;
  String editionCode;
  String collectorNumber;
  Set<String> pictures;

  CardModel(this.name, this.eurPrice, this.eurFoilPrice, this.editionCode, this.collectorNumber, this.pictures);
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
  final _freeSearchController = TextEditingController();
  CardModel? _currentCard;
  final _savedCards = <CardModel>{};
  final _cardsFromSearch = <CardModel>{};

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
                  items:_currentCard?.pictures.map((uri) {
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
                    Expanded(child: _currentCard?.eurPrice != "" ? Text('Non foil : ${_currentCard?.eurPrice} €') : const Text('No non foil price found')),
                    Expanded(child: _currentCard?.eurFoilPrice != "" ? Text('Foil : ${_currentCard?.eurFoilPrice} €') : const Text('No foil price found')),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Enter card name'
                        ),
                        keyboardType: TextInputType.text,
                        controller: _freeSearchController,
                      )
                    ),
                    TextButton(onPressed: getCardFromNameField, child: const Text('Search')),
                  ],
                ),
              ),
            ),
            ButtonBar(children: [
              TextButton(onPressed: getCardFromCodeCollector, child: const Text('Get card')),
              TextButton(onPressed: saveCard, child: const Text('Save card'))
            ],)
          ],
        ),   
      )
    );
  }

  void getCardFromCodeCollector() async {
    final editionCode = _extensionCodeController.text.toString();
    final collectorNumber = _collectorNumberController.text.toString();
    final url = Uri.parse('https://api.scryfall.com/cards/${editionCode.toLowerCase()}/$collectorNumber');
    var response = await http.get(url);
    var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));

    setState(() {
      var pictures = getPicturesFromJson(decodedResponse);
      _currentCard = CardModel(
        decodedResponse['name'],
        decodedResponse['prices']['eur'],
        decodedResponse['prices']['eur_foil'],
        decodedResponse['set'],
        decodedResponse['collector_number'],
        pictures
      );     
    });   
  }

  void getCardFromNameField() async {
    final nameQuery = _freeSearchController.text.toString();
    _freeSearchController.clear();
    FocusScope.of(context).unfocus();
    final uri = 'https://api.scryfall.com/cards/search?q=$nameQuery&unique=prints';
    final encodedUri = Uri.encodeFull(uri);
    var response = await http.get(Uri.parse(encodedUri));
    var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
    setState(() {
      _cardsFromSearch.clear();
      var resultList = decodedResponse['data'];
      for (var cardJson in resultList) {
        var pictures = getPicturesFromJson(cardJson);

        var cardModel = CardModel(
          cardJson['name'], 
          cardJson['prices']['eur'] == null ? "" : cardJson['prices']['eur'],
          cardJson['prices']['eur_foil'] == null ? "" : cardJson['prices']['eur_foil'],
          cardJson['set'],
          cardJson['collector_number'],
          pictures
        );
        _cardsFromSearch.add(cardModel);
      }
      if (_cardsFromSearch.isNotEmpty) {
        pushCardListFromSearch();
      } else {
        Fluttertoast.showToast(msg: 'No Results');
      }
    }); 
  }

  Set<String> getPicturesFromJson(cardJson) {
    var pictures = <String>{};
    if (cardJson['card_faces'] != null) {
      for (var face in (cardJson['card_faces'] as List<dynamic>)) {
        if (face['image_uris'] != null) {
          pictures.add(face['image_uris']['png']);
        } else {
          if (cardJson['image_uris'] != null) {
            pictures.add(cardJson['image_uris']['png']);
          }
        }
      }
    } else {
      pictures.add(cardJson['image_uris']['png']);
    }
    return pictures;
  }

  void saveCard() {
    if (!_savedCards.contains(_currentCard)) {
      _savedCards.add(_currentCard as CardModel);
    }
  }

  void cleanList() {
    _savedCards.clear();
    Navigator.of(context).pop();
  }

  void pushList() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
      final cards = _savedCards.map((savedCard) {
        return Card(
          child: Row(
            children: [
              Expanded(child: Text(savedCard.name), flex: 3,),
              Expanded(child: Text(savedCard.editionCode.toUpperCase()), flex: 1,),
              Expanded(child: Text(savedCard.collectorNumber.toString()), flex: 1,),
              Expanded(child: Text(savedCard.eurPrice.toString()), flex: 1,),
              Expanded(child: Text(savedCard.eurFoilPrice.toString()), flex: 1,),
            ]
          ),
        );
      });
      final widgetList = cards.isNotEmpty ? cards.toList() : <Widget>[];
      return Scaffold(
        appBar: AppBar(title: const Text('Cards to sell'),
         actions: [
           IconButton(onPressed: cleanList, icon: const Icon(Icons.delete), tooltip: 'Clean list and go back',)
         ],
        ),
        body: ListView(children: widgetList),
      );
    }));
  }

  void pushCardListFromSearch() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) {
        final cards = _cardsFromSearch.map((cardFromSearchResults) {
          return Card(
            child: Row(
              children: [
                Expanded(child: Text(cardFromSearchResults.name), flex: 3,),
                Expanded(child: Text(cardFromSearchResults.editionCode), flex: 1,),
                Expanded(child: Text(cardFromSearchResults.collectorNumber.toString()), flex: 1,),
                Expanded(child: Text(cardFromSearchResults.eurPrice.toString()), flex: 1,),
                Expanded(child: Text(cardFromSearchResults.eurFoilPrice.toString()), flex: 1,),
                Expanded(child: TextButton(
                  child: const Text('OK'), 
                  onPressed: () {
                    setState(() {
                      _currentCard = cardFromSearchResults;
                      Navigator.of(context).pop();
                    });
                  },
                ),)
              ]
            ),
          );
        });
        final widgetList = cards.isNotEmpty ? cards.toList() : <Widget>[];
      return Scaffold(
        appBar: AppBar(title: const Text('Search Results'),
          actions: [
            IconButton(
              onPressed: () {
              _cardsFromSearch.clear();
              Navigator.of(context).pop();
              },
              icon: const Icon(Icons.backspace_outlined), 
              tooltip: 'Clean list and go back',
            )
          ],
        ),
        body: ListView(children: widgetList),
      );
      })
    );
  }
}
