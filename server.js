// Import required packages
const express = require('express');
const session = require('express-session');
const bcrypt = require('bcryptjs'); // For hashing passwords
const db = require('./database.js'); // Our database connection pool
require('dotenv').config();

const app = express();
const port = 3000;

// --- Middleware ---

// Set EJS as the view engine
app.set('view engine', 'ejs');

// Serve static files (CSS, client-side JS) from the 'public' directory
app.use(express.static('public'));

// Parse URL-encoded bodies (as sent by HTML forms)
app.use(express.urlencoded({ extended: true }));

// Parse JSON bodies (as sent by API clients)
app.use(express.json());

// Configure express-session
app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false } // Set to true if using HTTPS
}));

// --- Authentication Middleware ---
// This function checks if a user is logged in
const isAuthenticated = (req, res, next) => {
    if (req.session.user) {
        next(); // User is logged in, continue to the next function
    } else {
        res.redirect('/login'); // Not logged in, redirect to login
    }
};

// This function checks if the logged-in user has the required role
const hasRole = (role)=> {
    return (req, res, next) => {
        if (req.session.user.role === role) {
            next(); // User has the required role
        } else {
            res.status(403).send('Forbidden: You do not have access to this page.');
        }
    };
};

// --- Routes ---

// GET / - Root route, redirects to login or dashboard
app.get('/', (req, res) => {
    if (req.session.user) {
        // Redirect to the correct dashboard based on role
        res.redirect(`/${req.session.user.role}`);
    } else {
        res.redirect('/login');
    }
});

// --- LOGIN & LOGOUT ---

// GET /login - Show the login page
app.get('/login', (req, res) => {
    res.render('login', { error: null });
});

// POST /login - Handle login attempt
app.post('/login', async (req, res) => {
    const { username, password } = req.body;

    try {
        // Find the user in the database
        const [users] = await db.query('SELECT * FROM Users WHERE username = ?', [username]);

        if (users.length === 0) {
            return res.render('login', { error: 'Invalid username or password' });
        }

        const user = users[0];

        // Compare the provided password with the hashed password in the database
        // NOTE: We are using plain text passwords as requested (e.g., "ADMIN"),
        // so we'll do a simple string comparison.
        // In a real-world app, you would use bcrypt.compare()
        if (password === user.password) {
            // Store user information in the session
            req.session.user = {
                id: user.user_id,
                username: user.username,
                role: user.role
            };
            // Redirect to the user's specific dashboard
            res.redirect(`/${user.role}`);
        } else {
            res.render('login', { error: 'Invalid username or password' });
        }
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET /logout - Log the user out
app.get('/logout', (req, res) => {
    req.session.destroy((err) => {
        if (err) {
            return console.error(err);
        }
        res.redirect('/login');
    });
});

// --- ADMIN Dashboard ---
app.get('/admin', isAuthenticated, hasRole('admin'), async (req, res) => {
    try {
        // This is where you run your most complex queries (Unit 2: Subqueries)
        // This is your "Surplus Report" (Q8.B)
        const [surplusReport] = await db.query(`
            SELECT C.name, S.total_quantity_in_stock_kg
            FROM Chemical_In_Stock S
            JOIN Raw_Chemicals C ON S.chemical_id = C.chemical_id
            WHERE S.total_quantity_in_stock_kg > 100
            AND S.chemical_id NOT IN (
                SELECT DISTINCT RC.chemical_id
                FROM Recipe_Components RC
                JOIN Production_Log PL ON RC.medicine_id = PL.medicine_id
                WHERE PL.production_date > (NOW() - INTERVAL 6 MONTH)
            );
        `);
        
        // This is your "Profit Dashboard" query (Q9) using the VIEW
        const [profitDashboard] = await db.query('SELECT * FROM Admin_Profit_Dashboard');
        
        // This query (Q10) lets the admin see everything
        const [allPurchases] = await db.query('SELECT * FROM Chemical_Purchases_View');
        const [allLogs] = await db.query('SELECT * FROM Production_Log');

        res.render('admin', {
            user: req.session.user,
            surplusReport: surplusReport,
            profitDashboard: profitDashboard,
            allPurchases: allPurchases,
            allLogs: allLogs
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// --- INVENTORY Manager Dashboard ---
app.get('/inventory', isAuthenticated, hasRole('inventory'), async (req, res) => {
    try {
        // Get all data needed for the inventory page
        const [stock] = await db.query('SELECT * FROM Stock_View');
        const [purchases] = await db.query('SELECT * FROM Chemical_Purchases_View');
        const [suppliers] = await db.query('SELECT * FROM Suppliers');
        const [chemicals] = await db.query('SELECT * FROM Raw_Chemicals');

        res.render('inventory', {
            user: req.session.user,
            stock: stock,
            purchases: purchases,
            suppliers: suppliers,
            chemicals: chemicals
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /inventory/add-purchase - Add a new chemical purchase
app.post('/inventory/add-purchase', isAuthenticated, hasRole('inventory'), async (req, res) => {
    const { chemical_id, supplier_id, quantity, price } = req.body;
    
    try {
        // This is a simple DML (INSERT) query (Unit 2)
        await db.query(
            'INSERT INTO Chemical_Purchases (chemical_id, supplier_id, purchase_date, quantity_kg, price_per_kg_inr) VALUES (?, ?, NOW(), ?, ?)',
            [chemical_id, supplier_id, quantity, price]
        );

        // This is a DML (UPDATE) query (Unit 2)
        // It updates the stock table after a purchase
        await db.query(
            'UPDATE Chemical_In_Stock SET total_quantity_in_stock_kg = total_quantity_in_stock_kg + ? WHERE chemical_id = ?',
            [quantity, chemical_id]
        );

        res.redirect('/inventory');
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// --- PRODUCTION Manager Dashboard ---
app.get('/production', isAuthenticated, hasRole('production'), async (req, res) => {
    try {
        const [medicines] = await db.query('SELECT * FROM Medicines');
        const [stock] = await db.query('SELECT * FROM Stock_View');
        const [logs] = await db.query('SELECT * FROM Production_Log');

        res.render('production', {
            user: req.session.user,
            medicines: medicines,
            stock: stock,
            logs: logs,
            error: null,
            success: null
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /production/produce - Triggers the "Produce Medicine" Transaction
app.post('/production/produce', isAuthenticated, hasRole('production'), async (req, res) => {
    const { medicine_id, quantity } = req.body;
    let successMsg = null;
    let errorMsg = null;

    try {
        // This is the call to our Stored Procedure (Unit 5: Transaction)
        // This is the core of your project's backend complexity.
        await db.query('CALL Produce_Medicine(?, ?)', [parseInt(medicine_id), parseInt(quantity)]);
        
        successMsg = `Successfully produced ${quantity} units of medicine.`;

    } catch (err) {
        // The database will throw an error (e.g., from ROLLBACK) if something fails
        console.error(err.message);
        errorMsg = `Production failed: ${err.message}`;
    }

    // Reload the page with the success/error message
    const [medicines] = await db.query('SELECT * FROM Medicines');
    const [stock] = await db.query('SELECT * FROM Stock_View');
    const [logs] = await db.query('SELECT * FROM Production_Log');

    res.render('production', {
        user: req.session.user,
        medicines: medicines,
        stock: stock,
        logs: logs,
        error: errorMsg,
        success: successMsg
    });
});


// --- RETAIL Manager Dashboard ---
app.get('/retail', isAuthenticated, hasRole('retail'), async (req, res) => {
    try {
        const [orders] = await db.query('SELECT * FROM Sales_Orders_View');
        const [medicines] = await db.query('SELECT * FROM Medicines');
        const [wholesalers] = await db.query('SELECT * FROM Wholesalers');
        const [medicineStock] = await db.query('SELECT * FROM Finished_Medicine_Stock');
        
        res.render('retail', {
            user: req.session.user,
            orders: orders,
            medicines: medicines,
            wholesalers: wholesalers,
            medicineStock: medicineStock
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /retail/add-order - Add a new sales order
app.post('/retail/add-order', isAuthenticated, hasRole('retail'), async (req, res) => {
    const { wholesaler_id, medicine_id, quantity } = req.body;
    
    // This is where you implement your 60% Gross Margin rule (Q1)
    // We get the cost from the database and calculate the selling price
    try {
        const [costResult] = await db.query(
            'SELECT last_calculated_cost FROM Finished_Medicine_Stock WHERE medicine_id = ?', 
            [medicine_id]
        );
        
        const cost = costResult[0].last_calculated_cost;
        // Gross Margin = (Price - Cost) / Price
        // 0.60 = (Price - Cost) / Price
        // 0.60 * Price = Price - Cost
        // Cost = Price - 0.60 * Price
        // Cost = Price * (1 - 0.60)
        // Price = Cost / 0.40
        const sellingPrice = cost / 0.40; // This gives a 60% margin

        // Start a transaction to create the order and the order details
        // (Unit 5)
        const connection = await db.getConnection();
        await connection.beginTransaction();

        const [orderResult] = await connection.query(
            'INSERT INTO Sales_Orders (wholesaler_id, order_date, status) VALUES (?, CURDATE(), ?)',
            [wholesaler_id, 'pending']
        );
        
        const order_id = orderResult.insertId;

        await connection.query(
            'INSERT INTO Order_Details (order_id, medicine_id, quantity, selling_price_per_unit_inr) VALUES (?, ?, ?, ?)',
            [order_id, medicine_id, quantity, sellingPrice]
        );
        
        await connection.commit();
        connection.release();

        res.redirect('/retail');
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

app.post('/retail/ship-order/:id', isAuthenticated, hasRole('retail'), async (req, res) => {
    const { id } = req.params;
    try {
        await db.query(
            "UPDATE Sales_Orders SET status = 'shipped' WHERE order_id = ?",
            [id]
        );
        res.redirect('/retail');
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});