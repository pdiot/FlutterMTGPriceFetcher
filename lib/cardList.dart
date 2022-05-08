import 'package:flutter/material.dart';

class CardList extends StatefulWidget {
  const CardList({ Key? key }) : super(key: key);

  @override
  State<CardList> createState() => _CardListState();
}

class _CardListState extends State<CardList> {
  @override
  Widget build(BuildContext context) {
    final tiles = [const Text('Toto'), const Text('Tata')];
    final list = ListTile.divideTiles(context: context, tiles: tiles).toList();

    return ListView(
      children: list
    );
  }
}