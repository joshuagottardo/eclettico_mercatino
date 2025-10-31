const express = require("express"); // Il framework per il server
const mysql = require("mysql2/promise"); // Il driver per MariaDB (usiamo la versione "promise" per codice più pulito)

const cors = require("cors"); // Per permettere la comunicazione tra app e API
const app = express();
const PORT = 4000; // Scegliamo una porta su cui l'API ascolterà. Puoi cambiarla se la 3000 è occupata.

app.use(cors()); // Abilita CORS per tutte le richieste

app.use(express.json()); // Permette al server di capire i dati JSON inviati dall'app (es. quando creiamo un articolo)

// 4. Configurazione della connessione al Database

const dbConfig = {
  host: "localhost", // O l'IP del tuo NAS se il DB non è sulla stessa macchina dell'API
  user: "eclettico_admin", // Sostituisci con il tuo utente
  password: "MercaAdmin25!", // Sostituisci con la tua password
  database: "eclettico_mercatino", // Sostituisci con il nome del DB che hai creato
};

// Creiamo un "pool" di connessioni. È più efficiente che aprire e chiudere
// una connessione per ogni singola richiesta.
const pool = mysql.createPool(dbConfig);

// ---------- ROTTE ----------

// --- ARTICOLI ---

/*
 * GET /api/test
 * Una rotta semplice per controllare se il server e il DB funzionano.
 */
app.get("/api/test", async (req, res) => {
  try {
    // Proviamo a fare una query semplice
    const [rows] = await pool.query("SELECT 1 + 1 AS solution");
    res.json({
      message: "API funzionante!",
      database_solution: rows[0].solution, // Dovrebbe mostrare 2
    });
  } catch (error) {
    console.error("Errore connessione DB:", error);
    res
      .status(500)
      .json({ error: "Errore durante la connessione al database" });
  }
});

/*
 * GET /api/items
 * La prima vera rotta: recupera TUTTI gli articoli dal database
 */
app.get("/api/items", async (req, res) => {
  try {
    // Usiamo il pool per eseguire la query SQL
    // Ordiniamo per i più recenti (created_at)
    const [items] = await pool.query(
      "SELECT * FROM items ORDER BY created_at DESC"
    );

    // Inviamo i risultati all'app come JSON
    res.json(items);
  } catch (error) {
    // Se qualcosa va storto, lo registriamo nel log e inviamo un errore
    console.error("Errore in GET /api/items:", error);
    res.status(500).json({ error: "Errore nel recupero degli articoli" });
  }
});

/*
 * POST /api/items
 * La rotta per CREARE un nuovo articolo.
 * Si aspetta un JSON nel "body" della richiesta.
 */
app.post("/api/items", async (req, res) => {
  // 1. Iniziamo una connessione "manuale" dal pool per gestire la transazione
  let connection;
  try {
    connection = await pool.getConnection();
  } catch (error) {
    console.error("Errore nel prendere connessione dal pool:", error);
    return res.status(500).json({ error: "Errore interno del server (pool)" });
  }

  // 2. Prendiamo i dati che l'app ci ha inviato nel "body"
  const {
    name,
    category,
    description,
    brand,
    value,
    sale_price,
    has_variants,
    quantity, // Sarà NULL se has_variants è true
    purchase_price, // Sarà NULL se has_variants è true
    platforms, // Ci aspettiamo un array di ID, es: [1, 2] (per Subito e Vinted)
  } = req.body;

  // --- Validazione base (possiamo migliorarla molto in futuro) ---
  if (!name || has_variants === undefined) {
    connection.release(); // Rilasciamo la connessione prima di uscire
    return res
      .status(400)
      .json({ error: 'Campi "name" e "has_variants" sono obbligatori' });
  }

  // 3. Generiamo il codice univoco di 10 cifre
  const unique_code = Math.floor(
    1000000000 + Math.random() * 9000000000
  ).toString();

  // 4. Iniziamo la Transazione
  try {
    await connection.beginTransaction();
    console.log("Transazione iniziata.");

    // 5. Query 1: Inseriamo l'articolo nella tabella 'items'
    const itemSql = `
            INSERT INTO items 
            (unique_code, name, category, description, brand, \`value\`, sale_price, has_variants, quantity, purchase_price)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

    // Prepariamo i valori: se has_variants è true, forziamo quantity e purchase_price a NULL
    const itemValues = [
      unique_code,
      name,
      category,
      description,
      brand,
      value,
      sale_price,
      has_variants,
      has_variants ? null : quantity,
      has_variants ? null : purchase_price,
    ];

    // Eseguiamo la query
    const [itemResult] = await connection.query(itemSql, itemValues);
    const newItemId = itemResult.insertId; // Recuperiamo l'ID del nuovo articolo appena creato

    console.log(`Articolo creato con ID: ${newItemId}`);

    // 6. Query 2 (Condizionale): Inseriamo le piattaforme
    //    Solo se l'articolo NON ha varianti e se l'app ci ha mandato un array di piattaforme
    if (has_variants === false && platforms && platforms.length > 0) {
      console.log(`Inserimento piattaforme per articolo ${newItemId}...`);

      const platformSql =
        "INSERT INTO item_platforms (item_id, platform_id) VALUES ?";

      // Creiamo un array di array per l'inserimento "bulk" (multiplo)
      // Es. [[newItemId, 1], [newItemId, 2]]
      const platformValues = platforms.map((platformId) => [
        newItemId,
        platformId,
      ]);

      await connection.query(platformSql, [platformValues]);
      console.log("Piattaforme inserite.");
    }

    // 7. Se siamo arrivati qui, è andato tutto bene. Confermiamo la transazione.
    await connection.commit();
    console.log("Transazione completata (COMMIT).");

    // 8. Inviamo una risposta positiva all'app
    res.status(201).json({
      message: "Articolo creato con successo!",
      newItemId: newItemId,
      unique_code: unique_code,
    });
  } catch (error) {
    // 9. Se qualcosa è andato storto, annulliamo TUTTE le modifiche
    await connection.rollback();
    console.error("Errore durante la transazione, eseguito ROLLBACK:", error);
    res
      .status(500)
      .json({ error: "Errore durante la creazione dell'articolo" });
  } finally {
    // 10. In ogni caso (successo o fallimento), rilasciamo la connessione al pool
    if (connection) {
      connection.release();
      console.log("Connessione rilasciata.");
    }
  }
});

// --- VARIANTI ---

/*
 * GET /api/items/:id/variants
 * (1) Recupera tutte le varianti per un articolo specifico
 * :id è un parametro, prenderà l'ID dell'articolo dall'URL
 */
app.get("/api/items/:id/variants", async (req, res) => {
  // (A) Prendiamo l'ID dell'articolo dall'URL
  const { id } = req.params;

  try {
    // (B) Facciamo una query semplice per trovare le varianti
    const [variants] = await pool.query(
      "SELECT * FROM variants WHERE item_id = ? ORDER BY variant_name ASC",
      [id] // Passiamo l'ID in modo sicuro per evitare SQL injection
    );

    // (C) Restituiamo la lista di varianti (sarà una lista vuota se non ce ne sono)
    res.json(variants);
  } catch (error) {
    console.error(`Errore in GET /api/items/${id}/variants:`, error);
    res.status(500).json({ error: "Errore nel recupero delle varianti" });
  }
});

/*
 * POST /api/items/:id/variants
 * (2) Crea una NUOVA variante per un articolo specifico
 */
app.post("/api/items/:id/variants", async (req, res) => {
  // (A) Prendiamo l'ID dell'articolo dall'URL
  const { id: item_id } = req.params;

  // (B) Prendiamo i dati della nuova variante dal "corpo" JSON
  const {
    variant_name,
    purchase_price,
    quantity,
    description,
    platforms, // Ci aspettiamo un array di ID, es: [1, 3]
  } = req.body;

  // (C) Validazione base
  if (!variant_name || purchase_price === undefined || quantity === undefined) {
    return res
      .status(400)
      .json({ error: "Nome, prezzo acquisto e quantità sono obbligatori" });
  }

  let connection;
  try {
    // (D) Iniziamo la transazione
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // (E) Query 1: Inseriamo la nuova variante
    const variantSql = `
            INSERT INTO variants (item_id, variant_name, purchase_price, quantity, description)
            VALUES (?, ?, ?, ?, ?)
        `;
    const [variantResult] = await connection.query(variantSql, [
      item_id,
      variant_name,
      purchase_price,
      quantity,
      description,
    ]);

    const newVariantId = variantResult.insertId; // Prendiamo l'ID della variante appena creata

    // (F) Query 2: Inseriamo le piattaforme (solo se ce ne sono)
    if (platforms && platforms.length > 0) {
      console.log(`Inserimento piattaforme per variante ${newVariantId}...`);

      const platformSql =
        "INSERT INTO variant_platforms (variant_id, platform_id) VALUES ?";
      const platformValues = platforms.map((platformId) => [
        newVariantId,
        platformId,
      ]);

      await connection.query(platformSql, [platformValues]);
      console.log("Piattaforme variante inserite.");
    }

    // (G) Tutto è andato bene! Salviamo le modifiche.
    await connection.commit();

    res.status(201).json({
      message: "Variante creata con successo!",
      newVariantId: newVariantId,
    });
  } catch (error) {
    // (H) Qualcosa è andato storto. Annulliamo tutto.
    if (connection) await connection.rollback();
    console.error(`Errore in POST /api/items/${item_id}/variants:`, error);
    res
      .status(500)
      .json({ error: "Errore durante la creazione della variante" });
  } finally {
    // (I) In ogni caso, rilasciamo la connessione
    if (connection) connection.release();
  }
});

// --- VENDITE ---

/*
 * GET /api/items/:id/sales
 * Recupera lo storico vendite per un articolo specifico
 */
app.get("/api/items/:id/sales", async (req, res) => {
  // (A) Prendiamo l'ID dell'articolo dall'URL
  const { id } = req.params;

  try {
    // (B) Query che unisce sales_log, platforms, e (opzionalmente) variants
    const sql = `
            SELECT 
                s.sale_id,
                s.sale_date,
                s.quantity_sold,
                s.total_price,
                s.sold_by_user,
                p.name AS platform_name, 
                v.variant_name
            FROM 
                sales_log s
            JOIN 
                platforms p ON s.platform_id = p.platform_id
            LEFT JOIN 
                variants v ON s.variant_id = v.variant_id
            WHERE 
                s.item_id = ?
            ORDER BY 
                s.sale_date DESC;
        `;

    const [sales] = await pool.query(sql, [id]);

    // (C) Restituiamo la lista di vendite
    res.json(sales);
  } catch (error) {
    console.error(`Errore in GET /api/items/${id}/sales:`, error);
    res
      .status(500)
      .json({ error: "Errore nel recupero dello storico vendite" });
  }
});

/*
 * POST /api/sales
 * Registra una nuova vendita e aggiorna le quantità
 */
app.post("/api/sales", async (req, res) => {
  // (A) Prendiamo i dati della vendita dal "corpo" JSON
  const {
    item_id,
    variant_id, // Può essere null
    platform_id,
    sale_date,
    quantity_sold,
    total_price,
    sold_by_user,
  } = req.body;

  // (B) Validazione
  if (
    !item_id ||
    !platform_id ||
    !sale_date ||
    !quantity_sold ||
    !total_price
  ) {
    return res.status(400).json({ error: "Campi obbligatori mancanti" });
  }

  let connection;
  try {
    // (C) Iniziamo la transazione
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // (D) Query 1: Inseriamo la vendita nel log
    const saleSql = `
            INSERT INTO sales_log 
            (item_id, variant_id, platform_id, sale_date, quantity_sold, total_price, sold_by_user)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `;
    await connection.query(saleSql, [
      item_id,
      variant_id,
      platform_id,
      sale_date,
      quantity_sold,
      total_price,
      sold_by_user,
    ]);
    console.log(`Vendita registrata per item_id: ${item_id}`);

    // (E) Query 2: Aggiorniamo la quantità e lo stato "is_sold"
    let newQuantity = 0;

    if (variant_id) {
      // --- Caso 1: È stata venduta una VARIANTE ---
      await connection.query(
        "UPDATE variants SET quantity = quantity - ? WHERE variant_id = ?",
        [quantity_sold, variant_id]
      );

      // Controlliamo la nuova quantità della variante
      const [variantRows] = await connection.query(
        "SELECT quantity FROM variants WHERE variant_id = ?",
        [variant_id]
      );
      newQuantity = variantRows[0].quantity;

      if (newQuantity <= 0) {
        // Segna la variante come venduta
        await connection.query(
          "UPDATE variants SET is_sold = 1 WHERE variant_id = ?",
          [variant_id]
        );
        console.log(`Variante ${variant_id} segnata come venduta.`);

        // Controlliamo se TUTTE le varianti di questo articolo sono vendute
        const [remainingVariants] = await connection.query(
          "SELECT COUNT(*) as remaining FROM variants WHERE item_id = ? AND is_sold = 0",
          [item_id]
        );

        if (remainingVariants[0].remaining == 0) {
          // Se non ci sono varianti rimaste, segna l'articolo come venduto
          await connection.query(
            "UPDATE items SET is_sold = 1 WHERE item_id = ?",
            [item_id]
          );
          console.log(
            `Articolo ${item_id} segnato come venduto (tutte le varianti vendute).`
          );
        }
      }
    } else {
      // --- Caso 2: È stato venduto un ARTICOLO (senza varianti) ---
      await connection.query(
        "UPDATE items SET quantity = quantity - ? WHERE item_id = ?",
        [quantity_sold, item_id]
      );

      // Controlliamo la nuova quantità dell'articolo
      const [itemRows] = await connection.query(
        "SELECT quantity FROM items WHERE item_id = ?",
        [item_id]
      );
      newQuantity = itemRows[0].quantity;

      if (newQuantity <= 0) {
        // Segna l'articolo come venduto
        await connection.query(
          "UPDATE items SET is_sold = 1 WHERE item_id = ?",
          [item_id]
        );
        console.log(`Articolo ${item_id} segnato come venduto.`);
      }
    }

    // (F) Tutto è andato bene! Salviamo le modifiche.
    await connection.commit();

    res.status(201).json({
      message: "Vendita registrata con successo!",
      newQuantity: newQuantity,
    });
  } catch (error) {
    // (G) Qualcosa è andato storto. Annulliamo tutto.
    if (connection) await connection.rollback();
    console.error(`Errore in POST /api/sales:`, error);
    res
      .status(500)
      .json({ error: "Errore durante la registrazione della vendita" });
  } finally {
    // (H) In ogni caso, rilasciamo la connessione
    if (connection) connection.release();
  }
});

// ---------- AVVIO SERVER ----------
app.listen(PORT, () => {
  console.log(`🚀 Server API in ascolto sulla porta ${PORT}`);
  console.log(
    `Testa la connessione su: http://[IP_DEL_TUO_NAS]:${PORT}/api/test`
  );
});
