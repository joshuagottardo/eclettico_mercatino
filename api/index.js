const express = require("express"); // Il framework per il server
const mysql = require("mysql2/promise"); // Il driver per MariaDB (usiamo la versione "promise" per codice più pulito)
const cors = require("cors"); // Per permettere la comunicazione tra app e API
const app = express();
const PORT = 4000; // Scegliamo una porta su cui l'API ascolterà
const path = require("path"); //Pacchetto per gestire i percorsi
const multer = require("multer"); //Pacchetto per gestire gli upload

app.use(cors()); // Abilita CORS per tutte le richieste
app.use(express.json()); // Permette al server di capire i dati JSON inviati dall'app (es. quando creiamo un articolo)
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// 4. Configurazione della connessione al Database
const dbConfig = {
  host: "localhost", // O l'IP del tuo NAS se il DB non è sulla stessa macchina dell'API
  user: "eclettico_admin", // Sostituisci con il tuo utente
  password: "MercaAdmin25!", // Sostituisci con la tua password
  database: "eclettico_mercatino", // Sostituisci con il nome del DB che hai creato
};

const storage = multer.diskStorage({
  // La destinazione è la cartella 'uploads' che abbiamo creato
  destination: function (req, file, cb) {
    cb(null, "uploads");
  },
  // Creiamo un nome file univoco
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      file.fieldname + "-" + uniqueSuffix + path.extname(file.originalname)
    );
  },
});

const upload = multer({ storage: storage });
const pool = mysql.createPool(dbConfig);

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
    const [items] = await pool.query(`
    SELECT i.*, c.name as category_name 
    FROM items i
    LEFT JOIN categories c ON i.category_id = c.category_id
    ORDER BY i.created_at DESC
`);

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
    category_id,
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
            (unique_code, name, category_id, description, brand, \`value\`, sale_price, has_variants, quantity, purchase_price)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

    // Prepariamo i valori: se has_variants è true, forziamo quantity e purchase_price a NULL
    const itemValues = [
      unique_code,
      name,
      category_id,
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

/*
 * GET /api/items/:id
 * Recupera i dettagli di un SINGOLO articolo
 */
app.get("/api/items/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [items] = await pool.query(
      `SELECT i.*, c.name as category_name 
     FROM items i
     LEFT JOIN categories c ON i.category_id = c.category_id
     WHERE i.item_id = ?`,
      [id]
    );

    if (items.length === 0) {
      return res.status(404).json({ error: "Articolo non trovato" });
    }

    // (Opzionale, ma utile) Recuperiamo anche le piattaforme
    const [platforms] = await pool.query(
      "SELECT platform_id FROM item_platforms WHERE item_id = ?",
      [id]
    );

    // Aggiungiamo l'array di ID piattaforma all'oggetto articolo
    const item = items[0];
    item.platforms = platforms.map((p) => p.platform_id); // es. [1, 2]

    res.json(item);
  } catch (error) {
    console.error(`Errore in GET /api/items/${id}:`, error);
    res.status(500).json({ error: "Errore nel recupero dell'articolo" });
  }
});

/*
 * GET /api/categories
 * Recupera l'elenco di tutte le categorie
 */
app.get("/api/categories", async (req, res) => {
  try {
    const [categories] = await pool.query(
      "SELECT * FROM categories ORDER BY category_id ASC"
    );
    res.json(categories);
  } catch (error) {
    console.error("Errore in GET /api/categories:", error);
    res.status(500).json({ error: "Errore nel recupero delle categorie" });
  }
});

/*
 * GET /api/variants/:id
 * Recupera i dettagli di una SINGOLA variante
 */
app.get('/api/variants/:id', async (req, res) => {
    const { id } = req.params;
    try {
        // Query 1: Prende i dati della variante
        const [variants] = await pool.query(
            'SELECT * FROM variants WHERE variant_id = ?', 
            [id]
        );
        
        if (variants.length === 0) {
            return res.status(404).json({ error: 'Variante non trovata' });
        }
        
        // Query 2: Prende le piattaforme collegate
        const [platforms] = await pool.query(
            'SELECT platform_id FROM variant_platforms WHERE variant_id = ?',
            [id]
        );
        
        // Aggiungiamo l'array di ID piattaforma all'oggetto variante
        const variant = variants[0];
        variant.platforms = platforms.map(p => p.platform_id); // es. [1, 2]

        res.json(variant);

    } catch (error) {
        console.error(`Errore in GET /api/variants/${id}:`, error);
        res.status(500).json({ error: 'Errore nel recupero della variante' });
    }
});

/*
 * PUT /api/variants/:id
 * Aggiorna una variante esistente
 */
app.put('/api/variants/:id', async (req, res) => {
    const { id } = req.params;
    
    // Prendiamo i dati dal corpo
    const {
        variant_name,
        purchase_price,
        quantity,
        description,
        platforms // Array di ID [1, 3]
    } = req.body;

    // Validazione
    if (!variant_name || purchase_price === undefined || quantity === undefined) {
        return res.status(400).json({ error: 'Nome, prezzo acquisto e quantità sono obbligatori' });
    }

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        // Query 1: Aggiorna i dati principali della variante
        const variantSql = `
            UPDATE variants SET 
                variant_name = ?, purchase_price = ?, quantity = ?, description = ?
            WHERE variant_id = ?
        `;
        await connection.query(variantSql, [
            variant_name,
            purchase_price,
            quantity,
            description,
            id
        ]);
        
        // Query 2: Aggiorna le piattaforme (Resetta e Inserisci)
        
        // (A) Cancella le vecchie piattaforme
        await connection.query('DELETE FROM variant_platforms WHERE variant_id = ?', [id]);

        // (B) Inserisci le nuove (se l'array non è vuoto)
        if (platforms && platforms.length > 0) {
            const platformSql = 'INSERT INTO variant_platforms (variant_id, platform_id) VALUES ?';
            const platformValues = platforms.map(platformId => [id, platformId]);
            await connection.query(platformSql, [platformValues]);
        }

        await connection.commit();
        res.status(200).json({ message: 'Variante aggiornata con successo!' });

    } catch (error) {
        if (connection) await connection.rollback();
        console.error(`Errore in PUT /api/variants/${id}:`, error);
        res.status(500).json({ error: 'Errore durante l\'aggiornamento della variante' });
    } finally {
        if (connection) connection.release();
    }
});

/*
 * DELETE /api/variants/:id
 * Elimina una variante (solo se non ha vendite associate)
 */
app.delete('/api/variants/:id', async (req, res) => {
    const { id } = req.params;

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        // Query 1: Controlla se esistono vendite per questa variante
        const [sales] = await pool.query(
            'SELECT COUNT(*) as salesCount FROM sales_log WHERE variant_id = ?',
            [id]
        );

        if (sales[0].salesCount > 0) {
            // Impedisci l'eliminazione
            await connection.rollback(); // Non serve, ma è pulito
            return res.status(400).json({ 
                error: 'Impossibile eliminare: la variante ha uno storico vendite.' 
            });
        }
        
        // Query 2: Elimina la variante
        // Le piattaforme (variant_platforms) verranno cancellate in automatico (ON DELETE CASCADE)
        // Le foto (photos) verranno scollegate in automatico (ON DELETE SET NULL)
        await connection.query('DELETE FROM variants WHERE variant_id = ?', [id]);

        await connection.commit();
        res.status(200).json({ message: 'Variante eliminata con successo.' });

    } catch (error) {
        if (connection) await connection.rollback();
        console.error(`Errore in DELETE /api/variants/${id}:`, error);
        res.status(500).json({ error: 'Errore durante l\'eliminazione della variante' });
    } finally {
        if (connection) connection.release();
    }
});

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

/*
 * DELETE /api/sales/:id
 * Elimina una vendita e ripristina lo stock
 */
app.delete('/api/sales/:id', async (req, res) => {
    const { id: sale_id } = req.params;

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        // (A) Query 1: Trova la vendita che stiamo per eliminare
        const [sales] = await connection.query(
            'SELECT * FROM sales_log WHERE sale_id = ?',
            [sale_id]
        );

        if (sales.length === 0) {
            await connection.rollback();
            return res.status(404).json({ error: 'Vendita non trovata.' });
        }

        const sale = sales[0];
        const { item_id, variant_id, quantity_sold } = sale;

        // (B) Query 2: Ripristina lo stock (aggiungi la quantità)
        if (variant_id) {
            // --- Caso 1: Ripristina una VARIANTE ---
            await connection.query(
                // Aggiungiamo la quantità e impostiamo is_sold = 0 (false)
                'UPDATE variants SET quantity = quantity + ?, is_sold = 0 WHERE variant_id = ?',
                [quantity_sold, variant_id]
            );
            
            // Dobbiamo anche assicurarci che l'articolo "padre" sia segnato come NON venduto
            await connection.query('UPDATE items SET is_sold = 0 WHERE item_id = ?', [item_id]);
            console.log(`Stock ripristinato per variante ${variant_id}.`);

        } else {
            // --- Caso 2: Ripristina un ARTICOLO (senza varianti) ---
            await connection.query(
                'UPDATE items SET quantity = quantity + ?, is_sold = 0 WHERE item_id = ?',
                [quantity_sold, item_id]
            );
            console.log(`Stock ripristinato per articolo ${item_id}.`);
        }

        // (C) Query 3: Ora elimina la vendita dal log
        await connection.query('DELETE FROM sales_log WHERE sale_id = ?', [sale_id]);

        // (D) Tutto a posto, salva
        await connection.commit();
        res.status(200).json({ message: 'Vendita eliminata e stock ripristinato.' });

    } catch (error) {
        if (connection) await connection.rollback();
        console.error(`Errore in DELETE /api/sales/${sale_id}:`, error);
        res.status(500).json({ error: 'Errore durante l\'eliminazione della vendita.' });
    } finally {
        if (connection) connection.release();
    }
});

/*
 * PUT /api/sales/:id
 * Modifica una vendita e aggiorna lo stock in base alla differenza
 */
app.put('/api/sales/:id', async (req, res) => {
    const { id: sale_id } = req.params;

    // Nuovi dati dal corpo
    const {
        platform_id,
        sale_date,
        quantity_sold: new_quantity,
        total_price,
        sold_by_user
    } = req.body;

    // Validazione
    if (!platform_id || !sale_date || !new_quantity || !total_price) {
        return res.status(400).json({ error: 'Campi obbligatori mancanti' });
    }

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        // (A) Query 1: Trova la vendita originale
        const [sales] = await connection.query(
            'SELECT * FROM sales_log WHERE sale_id = ?',
            [sale_id]
        );

        if (sales.length === 0) {
            await connection.rollback();
            return res.status(404).json({ error: 'Vendita non trovata.' });
        }

        const old_sale = sales[0];
        const old_quantity = old_sale.quantity_sold;
        const { item_id, variant_id } = old_sale;

        // (B) Calcola la differenza
        // Esempio: Vecchia=5, Nuova=3. Diff = 2 (dobbiamo AGGIUNGERE 2 allo stock)
        // Esempio: Vecchia=5, Nuova=7. Diff = -2 (dobbiamo TOGLIERE 2 dallo stock)
        const quantity_diff = old_quantity - new_quantity;

        // (C) Query 2: Aggiorna lo stock
        if (variant_id) {
            // Aggiorna variante
            await connection.query(
                // Aggiungiamo la differenza (sarà negativa se la nuova quantità è maggiore)
                'UPDATE variants SET quantity = quantity + ?, is_sold = 0 WHERE variant_id = ?',
                [quantity_diff, variant_id]
            );
            // Assicurati che anche l'articolo padre sia segnato come non venduto
            await connection.query('UPDATE items SET is_sold = 0 WHERE item_id = ?', [item_id]);
        } else {
            // Aggiorna articolo
            await connection.query(
                'UPDATE items SET quantity = quantity + ?, is_sold = 0 WHERE item_id = ?',
                [quantity_diff, item_id]
            );
        }
        
        // (D) Query 3: Aggiorna la vendita nel log
        const updateSql = `
            UPDATE sales_log SET
                platform_id = ?, sale_date = ?, quantity_sold = ?, 
                total_price = ?, sold_by_user = ?
            WHERE sale_id = ?
        `;
        await connection.query(updateSql, [
            platform_id,
            sale_date,
            new_quantity,
            total_price,
            sold_by_user,
            sale_id
        ]);
        
        // (E) Query 4: (IMPORTANTE) Ricontrolla lo stato "is_sold"
        // Ora che abbiamo aggiornato, la quantità potrebbe essere di nuovo <= 0
        if (variant_id) {
            await connection.query(
                'UPDATE variants SET is_sold = 1 WHERE quantity <= 0 AND variant_id = ?',
                [variant_id]
            );
        } else {
            await connection.query(
                'UPDATE items SET is_sold = 1 WHERE quantity <= 0 AND item_id = ?',
                [item_id]
            );
        }

        await connection.commit();
        res.status(200).json({ message: 'Vendita aggiornata con successo.' });

    } catch (error) {
        if (connection) await connection.rollback();
        console.error(`Errore in PUT /api/sales/${sale_id}:`, error);
        res.status(500).json({ error: 'Errore durante l\'aggiornamento della vendita.' });
    } finally {
        if (connection) connection.release();
    }
});

/*
 * PUT /api/items/:id
 * Aggiorna un articolo esistente (MODIFICATO per gestire le piattaforme)
 */
app.put('/api/items/:id', async (req, res) => {
    const { id } = req.params;
    const {
        name,
        category_id, // Già aggiornato
        description,
        brand,
        value,
        sale_price,
        has_variants,
        quantity,
        purchase_price,
        platforms // (1 - NUOVO) Riceviamo l'array di piattaforme [1, 2]
    } = req.body;

    if (!name || has_variants === undefined) {
        return res.status(400).json({ error: 'Campi "name" e "has_variants" sono obbligatori' });
    }
    
    const itemValues = [
        name,
        category_id,
        description,
        brand,
        value,
        sale_price,
        has_variants,
        has_variants ? null : quantity,
        has_variants ? null : purchase_price,
        id 
    ];

    let connection;
    try {
        connection = await pool.getConnection();
        await connection.beginTransaction();

        // Query 1: Aggiorniamo l'articolo (invariata)
        const updateSql = `
            UPDATE items SET 
                name = ?, category_id = ?, description = ?, brand = ?, 
                \`value\` = ?, sale_price = ?, has_variants = ?, 
                quantity = ?, purchase_price = ?
            WHERE item_id = ?
        `;
        await connection.query(updateSql, itemValues);

        // Query 2: Aggiorniamo le piattaforme
        if (has_variants) {
             // (2 - MODIFICA) Se ha varianti, le piattaforme sono gestite altrove
             // Cancelliamo qualsiasi piattaforma rimasta sull'articolo
             await connection.query('DELETE FROM item_platforms WHERE item_id = ?', [id]);
        } else {
            // (3 - NUOVO) Se NON ha varianti, aggiorniamo le sue piattaforme
            
            // (A) Cancelliamo le vecchie piattaforme per "resettare"
            await connection.query('DELETE FROM item_platforms WHERE item_id = ?', [id]);

            // (B) Inseriamo le nuove (se l'array non è vuoto)
            if (platforms && platforms.length > 0) {
                const platformSql = 'INSERT INTO item_platforms (item_id, platform_id) VALUES ?';
                const platformValues = platforms.map(platformId => [id, platformId]);
                await connection.query(platformSql, [platformValues]);
            }
        }
        
        await connection.commit();
        
        res.status(200).json({ 
            message: 'Articolo aggiornato con successo!'
        });

    } catch (error) {
        if (connection) await connection.rollback();
        console.error(`Errore in PUT /api/items/${id}:`, error);
        res.status(500).json({ error: 'Errore durante l\'aggiornamento dell\'articolo' });
    } finally {
        if (connection) connection.release();
    }
});

/*
 * GET /api/platforms
 * Recupera l'elenco di tutte le piattaforme di pubblicazione disponibili
 */
app.get("/api/platforms", async (req, res) => {
  try {
    // (A) Semplice query per prendere tutto dalla tabella platforms
    const [platforms] = await pool.query(
      "SELECT * FROM platforms ORDER BY name ASC"
    );

    // (B) Invia i risultati
    res.json(platforms);
  } catch (error) {
    console.error("Errore in GET /api/platforms:", error);
    res.status(500).json({ error: "Errore nel recupero delle piattaforme" });
  }
});

// --- FOTO ---
/*
 * GET /api/items/:id/photos
 * Recupera la lista di foto per un articolo (e le sue varianti)
 */
app.get("/api/items/:id/photos", async (req, res) => {
  const { id } = req.params;
  try {
    const [photos] = await pool.query(
      "SELECT * FROM photos WHERE item_id = ?",
      [id]
    );
    res.json(photos);
  } catch (error) {
    console.error(`Errore in GET /api/items/${id}/photos:`, error);
    res.status(500).json({ error: "Errore nel recupero delle foto" });
  }
});

/*
 * POST /api/photos/upload
 * Carica una nuova foto e la salva nel database
 */
// (5 - NUOVO) Usiamo il middleware 'upload.single('photo')'
// 'photo' deve essere il nome del campo che l'app userà
app.post("/api/photos/upload", upload.single("photo"), async (req, res) => {
  // (A) Multer ha già salvato il file. I suoi dati sono in 'req.file'
  if (!req.file) {
    return res.status(400).json({ error: "Nessun file caricato." });
  }

  // (B) I dati del form (a quale articolo/variante appartiene) sono in 'req.body'
  const { item_id, variant_id, description } = req.body;

  if (!item_id) {
    return res.status(400).json({ error: "item_id è obbligatorio." });
  }

  // (C) Creiamo il percorso URL per salvare nel DB
  // es. "uploads/photo-123456.jpg"
  const file_path = "uploads/" + req.file.filename;

  try {
    // (D) Salviamo il riferimento nel DB
    const sql = `
            INSERT INTO photos (item_id, variant_id, file_path, description)
            VALUES (?, ?, ?, ?)
        `;
    await pool.query(sql, [
      item_id,
      variant_id ? variant_id : null, // Salva null se variant_id è assente
      file_path,
      description,
    ]);

    // (E) Inviamo una risposta di successo con il percorso del file
    res.status(201).json({
      message: "Foto caricata con successo!",
      filePath: file_path,
    });
  } catch (error) {
    console.error("Errore salvataggio foto su DB:", error);
    res
      .status(500)
      .json({ error: "Errore durante il salvataggio della foto nel database" });
  }
});

// ---------- AVVIO SERVER ----------
app.listen(PORT, () => {
  console.log(`🚀 Server API in ascolto sulla porta ${PORT}`);
  console.log(
    `Testa la connessione su: http://[IP_DEL_TUO_NAS]:${PORT}/api/test`
  );
});
