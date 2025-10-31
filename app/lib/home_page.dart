// lib/home_page.dart - AGGIORNATO CON RICERCA DINAMICA

import 'dart:convert';
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  
  // (1 - MODIFICATO) Creiamo due liste
  List _allItems = []; // Conterrà SEMPRE tutti gli articoli
  List _filteredItems = []; // Conterrà gli articoli da mostrare
  
  // (2 - NUOVO) Creiamo un controller per la barra di ricerca
  // Questo ci permette di "ascoltare" cosa scrive l'utente
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // (3 - NUOVO) Aggiungiamo un "ascoltatore"
    // Ogni volta che il testo cambia, chiama la funzione _filterItems
    _searchController.addListener(_filterItems);
    
    // Carichiamo i dati iniziali
    fetchItems();
  }

  // (4 - NUOVO) Ricorda di "pulire" il controller
  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  // (5 - MODIFICATO) Ora questa funzione popola entrambe le liste
  Future<void> fetchItems() async {
    // Non serve reimpostare _isLoading a true se non è la prima volta
    if (!_isLoading) {
      setState(() { _isLoading = true; });
    }
    
    const url = 'http://trentin-nas.synology.me:4000/api/items';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _allItems = data; // Popola la lista principale
            _filteredItems = data; // Popola la lista filtrata
            _isLoading = false;
          });
        }
      } else {
        // ... (gestione errore)
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      // ... (gestione errore)
      print('Errore di rete: $e');
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // (6 - NUOVO) Questa è la funzione magica della ricerca!
  void _filterItems() {
    // Prende il testo dalla barra e lo mette in minuscolo
    final searchTerm = _searchController.text.toLowerCase();
    
    List tempFilteredList = [];

    // Se la barra è vuota, mostra di nuovo tutti gli articoli
    if (searchTerm.isEmpty) {
      tempFilteredList = _allItems;
    } else {
      // Altrimenti, "filtra" la lista principale
      tempFilteredList = _allItems.where((item) {
        
        // (A) Controlla il nome (titolo)
        final name = item['name']?.toLowerCase() ?? '';
        // (B) Controlla il codice univoco
        final code = item['unique_code']?.toLowerCase() ?? '';
        
        // Se uno dei due contiene il termine di ricerca, l'articolo "passa"
        return name.contains(searchTerm) || code.contains(searchTerm);
        
      }).toList(); // Converte il risultato in una nuova Lista
    }

    // (C) Aggiorna lo stato, dicendo a Flutter di ridisegnare
    //     l'interfaccia con la nuova lista filtrata
    setState(() {
      _filteredItems = tempFilteredList;
    });
  }

  // (7 - MODIFICATO) Funzione per la navigazione
  //    Ora dobbiamo ricaricare i dati quando torniamo indietro (Fix 1)
  Future<void> _navigateAndReload(BuildContext context, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    // (8 - FIX 1) Se torniamo indietro e abbiamo un risultato 'true'
    //    (come da AddItemPage o dal futuro ItemDetailPage), ricarichiamo!
    if (result == true) {
      fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // (9 - MODIFICATO) Colleghiamo il controller
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca per nome o codice...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            // (10 - NUOVO) Aggiungiamo un bottone "X" per pulire la ricerca
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear(); // Pulisce il testo
                    },
                  )
                : null, // Non mostra nulla se la barra è vuota
          ),
          // (11 - NUOVO) Gestisce il tasto "Invio" sulla tastiera
          onSubmitted: (value) => _filterItems(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtri',
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          // (12 - MODIFICATO) Mostra un messaggio se la ricerca non produce risultati
          : _filteredItems.isEmpty
            ? const Center(
                child: Text('Nessun articolo trovato.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                // (13 - MODIFICATO) Usiamo la lista filtrata
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  // (14 - MODIFICATO) Usiamo la lista filtrata
                  final item = _filteredItems[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Codice: ${item['unique_code']} | Pz: ${item['quantity'] ?? 'N/A'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // (15 - MODIFICATO) Usiamo la nostra nuova funzione
                        _navigateAndReload(
                          context, 
                          ItemDetailPage(item: item),
                        );
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // (16 - MODIFICATO) Usiamo la nostra nuova funzione
          _navigateAndReload(
            context,
            const AddItemPage(),
          );
        },
        tooltip: 'Aggiungi articolo',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}