const express = require("express"); // Il framework per il server
const mysql = require("mysql2/promise"); // Il driver per MariaDB (usiamo la versione "promise" per codice più pulito)
const cors = require("cors"); // Per permettere la comunicazione tra app e API
const app = express();
const PORT = 4000; // Scegliamo una porta su cui l'API ascolterà
const path = require("path"); //Pacchetto per gestire i percorsi
const multer = require("multer"); //Pacchetto per gestire gli upload
const fs = require("fs"); // Importa il File System
const sharp = require("sharp");

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
    const tempDir = "uploads/temp";
    // Assicurati che la cartella temp esista
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    cb(null, tempDir);
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
    SELECT 
        i.*, 
        c.name as category_name,
        IF(i.has_variants = 1, 
           IFNULL((SELECT SUM(v.quantity) FROM variants v WHERE v.item_id = i.item_id AND v.is_sold = 0), 0), 
           i.quantity
        ) AS display_quantity,
         i.is_used,
        (SELECT p.thumbnail_path 
         FROM photos p 
         WHERE p.item_id = i.item_id 
         LIMIT 1) AS thumbnail_path 

    FROM items i
    LEFT JOIN categories c ON i.category_id = c.category_id
    ORDER BY i.created_at DESC`
    //LIMIT 20 -- (FIX 2) Limita ai 20 risultati più recenti
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
    category_id,
    description,
    is_used,
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
            (unique_code, name, category_id, description, is_used, brand, \`value\`, sale_price, has_variants, quantity, purchase_price)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

    // Prepariamo i valori: se has_variants è true, forziamo quantity e purchase_price a NULL
    const itemValues = [
      unique_code,
      name,
      category_id,
      description,
      is_used,
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
app.get("/api/variants/:id", async (req, res) => {
  const { id } = req.params;
  try {
    // Query 1: Prende i dati della variante
    const [variants] = await pool.query(
      "SELECT * FROM variants WHERE variant_id = ?",
      [id]
    );

    if (variants.length === 0) {
      return res.status(404).json({ error: "Variante non trovata" });
    }

    // Query 2: Prende le piattaforme collegate
    const [platforms] = await pool.query(
      "SELECT platform_id FROM variant_platforms WHERE variant_id = ?",
      [id]
    );

    // Aggiungiamo l'array di ID piattaforma all'oggetto variante
    const variant = variants[0];
    variant.platforms = platforms.map((p) => p.platform_id); // es. [1, 2]

    res.json(variant);
  } catch (error) {
    console.error(`Errore in GET /api/variants/${id}:`, error);
    res.status(500).json({ error: "Errore nel recupero della variante" });
  }
});

/*
 * PUT /api/variants/:id
 * Aggiorna una variante esistente
 */
app.put("/api/variants/:id", async (req, res) => {
  const { id } = req.params;

  // Prendiamo i dati dal corpo
  const {
    variant_name,
    purchase_price,
    quantity,
    description,
    platforms, // Array di ID [1, 3]
  } = req.body;

  // Validazione
  if (!variant_name || purchase_price === undefined || quantity === undefined) {
    return res
      .status(400)
      .json({ error: "Nome, prezzo acquisto e quantità sono obbligatori" });
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
      id,
    ]);

    // Query 2: Aggiorna le piattaforme (Resetta e Inserisci)

    // (A) Cancella le vecchie piattaforme
    await connection.query(
      "DELETE FROM variant_platforms WHERE variant_id = ?",
      [id]
    );

    // (B) Inserisci le nuove (se l'array non è vuoto)
    if (platforms && platforms.length > 0) {
      const platformSql =
        "INSERT INTO variant_platforms (variant_id, platform_id) VALUES ?";
      const platformValues = platforms.map((platformId) => [id, platformId]);
      await connection.query(platformSql, [platformValues]);
    }

    await connection.commit();
    res.status(200).json({ message: "Variante aggiornata con successo!" });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in PUT /api/variants/${id}:`, error);
    res
      .status(500)
      .json({ error: "Errore durante l'aggiornamento della variante" });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * DELETE /api/variants/:id
 * Elimina una variante (solo se non ha vendite associate)
 */
app.delete("/api/variants/:id", async (req, res) => {
  const { id } = req.params;

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // Query 1: Controlla se esistono vendite per questa variante
    const [sales] = await pool.query(
      "SELECT COUNT(*) as salesCount FROM sales_log WHERE variant_id = ?",
      [id]
    );

    if (sales[0].salesCount > 0) {
      // Impedisci l'eliminazione
      await connection.rollback(); // Non serve, ma è pulito
      return res.status(400).json({
        error: "Impossibile eliminare: la variante ha uno storico vendite.",
      });
    }

    // Query 2: Elimina la variante
    // Le piattaforme (variant_platforms) verranno cancellate in automatico (ON DELETE CASCADE)
    // Le foto (photos) verranno scollegate in automatico (ON DELETE SET NULL)
    await connection.query("DELETE FROM variants WHERE variant_id = ?", [id]);

    await connection.commit();
    res.status(200).json({ message: "Variante eliminata con successo." });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in DELETE /api/variants/${id}:`, error);
    res
      .status(500)
      .json({ error: "Errore durante l'eliminazione della variante" });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * GET /api/items/:id/variants
 * (MODIFICATO per includere le piattaforme di ogni variante)
 */
app.get("/api/items/:id/variants", async (req, res) => {
  const { id } = req.params;
  try {
    // (A) Query 1: Prende tutte le varianti
    const [variants] = await pool.query(
      "SELECT * FROM variants WHERE item_id = ? ORDER BY variant_name ASC",
      [id]
    );

    // (B) NUOVO: Usiamo Promise.all per caricare le piattaforme
    //     di ogni variante in parallelo
    const variantsWithPlatforms = await Promise.all(
      variants.map(async (variant) => {
        // (C) Query 2: Prende le piattaforme per QUESTA variante
        const [platforms] = await pool.query(
          "SELECT platform_id FROM variant_platforms WHERE variant_id = ?",
          [variant.variant_id]
        );

        // (D) Aggiunge l'array di ID all'oggetto variante
        variant.platforms = platforms.map((p) => p.platform_id); // es. [1, 2]
        return variant;
      })
    );

    // (E) Invia la lista completa
    res.json(variantsWithPlatforms);
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
                s.variant_id,
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
 * GET /api/items/category/:id
 * Recupera tutti gli articoli per una specifica categoria
 */
app.get("/api/items/category/:id", async (req, res) => {
  const { id } = req.params; // Questo è il category_id

  try {
    const [items] = await pool.query(
      `
            SELECT 
                i.*, 
                c.name as category_name,
                IF(i.has_variants = 1, 
                   IFNULL((SELECT SUM(v.quantity) FROM variants v WHERE v.item_id = i.item_id AND v.is_sold = 0), 0), 
                   i.quantity
                ) AS display_quantity,
                 i.is_used,
                (SELECT p.thumbnail_path 
                 FROM photos p 
                 WHERE p.item_id = i.item_id 
                 LIMIT 1) AS thumbnail_path 

            FROM items i
            LEFT JOIN categories c ON i.category_id = c.category_id
            WHERE i.category_id = ?
            ORDER BY i.created_at DESC
        `,
      [id]
    );

    res.json(items);
  } catch (error) {
    console.error(`Errore in GET /api/items/category/${id}:`, error);
    res.status(500).json({ error: "Errore nel recupero degli articoli" });
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
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // 1. RECUPERA IL PREZZO DI ACQUISTO, BRAND E CATEGORIA
    let purchasePriceSnapshot = 0;
    let itemBrand = "";
    let itemCategoryId = null;

    if (variant_id) {
      // Se variante: prendi dati da variants + items
      const [variantData] = await connection.query(
        `SELECT v.purchase_price, i.brand, i.category_id 
                 FROM variants v 
                 JOIN items i ON v.item_id = i.item_id 
                 WHERE v.variant_id = ?`,
        [variant_id]
      );
      if (variantData.length === 0) throw new Error("Variante non trovata.");
      purchasePriceSnapshot = variantData[0].purchase_price;
      itemBrand = variantData[0].brand;
      itemCategoryId = variantData[0].category_id;
    } else {
      // Se articolo singolo: prendi dati da items
      const [itemData] = await connection.query(
        `SELECT purchase_price, brand, category_id FROM items WHERE item_id = ?`,
        [item_id]
      );
      if (itemData.length === 0) throw new Error("Articolo non trovato.");
      purchasePriceSnapshot = itemData[0].purchase_price;
      itemBrand = itemData[0].brand;
      itemCategoryId = itemData[0].category_id;
    }

    // 2. Calcola i valori per le statistiche
    const soldCost = purchasePriceSnapshot * quantity_sold;
    const netGain = total_price - soldCost; // total_price è il lordo

    // 3. Inseriamo la vendita nel log (INCLUSO IL NUOVO CAMPO)
    const saleSql = `
            INSERT INTO sales_log 
            (item_id, variant_id, platform_id, sale_date, quantity_sold, total_price, sold_by_user, purchase_price_snapshot)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `;
    await connection.query(saleSql, [
      item_id,
      variant_id,
      platform_id,
      sale_date,
      quantity_sold,
      total_price,
      sold_by_user,
      purchasePriceSnapshot, // NUOVO VALORE
    ]);

    // 4. AGGIORNA LE STATISTICHE TOTALI (statistics)
    await connection.query(
      `
            UPDATE statistics SET 
                gross_profit_total = gross_profit_total + ?,
                net_profit_total = net_profit_total + ?,
                total_spent = total_spent + ?
            WHERE stats_id = 1 
        `,
      [total_price, netGain, soldCost]
    );

    // (Assicurati che la riga 1 esista, potresti volerla inserire se non c'è)

    // (FIX 1) Spostato blocco validazione quantità PRIMA di usarlo
    const qty = Number(quantity_sold) || 0;
    if (!Number.isFinite(qty) || qty <= 0) {
      await connection.rollback();
      return res.status(400).json({ error: "quantity_sold non valido" });
    }

    // 5. AGGIORNA I CONTATORI (sales_counter)
    // Aggiorna Categoria
    if (itemCategoryId) {
      await connection.query(
        `INSERT INTO sales_counter (category_id, sales_count) 
                 VALUES (?, ?) 
                 ON DUPLICATE KEY UPDATE sales_count = sales_count + ?`,
        [itemCategoryId, qty, qty] // <-- FIX: era 1
      );
    }

    // Aggiorna Brand
    if (itemBrand) {
      await connection.query(
        `INSERT INTO sales_counter (brand, sales_count) 
                 VALUES (?, ?) 
                 ON DUPLICATE KEY UPDATE sales_count = sales_count + ?`,
        [itemBrand, qty, qty] // <-- FIX: era 1
      );
    }

    // (FIX 2) Blocco validazione quantità rimosso da qui (già eseguito sopra)

    // Decremento stock in transazione, con guardia anti-negativo
    if (variant_id) {
      // Variante
      const [resUpd] = await connection.query(
        `
    UPDATE variants 
    SET quantity = COALESCE(quantity,0) - ?,
        is_sold  = CASE WHEN COALESCE(quantity,0) - ? <= 0 THEN 1 ELSE 0 END
    WHERE variant_id = ? AND COALESCE(quantity,0) >= ?
    `,
        [qty, qty, variant_id, qty]
      );
      if (resUpd.affectedRows === 0) {
        await connection.rollback();
        return res.status(400).json({
          error: "Stock variante insufficiente o variante non trovata",
        });
      }
    } else {
      // Articolo senza varianti
      const [resUpd] = await connection.query(
        `
    UPDATE items 
    SET quantity = COALESCE(quantity,0) - ?,
        is_sold  = CASE WHEN COALESCE(quantity,0) - ? <= 0 THEN 1 ELSE 0 END
    WHERE item_id = ? AND COALESCE(quantity,0) >= ?
    `,
        [qty, qty, item_id, qty]
      );
      if (resUpd.affectedRows === 0) {
        await connection.rollback();
        return res.status(400).json({
          error: "Stock articolo insufficiente o articolo non trovato",
        });
      }
    }

    // 7. Commit
    await connection.commit();
    res.status(201).json({ message: "Vendita registrata con successo!" });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in POST /api/sales:`, error);
    res
      .status(500)
      .json({ error: "Errore durante la registrazione della vendita" });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * DELETE /api/items/:id
 * Elimina un articolo (SOLO SE NON HA VENDITE ASSOCIATE)
 */
app.delete("/api/items/:id", async (req, res) => {
  const { id: item_id } = req.params;

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // 1. Controlla lo storico vendite
    const [sales] = await connection.query(
      "SELECT COUNT(*) as salesCount FROM sales_log WHERE item_id = ?",
      [item_id]
    );

    if (sales[0].salesCount > 0) {
      // Se ci sono vendite, blocca l'eliminazione
      await connection.rollback();
      return res.status(400).json({
        error:
          "Impossibile eliminare: l'articolo ha uno storico vendite associato.",
      });
    }

    // 2. Se non ci sono vendite, procedi con l'eliminazione
    // (Assumendo che il DB usi ON DELETE CASCADE per variants, photos, item_platforms)
    await connection.query("DELETE FROM items WHERE item_id = ?", [item_id]);

    await connection.commit();
    res.status(200).json({ message: "Articolo eliminato con successo." });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in DELETE /api/items/${item_id}:`, error);
    res
      .status(500)
      .json({ error: "Errore durante l'eliminazione dell'articolo." });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * DELETE /api/sales/:id
 * Elimina una vendita e ripristina lo stock
 */
app.delete("/api/sales/:id", async (req, res) => {
  const { id: sale_id } = req.params;
  let connection;

  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // 1) Carica vendita + info item (usa i.quantity, non i.stock_quantity!)
    const [rows] = await connection.query(
      `
      SELECT 
        s.sale_id, s.item_id, s.variant_id, s.platform_id,
        s.sale_date, s.quantity_sold, s.total_price,
        s.purchase_price_snapshot,                  -- può essere NULL
        i.quantity              AS item_quantity,    -- stock item (no varianti)
        i.has_variants,
        i.purchase_price        AS item_purchase_price,  -- fallback per costo
        i.category_id, i.brand
      FROM sales_log s
      JOIN items i ON i.item_id = s.item_id
      WHERE s.sale_id = ?
      `,
      [sale_id]
    );

    if (!rows.length) {
      await connection.rollback();
      return res.status(404).json({ error: "Vendita non trovata" });
    }

    const sale = rows[0];

    // 2) Normalizza numeri
    const qty = Number(sale.quantity_sold) || 0;
    const oldTotal = Number(sale.total_price) || 0;
    const purchasePriceForCostRaw =
      sale.purchase_price_snapshot ?? sale.item_purchase_price ?? 0;
    const purchasePriceForCost = Number(purchasePriceForCostRaw) || 0;

    const soldCost = purchasePriceForCost * qty;
    const netGain = oldTotal - soldCost;

    for (const [k, v] of Object.entries({
      qty,
      oldTotal,
      purchasePriceForCost,
      soldCost,
      netGain,
    })) {
      if (!Number.isFinite(v)) {
        throw new Error(`Valore numerico non valido per ${k}: ${v}`);
      }
    }

    // 3) Ripristina lo stock:
    // - se la vendita ha variant_id -> aggiorno variants.quantity
    // - altrimenti aggiorno items.quantity
    if (sale.variant_id) {
      await connection.query(
        `UPDATE variants SET quantity = COALESCE(quantity,0) + ? WHERE variant_id = ?`,
        [qty, sale.variant_id]
      );
    } else {
      await connection.query(
        `UPDATE items SET quantity = COALESCE(quantity,0) + ? WHERE item_id = ?`,
        [qty, sale.item_id]
      );
    }

    // 4) Aggiorna statistiche (sottraggo i valori della vendita eliminata)
    await connection.query(
      `
      UPDATE statistics SET
        gross_profit_total = COALESCE(gross_profit_total,0) - ?,
        net_profit_total   = COALESCE(net_profit_total,0)   - ?,
        total_spent        = COALESCE(total_spent,0)        - ?
      WHERE stats_id = 1
      `,
      [oldTotal, netGain, soldCost]
    );

    // 5) Aggiorna contatori (se li usi)
    // (La variabile 'qty' è già stata definita correttamente sopra)
    if (sale.category_id) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = COALESCE(sales_count,0) - ? WHERE category_id = ?`,
        [qty, sale.category_id] // <-- FIX: era - 1
      );
    }
    if (sale.brand) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = COALESCE(sales_count,0) - ? WHERE brand = ?`,
        [qty, sale.brand] // <-- FIX: era - 1
      );
    }
    // 6) Elimina la vendita dal log
    await connection.query(`DELETE FROM sales_log WHERE sale_id = ?`, [
      sale_id,
    ]);

    await connection.commit();
    res.json({ message: "Vendita eliminata e statistiche aggiornate" });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error("Errore in DELETE /api/sales/:id:", err);
    res
      .status(500)
      .json({ error: "Errore durante l'eliminazione della vendita" });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * GET /api/photos/compressed/:photoId
 * (NUOVO) Restituisce un'immagine compressa al volo per la visualizzazione
 */
app.get("/api/photos/compressed/:photoId", async (req, res) => {
  const { photoId } = req.params;
  let connection;

  try {
    connection = await pool.getConnection();

    // 1. Trova il percorso del file originale dal DB
    const [photos] = await connection.query(
      "SELECT file_path FROM photos WHERE photo_id = ?",
      [photoId]
    );

    if (photos.length === 0) {
      return res.status(404).json({ error: "Foto non trovata." });
    }

    const originalFilePath = photos[0].file_path;
    const physicalPath = path.join(__dirname, originalFilePath);

    // 2. Controlla se il file esiste fisicamente
    if (!fs.existsSync(physicalPath)) {
      console.warn(`File non trovato: ${physicalPath}`);
      return res
        .status(404)
        .json({ error: "File immagine non trovato sul server." });
    }

    // 3. Comprimi l'immagine al volo con Sharp e inviala
    res.set("Content-Type", "image/jpeg"); // O il tipo originale, se puoi rilevarlo

    // Qualità di compressione: 70 è un buon compromesso.
    // Puoi giocare con questo valore (es. 60-80)
    await sharp(physicalPath)
      .jpeg({ quality: 70 }) // Comprime a JPEG con qualità 70
      .toBuffer()
      .then((data) => {
        res.send(data);
      })
      .catch((err) => {
        console.error("Errore compressione Sharp:", err);
        res
          .status(500)
          .json({ error: "Errore durante la compressione dell'immagine." });
      });
  } catch (error) {
    console.error(`Errore in GET /api/photos/compressed/${photoId}:`, error);
    res.status(500).json({ error: "Errore interno del server." });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * PUT /api/sales/:id
 * Modifica una vendita (AGGIORNATO CON VALIDAZIONE STOCK E STATISTICHE)
 */
app.put("/api/sales/:id", async (req, res) => {
  const { id: sale_id } = req.params;

  const {
    platform_id,
    sale_date,
    quantity_sold: new_quantity,
    total_price,
    sold_by_user,
  } = req.body;

  if (!platform_id || !sale_date || !new_quantity || !total_price) {
    return res.status(400).json({ error: "Campi obbligatori mancanti" });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // (A) Query 1: Trova la vendita originale e i dati dell'articolo padre
    const [sales] = await connection.query(
      `SELECT s.*, i.brand, i.category_id 
             FROM sales_log s 
             JOIN items i ON s.item_id = i.item_id 
             WHERE s.sale_id = ?`,
      [sale_id]
    );

    if (sales.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: "Vendita non trovata." });
    }

    const old_sale = sales[0];
    const {
      item_id,
      variant_id,
      quantity_sold: old_quantity,
      total_price: old_total_price,
      purchase_price_snapshot: old_purchase_price_snapshot,
    } = old_sale;

    const itemBrand = old_sale.brand;
    const itemCategoryId = old_sale.category_id;

    // 1. ANNULLA E APPLICA LE STATISTICHE

    // Calcola i valori VECCHI da SOTTRARRE
    const old_soldCost = old_purchase_price_snapshot * old_quantity;
    const old_netGain = old_total_price - old_soldCost;

    // Query 2a: Sottrai i vecchi valori dalle statistiche totali
    await connection.query(
      `
            UPDATE statistics SET 
                gross_profit_total = gross_profit_total - ?,
                net_profit_total = net_profit_total - ?,
                total_spent = total_spent - ?
            WHERE stats_id = 1 
        `,
      [old_total_price, old_netGain, old_soldCost]
    );

    // Aggiorna brand/categoria (Decremento VECCHIO)
    if (itemCategoryId) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = sales_count - ? WHERE category_id = ?`,
        [old_quantity, itemCategoryId]
      );
    }
    if (itemBrand) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = sales_count - ? WHERE brand = ?`,
        [old_quantity, itemBrand]
      );
    }

    // 2. STOCK CHECK & AGGIORNAMENTO

    // (B) Calcola la differenza per lo stock: Vecchio stock da rimettere + Nuovo stock da togliere
    // stock_to_change è positivo se devo rimettere stock, negativo se devo togliere
    const stock_to_change = old_quantity - new_quantity;

    // (C) Query 3: Controlla lo stock ATTUALE
    let current_stock = 0;
    let purchase_price_current = old_purchase_price_snapshot; // Useremo questo per la nuova riga

    if (variant_id) {
      const [rows] = await connection.query(
        "SELECT quantity, purchase_price FROM variants WHERE variant_id = ?",
        [variant_id]
      );
      if (rows.length === 0)
        throw new Error("Variante non trovata in stock check.");
      current_stock = rows[0].quantity;
      purchase_price_current = rows[0].purchase_price;
    } else {
      const [rows] = await connection.query(
        "SELECT quantity, purchase_price FROM items WHERE item_id = ?",
        [item_id]
      );
      if (rows.length === 0)
        throw new Error("Articolo non trovato in stock check.");
      current_stock = rows[0].quantity;
      purchase_price_current = rows[0].purchase_price;
    }

    // (D) Calcola il nuovo stock e controlla
    const new_stock_level = current_stock + stock_to_change;

    if (new_stock_level < 0) {
      // Rollback e messaggio di errore (include lo stock massimo disponibile)
      await connection.rollback();
      return res.status(400).json({
        error: `Quantità non valida. Max vendibile: ${
          current_stock + old_quantity
        }`,
      });
    }

    // (E) Query 4: Aggiorna lo stock
    if (variant_id) {
      await connection.query(
        "UPDATE variants SET quantity = ?, is_sold = 0 WHERE variant_id = ?",
        [new_stock_level, variant_id] // Usa il nuovo stock calcolato
      );
      await connection.query("UPDATE items SET is_sold = 0 WHERE item_id = ?", [
        item_id,
      ]);
    } else {
      await connection.query(
        "UPDATE items SET quantity = ?, is_sold = 0 WHERE item_id = ?",
        [new_stock_level, item_id]
      );
    }

    // 3. APPLICA NUOVI VALORI & LOG UPDATE

    // Calcola i valori NUOVI da AGGIUNGERE
    const new_soldCost = purchase_price_current * new_quantity;
    const new_netGain = total_price - new_soldCost;

    // Query 5: Aggiorna la vendita nel log (incluso il nuovo snapshot)
    const updateSql = `
            UPDATE sales_log SET
                platform_id = ?, sale_date = ?, quantity_sold = ?, 
                total_price = ?, sold_by_user = ?, purchase_price_snapshot = ?
            WHERE sale_id = ?
        `;
    await connection.query(updateSql, [
      platform_id,
      sale_date,
      new_quantity,
      total_price,
      sold_by_user,
      purchase_price_current, // NUOVO SNAPSHOT!
      sale_id,
    ]);

    // Query 6: Aggiorna le statistiche totali (Aggiunge i nuovi valori)
    await connection.query(
      `
            UPDATE statistics SET 
                gross_profit_total = gross_profit_total + ?,
                net_profit_total = net_profit_total + ?,
                total_spent = total_spent + ?
            WHERE stats_id = 1 
        `,
      [total_price, new_netGain, new_soldCost]
    );

    // Aggiorna brand/categoria (Incremento NUOVO)
    if (itemCategoryId) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = sales_count + ? WHERE category_id = ?`,
        [new_quantity, itemCategoryId]
      );
    }
    if (itemBrand) {
      await connection.query(
        `UPDATE sales_counter SET sales_count = sales_count + ? WHERE brand = ?`,
        [new_quantity, itemBrand]
      );
    }

    // Query 7: Ricontrolla e imposta is_sold = 1 se il nuovo stock è <= 0
    if (variant_id) {
      await connection.query(
        "UPDATE variants SET is_sold = 1 WHERE quantity <= 0 AND variant_id = ?",
        [variant_id]
      );
    } else {
      await connection.query(
        "UPDATE items SET is_sold = 1 WHERE quantity <= 0 AND item_id = ?",
        [item_id]
      );
    }

    await connection.commit();
    res.status(200).json({ message: "Vendita aggiornata con successo." });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in PUT /api/sales/${sale_id}:`, error);
    // Se è un errore del server/DB non previsto, usa 500
    const errorMessage =
      error.message || "Errore durante l'aggiornamento della vendita.";
    res.status(500).json({ error: errorMessage });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * GET /api/statistics/summary
 * Recupera tutte le statistiche chiave
 */
app.get("/api/statistics/summary", async (req, res) => {
  try {
    // 1. Statistiche Totali (Single row)
    const [totals] = await pool.query(
      "SELECT * FROM statistics WHERE stats_id = 1"
    );

    // 2. Categoria Più Venduta (Top 1)
    const [topCategory] = await pool.query(`
            SELECT sc.sales_count, c.name as category_name
            FROM sales_counter sc
            JOIN categories c ON sc.category_id = c.category_id
            WHERE sc.category_id IS NOT NULL 
            ORDER BY sc.sales_count DESC
            LIMIT 1
        `);

    // 3. Brand Più Venduto (Top 1)
    const [topBrand] = await pool.query(`
            SELECT brand, sales_count
            FROM sales_counter
            WHERE brand IS NOT NULL 
            ORDER BY sales_count DESC
            LIMIT 1
        `);

    const [estimatedProfitRows] = await pool.query(`
        SELECT SUM(total_value) AS estimated_profit
        FROM (
            -- 1. Articoli semplici (valore * quantità)
            SELECT (value * quantity) AS total_value
            FROM items
            WHERE has_variants = 0 AND is_sold = 0 AND value IS NOT NULL AND quantity IS NOT NULL

            UNION ALL

            -- 2. Articoli con varianti (valore_articolo * SOMMA(quantità_varianti))
            SELECT (i.value * IFNULL(v_sum.total_qty, 0)) AS total_value
            FROM items i
            JOIN (
                SELECT item_id, SUM(quantity) AS total_qty
                FROM variants
                WHERE is_sold = 0 AND quantity > 0
                GROUP BY item_id
            ) v_sum ON i.item_id = v_sum.item_id
            WHERE i.has_variants = 1 AND i.value IS NOT NULL
        ) AS combined_values;
    `);

    // Estrai il valore, o 0 se nullo
    const estimated_profit = estimatedProfitRows[0]?.estimated_profit || 0;

    const totalsData = totals[0] || {
      gross_profit_total: 0,
      net_profit_total: 0,
      total_spent: 0,
    };

    // Aggiungi il nuovo valore all'oggetto totals
    totalsData.estimated_profit = estimated_profit;

    res.json({
      totals: totalsData, // Invia l'oggetto totals aggiornato
      topCategory: topCategory[0] || null,
      topBrand: topBrand[0] || null,
    });
  } catch (error) {
    console.error("Errore in GET /api/statistics/summary:", error);
    res.status(500).json({ error: "Errore nel recupero delle statistiche" });
  }
});

/*
 * PUT /api/items/:id
 * Aggiorna un articolo esistente (MODIFICATO per gestire le piattaforme)
 */
app.put("/api/items/:id", async (req, res) => {
  const { id } = req.params;
  const {
    name,
    category_id, 
    description,
    is_used,
    brand,
    value,
    sale_price,
    has_variants,
    quantity,
    purchase_price,
    platforms, // (1 - NUOVO) Riceviamo l'array di piattaforme [1, 2]
  } = req.body;

  if (!name || has_variants === undefined) {
    return res
      .status(400)
      .json({ error: 'Campi "name" e "has_variants" sono obbligatori' });
  }

  const itemValues = [
    name,
    category_id,
    description,
    is_used,
    brand,
    value,
    sale_price,
    has_variants,
    has_variants ? null : quantity,
    has_variants ? null : purchase_price,
    id,
  ];

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    // Query 1: Aggiorniamo l'articolo (invariata)
    const updateSql = `
            UPDATE items SET 
                name = ?, category_id = ?, description = ?, is_used =?, brand = ?, 
                \`value\` = ?, sale_price = ?, has_variants = ?, 
                quantity = ?, purchase_price = ?
            WHERE item_id = ?
        `;
    await connection.query(updateSql, itemValues);

    // Query 2: Aggiorniamo le piattaforme
    if (has_variants) {
      // (2 - MODIFICA) Se ha varianti, le piattaforme sono gestite altrove
      // Cancelliamo qualsiasi piattaforma rimasta sull'articolo
      await connection.query("DELETE FROM item_platforms WHERE item_id = ?", [
        id,
      ]);
    } else {
      // (3 - NUOVO) Se NON ha varianti, aggiorniamo le sue piattaforme

      // (A) Cancelliamo le vecchie piattaforme per "resettare"
      await connection.query("DELETE FROM item_platforms WHERE item_id = ?", [
        id,
      ]);

      // (B) Inseriamo le nuove (se l'array non è vuoto)
      if (platforms && platforms.length > 0) {
        const platformSql =
          "INSERT INTO item_platforms (item_id, platform_id) VALUES ?";
        const platformValues = platforms.map((platformId) => [id, platformId]);
        await connection.query(platformSql, [platformValues]);
      }
    }

    await connection.commit();

    res.status(200).json({
      message: "Articolo aggiornato con successo!",
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error(`Errore in PUT /api/items/${id}:`, error);
    res
      .status(500)
      .json({ error: "Errore durante l'aggiornamento dell'articolo" });
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
/*
 * POST /api/photos/upload
 * (MODIFICATO) Carica una foto, crea un thumbnail e salva entrambi
 */
/*
 * POST /api/photos/upload
 * (MODIFICATO) Salva in una cartella specifica per item_id
 */
app.post("/api/photos/upload", upload.single("photo"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "Nessun file caricato." });
  }

  const { item_id, variant_id, description } = req.body;
  if (!item_id) {
    // Se manca l'item_id, cancella il file temp caricato
    fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: "item_id è obbligatorio." });
  }

  let connection;
  try {
    connection = await pool.getConnection();

    // --- (FIX 1) Trova il unique_code dell'articolo ---
    const [items] = await connection.query(
      "SELECT unique_code FROM items WHERE item_id = ?",
      [item_id]
    );

    if (items.length === 0) {
      fs.unlinkSync(req.file.path); // Cancella il file temp
      return res.status(404).json({ error: "Articolo non trovato." });
    }
    const unique_code = items[0].unique_code;

    // --- (FIX 2) Definisci i nuovi percorsi ---
    const originalFilename = req.file.filename;
    const thumbFilename = "thumb-" + originalFilename;

    // Cartelle di destinazione
    const itemDir = path.join(__dirname, "uploads", unique_code);
    const thumbDir = path.join(itemDir, "thumbnails");

    // Percorsi fisici finali
    const finalOriginalPath = path.join(itemDir, originalFilename);
    const finalThumbPath = path.join(thumbDir, thumbFilename);

    // Percorsi URL da salvare nel DB
    const originalUrlPath = `uploads/${unique_code}/${originalFilename}`;
    const thumbUrlPath = `uploads/${unique_code}/thumbnails/${thumbFilename}`;

    // --- (FIX 3) Crea le cartelle e sposta il file ---

    // Crea le cartelle (ricorsivo le crea entrambe)
    if (!fs.existsSync(thumbDir)) {
      fs.mkdirSync(thumbDir, { recursive: true });
    }

    // Sposta il file dalla cartella /temp alla destinazione finale
    fs.renameSync(req.file.path, finalOriginalPath);

    // --- (FIX 4) Crea la thumbnail (dal nuovo percorso) ---
    await sharp(finalOriginalPath)
      .resize(300, 300, { fit: "cover" })
      .toFile(finalThumbPath);

    // --- (FIX 5) Salva i nuovi percorsi nel DB ---
    const sql = `
        INSERT INTO photos (item_id, variant_id, file_path, thumbnail_path, description)
        VALUES (?, ?, ?, ?, ?)
    `;
    await connection.query(sql, [
      item_id,
      variant_id ? variant_id : null,
      originalUrlPath, // Percorso originale (es. uploads/123/file.jpg)
      thumbUrlPath, // Percorso thumbnail (es. uploads/123/thumbnails/thumb-file.jpg)
      description,
    ]);

    res.status(201).json({
      message: "Foto caricata con successo!",
      filePath: originalUrlPath,
    });
  } catch (error) {
    // Se qualcosa va storto, prova a cancellare il file temp
    if (fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error(
      "Errore durante la creazione del thumbnail o salvataggio DB:",
      error
    );
    res.status(500).json({ error: "Errore durante il salvataggio della foto" });
  } finally {
    if (connection) connection.release();
  }
});
/*
 * DELETE /api/photos/:id
 * Elimina una foto (sia dal DB che dal disco)
 */
app.delete("/api/photos/:id", async (req, res) => {
  const { id: photo_id } = req.params;
  let connection;

  try {
    connection = await pool.getConnection();

    // (FIX 1) Trova entrambi i percorsi (originale e thumbnail)
    const [photos] = await connection.query(
      "SELECT file_path, thumbnail_path FROM photos WHERE photo_id = ?",
      [photo_id]
    );

    if (photos.length === 0) {
      return res.status(404).json({ error: "Foto non trovata." });
    }

    const originalPath = photos[0].file_path;
    const thumbPath = photos[0].thumbnail_path;

    // (FIX 2) Elimina la riga dal database
    await connection.query("DELETE FROM photos WHERE photo_id = ?", [photo_id]);

    // (FIX 3) Elimina i file fisici (entrambi)
    if (originalPath) {
      const physicalPath = path.join(__dirname, originalPath);
      fs.unlink(physicalPath, (err) => {
        if (err) console.error("Errore eliminazione file originale:", err);
        else console.log(`File fisico eliminato: ${physicalPath}`);
      });
    }
    // Elimina anche la thumbnail se esiste
    if (thumbPath) {
      const physicalThumbPath = path.join(__dirname, thumbPath);
      fs.unlink(physicalThumbPath, (err) => {
        if (err) console.error("Errore eliminazione thumbnail:", err);
        else console.log(`File fisico eliminato: ${physicalThumbPath}`);
      });
    }

    res.status(200).json({ message: "Foto eliminata con successo." });
  } catch (error) {
    console.error(`Errore in DELETE /api/photos/${photo_id}:`, error);
    res
      .status(500)
      .json({ error: "Errore durante l'eliminazione della foto." });
  } finally {
    if (connection) connection.release();
  }
});

/*
 * GET /api/dashboard/latest-sale (CORRETTO)
 * Recupera le ULTIME 3 vendite registrate
 */
app.get("/api/dashboard/latest-sale", async (req, res) => {
  try {
    const [sales] = await pool.query(`
            SELECT 
                s.sale_id, s.total_price, s.sale_date,
                p.name AS platform_name, 
                v.variant_name,
                i.name AS item_name,
                i.item_id  -- Includiamo item_id per la navigazione!
            FROM sales_log s
            JOIN items i ON s.item_id = i.item_id
            JOIN platforms p ON s.platform_id = p.platform_id
            LEFT JOIN variants v ON s.variant_id = v.variant_id
            ORDER BY s.sale_id DESC
            LIMIT 3;
        `);
    // RESTITUISCE SEMPRE UNA LISTA (anche se vuota)
    res.json(sales);
  } catch (error) {
    console.error("Errore in GET /api/dashboard/latest-sale:", error);
    res.status(500).json({ error: "Errore nel recupero ultima vendita" });
  }
});

/*
 * GET /api/dashboard/latest-item (CORRETTO)
 * Recupera gli ULTIMI 3 articoli aggiunti
 */
app.get("/api/dashboard/latest-item", async (req, res) => {
  try {
    const [items] = await pool.query(`
            SELECT i.item_id, i.name, i.unique_code, c.name as category_name 
            FROM items i
            LEFT JOIN categories c ON i.category_id = c.category_id
            ORDER BY i.item_id DESC
            LIMIT 3;
        `);
    // RESTITUISCE SEMPRE UNA LISTA (anche se vuota)
    res.json(items);
  } catch (error) {
    console.error("Errore in GET /api/dashboard/latest-item:", error);
    res.status(500).json({ error: "Errore nel recupero ultimo articolo" });
  }
});

// ---------- AVVIO SERVER ----------
app.listen(PORT, () => {
  console.log(`🚀 Server API in ascolto sulla porta ${PORT}`);
  console.log(
    `Testa la connessione su: http://[IP_DEL_TUO_NAS]:${PORT}/api/test`
  );
});