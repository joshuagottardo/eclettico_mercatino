// lib/home_page.dart - AGGIORNATO PER L'API

import 'dart:convert'; // (1) Per decodificare JSON
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // (2) Il nostro pacchetto di rete
import 'package:app/add_item_page.dart';
import 'package:app/item_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // (3) Variabili di "stato"
  bool _isLoading = true; // Mostra il caricamento all'inizio
  List _items = []; // Lista vuota per contenere gli articoli

  // (4) Questa funzione viene chiamata AUTOMATICAMENTE quando la pagina si carica
  @override
  void initState() {
    super.initState();
    fetchItems(); // Chiamiamo la nostra funzione per caricare i dati
  }

  // (5) La funzione che parla con la tua API
  Future<void> fetchItems() async {
    // Sostituisci questo IP se il tuo NAS è diverso!
    const url = 'http://trentin-nas.synology.me:4000/api/items';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // (6) Successo! Decodifichiamo il JSON e aggiorniamo lo stato
        final data = jsonDecode(response.body);

        // (7) setState() dice a Flutter: "Ho nuovi dati, ridisegna l'interfaccia!"
        setState(() {
          _items = data;
          _isLoading = false; // Finito di caricare
        });
      } else {
        // Gestiamo un errore del server (es. 500)
        print('Errore server: ${response.statusCode}');
        setState(() {
          _isLoading = false; // Finito di caricare (con errore)
        });
      }
    } catch (e) {
      // Gestiamo un errore di rete (es. WiFi spento, API non raggiungibile)
      print('Errore di rete: $e');
      setState(() {
        _isLoading = false; // Finito di caricare (con errore)
      });
    }
  }

  // (8) Il metodo build che disegna l'interfaccia
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'Cerca articolo...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          ),
          onChanged: (text) {
            // Logica di ricerca (la faremo dopo)
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtri',
            onPressed: () {},
          ),
        ],
      ),

      // --- IL CORPO DELLA PAGINA (AGGIORNATO) ---
      body:
          _isLoading
              // (A) Se stiamo caricando, mostra il cerchio azzurro
              ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              // (B) Altrimenti, mostra la lista
              : ListView.builder(
                padding: const EdgeInsets.all(8.0), // Un po' di spazio
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  // Prendiamo il singolo articolo dalla lista
                  final item = _items[index];

                  // (9) ListTile è un widget perfetto per una riga di una lista
                  // Cerca questo blocco:
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text(
                        'Codice: ${item['unique_code']} | Pz: ${item['quantity'] ?? 'N/A'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),

                      // (1) MODIFICHIAMO QUESTA FUNZIONE
                      onTap: () {
                        // (2) Usiamo Navigator.push per aprire la nuova pagina
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // (3) Passiamo l'oggetto "item" al costruttore della pagina di dettaglio
                            builder: (context) => ItemDetailPage(item: item),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

      // Cerca questo blocco:
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // (A) Rendi la funzione "async"

          // (B) Apriamo la nuova pagina e ASPETTIAMO che si chiuda
          final bool? newItemAdded = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemPage()),
          );

          // (C) Se la pagina è stata chiusa con "true" (ovvero abbiamo salvato)...
          if (newItemAdded == true) {
            // ... ricarichiamo la lista degli articoli!
            fetchItems();
          }
        },
        tooltip: 'Aggiungi articolo',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
