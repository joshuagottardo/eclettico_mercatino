const express = require('express'); // Il framework per il server
const mysql = require('mysql2/promise'); // Il driver per MariaDB (usiamo la versione "promise" per codice più pulito)

const cors = require('cors'); // Per permettere la comunicazione tra app e API
const app = express();
const PORT = 4000; // Scegliamo una porta su cui l'API ascolterà. Puoi cambiarla se la 3000 è occupata.

app.use(cors()); // Abilita CORS per tutte le richieste

app.use(express.json()); // Permette al server di capire i dati JSON inviati dall'app (es. quando creiamo un articolo)


// 4. Configurazione della connessione al Database

const dbConfig = {
    host: 'localhost', // O l'IP del tuo NAS se il DB non è sulla stessa macchina dell'API
    user: 'eclettico_admin',       // Sostituisci con il tuo utente
    password: 'MercaAdmin25!', // Sostituisci con la tua password
    database: 'eclettico_mercatino' // Sostituisci con il nome del DB che hai creato
};

// Creiamo un "pool" di connessioni. È più efficiente che aprire e chiudere
// una connessione per ogni singola richiesta.
const pool = mysql.createPool(dbConfig);


// 5. Definiamo le "Rotte" (le richieste che il cameriere sa gestire)

/*
 * GET /api/test
 * Una rotta semplice per controllare se il server e il DB funzionano.
 */
app.get('/api/test', async (req, res) => {
    try {
        // Proviamo a fare una query semplice
        const [rows] = await pool.query('SELECT 1 + 1 AS solution');
        res.json({
            message: 'API funzionante!',
            database_solution: rows[0].solution // Dovrebbe mostrare 2
        });
    } catch (error) {
        console.error("Errore connessione DB:", error);
        res.status(500).json({ error: 'Errore durante la connessione al database' });
    }
});


/*
 * GET /api/items
 * La prima vera rotta: recupera TUTTI gli articoli dal database
 */
app.get('/api/items', async (req, res) => {
    try {
        // Usiamo il pool per eseguire la query SQL
        // Ordiniamo per i più recenti (created_at)
        const [items] = await pool.query('SELECT * FROM items ORDER BY created_at DESC');
        
        // Inviamo i risultati all'app come JSON
        res.json(items);

    } catch (error) {
        // Se qualcosa va storto, lo registriamo nel log e inviamo un errore
        console.error("Errore in GET /api/items:", error);
        res.status(500).json({ error: 'Errore nel recupero degli articoli' });
    }
});

/*
 * POST /api/items
 * La rotta per CREARE un nuovo articolo.
 * Si aspetta un JSON nel "body" della richiesta.
 */
app.post('/api/items', async (req, res) => {
    
    // 1. Iniziamo una connessione "manuale" dal pool per gestire la transazione
    let connection;
    try {
        connection = await pool.getConnection();
    } catch (error) {
        console.error("Errore nel prendere connessione dal pool:", error);
        return res.status(500).json({ error: 'Errore interno del server (pool)' });
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
        quantity,       // Sarà NULL se has_variants è true
        purchase_price, // Sarà NULL se has_variants è true
        platforms       // Ci aspettiamo un array di ID, es: [1, 2] (per Subito e Vinted)
    } = req.body;

    // --- Validazione base (possiamo migliorarla molto in futuro) ---
    if (!name || has_variants === undefined) {
        connection.release(); // Rilasciamo la connessione prima di uscire
        return res.status(400).json({ error: 'Campi "name" e "has_variants" sono obbligatori' });
    }
    
    // 3. Generiamo il codice univoco di 10 cifre
    const unique_code = Math.floor(1000000000 + Math.random() * 9000000000).toString();

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
            has_variants ? null : purchase_price
        ];
        
        // Eseguiamo la query
        const [itemResult] = await connection.query(itemSql, itemValues);
        const newItemId = itemResult.insertId; // Recuperiamo l'ID del nuovo articolo appena creato

        console.log(`Articolo creato con ID: ${newItemId}`);

        // 6. Query 2 (Condizionale): Inseriamo le piattaforme
        //    Solo se l'articolo NON ha varianti e se l'app ci ha mandato un array di piattaforme
        if (has_variants === false && platforms && platforms.length > 0) {
            console.log(`Inserimento piattaforme per articolo ${newItemId}...`);
            
            const platformSql = 'INSERT INTO item_platforms (item_id, platform_id) VALUES ?';
            
            // Creiamo un array di array per l'inserimento "bulk" (multiplo)
            // Es. [[newItemId, 1], [newItemId, 2]]
            const platformValues = platforms.map(platformId => [newItemId, platformId]);
            
            await connection.query(platformSql, [platformValues]);
            console.log("Piattaforme inserite.");
        }

        // 7. Se siamo arrivati qui, è andato tutto bene. Confermiamo la transazione.
        await connection.commit();
        console.log("Transazione completata (COMMIT).");

        // 8. Inviamo una risposta positiva all'app
        res.status(201).json({ 
            message: 'Articolo creato con successo!', 
            newItemId: newItemId,
            unique_code: unique_code 
        });

    } catch (error) {
        // 9. Se qualcosa è andato storto, annulliamo TUTTE le modifiche
        await connection.rollback();
        console.error("Errore durante la transazione, eseguito ROLLBACK:", error);
        res.status(500).json({ error: 'Errore durante la creazione dell\'articolo' });
    } finally {
        // 10. In ogni caso (successo o fallimento), rilasciamo la connessione al pool
        if (connection) {
            connection.release();
            console.log("Connessione rilasciata.");
        }
    }
});

// 6. Avviamo il Server
app.listen(PORT, () => {
    console.log(`🚀 Server API in ascolto sulla porta ${PORT}`);
    console.log(`Testa la connessione su: http://[IP_DEL_TUO_NAS]:${PORT}/api/test`);
});