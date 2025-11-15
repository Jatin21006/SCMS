-- -----------------------------------------------------------------
-- SURPLUS CHEMICAL MANAGEMENT - DBMS PROJECT SQL SCRIPT
-- -----------------------------------------------------------------

-- STEP 1: CREATE THE DATABASE
-- Drop the database if it already exists to start fresh
DROP DATABASE IF EXISTS chemical_db;
CREATE DATABASE chemical_db;
USE chemical_db;

-- -----------------------------------------------------------------
-- STEP 2: CREATE TABLES (DDL) - Corresponds to Unit 3
-- -----------------------------------------------------------------
-- We use normalization (3NF) to design the schema.

-- Users table for role-based access
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    role ENUM('admin', 'inventory', 'production', 'retail') NOT NULL
);

-- Suppliers of raw chemicals
CREATE TABLE Suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(20)
);

-- Master list of all raw chemicals
CREATE TABLE Raw_Chemicals (
    chemical_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT
);

-- Logs every single purchase (as requested in Q3)
-- This allows for complex cost analysis.
CREATE TABLE Chemical_Purchases (
    purchase_id INT AUTO_INCREMENT PRIMARY KEY,
    chemical_id INT NOT NULL,
    supplier_id INT NOT NULL,
    purchase_date DATETIME NOT NULL,
    quantity_kg DECIMAL(10, 2) NOT NULL,
    price_per_kg_inr DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (chemical_id) REFERENCES Raw_Chemicals(chemical_id),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- This table tracks the CURRENT inventory levels.
-- It is updated by triggers and transactions.
CREATE TABLE Chemical_In_Stock (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    chemical_id INT NOT NULL UNIQUE,
    total_quantity_in_stock_kg DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (chemical_id) REFERENCES Raw_Chemicals(chemical_id)
);

-- Master list of all medicines we can produce
CREATE TABLE Medicines (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

-- JUNCTION TABLE (Unit 3: Many-to-Many Relationship)
-- Defines the "recipe" for each medicine.
CREATE TABLE Recipe_Components (
    recipe_component_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    chemical_id INT NOT NULL,
    -- e.g., 0.65 for 65%
    percentage_composition DECIMAL(5, 4) NOT NULL, 
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id),
    FOREIGN KEY (chemical_id) REFERENCES Raw_Chemicals(chemical_id),
    -- A medicine can't have the same chemical listed twice
    UNIQUE KEY uk_medicine_chemical (medicine_id, chemical_id) 
);

-- This table tracks the CURRENT stock of finished medicines
CREATE TABLE Finished_Medicine_Stock (
    stock_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL UNIQUE,
    quantity_in_stock INT NOT NULL DEFAULT 0,
    -- Stores the cost at the time of the *last* production run
    last_calculated_cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

-- Logs every production batch (Unit 5)
CREATE TABLE Production_Log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    quantity_produced INT NOT NULL,
    production_date DATETIME NOT NULL,
    -- We log the cost per unit *at the time of production*
    calculated_cost_per_unit_inr DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

-- Wholesalers who buy our finished medicines
CREATE TABLE Wholesalers (
    wholesaler_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT
);

-- Master table for sales orders
CREATE TABLE Sales_Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    wholesaler_id INT NOT NULL,
    order_date DATE NOT NULL,
    status ENUM('pending', 'shipped', 'cancelled') NOT NULL DEFAULT 'pending',
    FOREIGN KEY (wholesaler_id) REFERENCES Wholesalers(wholesaler_id)
);

-- JUNCTION TABLE (Unit 3: Many-to-Many)
-- Links Sales_Orders to Medicines (an order can have multiple medicines)
CREATE TABLE Order_Details (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    medicine_id INT NOT NULL,
    quantity INT NOT NULL,
    -- We log the price *at the time of sale*
    selling_price_per_unit_inr DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Sales_Orders(order_id),
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

-- -----------------------------------------------------------------
-- STEP 3: INSERT SAMPLE DATA (DML) - 10+ REAL-WORLD ENTRIES
-- -----------------------------------------------------------------

-- 1. Users (Using plain text passwords as requested, NOT for production)
INSERT INTO Users (username, password, role) VALUES
('ADMIN', 'ADMIN', 'admin'),
('INVENTORYMANAGER', 'ADMIN_INVENTORYMANAGER', 'inventory'),
('PRODUCTIONMANAGER', 'ADMIN_PRODUCTIONMANAGER', 'production'),
('RETAILMANAGER', 'ADMIN_RETAILMANAGER', 'retail');

-- 2. Suppliers
INSERT INTO Suppliers (name, contact_person, phone) VALUES
('PharmaCore India', 'Mr. A. Sharma', '9810012345'),
('Delta Chemicals', 'Ms. R. Singh', '9811067890'),
('Gujarat Fine Chemicals', 'Mr. P. Mehta', '9820054321'),
('SolvoChem Ltd.', 'Ms. S. Reddy', '9830011223');

-- 3. Raw Chemicals (Master List)
INSERT INTO Raw_Chemicals (name, description) VALUES
('Paracetamol API', 'Active Pharmaceutical Ingredient for analgesics.'),
('Caffeine Anhydrous', 'Stimulant used in painkiller formulations.'),
('Pharmaceutical Starch', 'Binder and filler agent (Corn Starch).'),
('Sodium Benzoate', 'Preservative.'),
('Ibuprofen API', 'Active Pharmaceutical Ingredient for NSAID.'),
('Microcrystalline Cellulose', 'Binder and texturizer.');

-- 4. Initial Stock (Create empty stock records for all chemicals)
INSERT INTO Chemical_In_Stock (chemical_id, total_quantity_in_stock_kg) VALUES
(1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0);

-- 5. Chemical Purchases (10 entries)
-- These INSERTs will also populate the Chemical_In_Stock table via a Trigger (see Step 4)
INSERT INTO Chemical_Purchases (chemical_id, supplier_id, purchase_date, quantity_kg, price_per_kg_inr) VALUES
(1, 1, '2025-10-01', 500.00, 300.00), -- Paracetamol
(1, 1, '2025-11-01', 500.00, 310.00), -- Paracetamol (price increased)
(2, 2, '2025-10-05', 100.00, 850.00), -- Caffeine
(3, 3, '2025-10-10', 1000.00, 40.00), -- Starch
(4, 4, '2025-10-15', 50.00, 120.00),  -- Sodium Benzoate
(5, 2, '2025-10-20', 300.00, 1100.00), -- Ibuprofen
(6, 3, '2025-10-22', 800.00, 60.00),  -- Microcrystalline Cellulose
(1, 1, '2025-05-01', 200.00, 290.00), -- Old Paracetamol purchase (for surplus report)
(3, 3, '2025-11-05', 1000.00, 42.00), -- Starch
(2, 2, '2025-11-10', 50.00, 875.00);  -- Caffeine

-- 6. Medicines (Master List)
INSERT INTO Medicines (name) VALUES
('Para-Caff 500mg', 'Paracetamol 500mg + Caffeine 65mg'),
('Ibu-Plus 400mg', 'Ibuprofen 400mg + Paracetamol 325mg'),
('Generic Paracetamol 650mg');

-- 7. Initial Finished Medicine Stock (Create empty records)
INSERT INTO Finished_Medicine_Stock (medicine_id, quantity_in_stock, last_calculated_cost) VALUES
(1, 0, 0), (2, 0, 0), (3, 0, 0);

-- 8. Recipes (Junction Table)
-- Assuming 1 unit = 1 gram total weight
-- Para-Caff 500mg (Let's say total tablet is 1g)
-- 500mg Paracetamol = 0.5g = 50%
-- 65mg Caffeine = 0.065g = 6.5%
-- Remainder is binders (Starch, Cellulose)
INSERT INTO Recipe_Components (medicine_id, chemical_id, percentage_composition) VALUES
(1, 1, 0.500), -- 50% Paracetamol
(1, 2, 0.065), -- 6.5% Caffeine
(1, 3, 0.435); -- 43.5% Starch (Binder)

-- Ibu-Plus 400mg (Let's say total tablet is 1.2g)
-- 400mg Ibuprofen = 0.4g = 33.33%
-- 325mg Paracetamol = 0.325g = 27.08%
-- Remainder is binders
INSERT INTO Recipe_Components (medicine_id, chemical_id, percentage_composition) VALUES
(2, 5, 0.3333), -- 33.33% Ibuprofen
(2, 1, 0.2708), -- 27.08% Paracetamol
(2, 6, 0.3959); -- 39.59% Microcrystalline Cellulose

-- Generic Paracetamol 650mg (Let's say total tablet is 1g)
-- 650mg Paracetamol = 0.65g = 65%
-- Remainder is binders
INSERT INTO Recipe_Components (medicine_id, chemical_id, percentage_composition) VALUES
(3, 1, 0.650), -- 65% Paracetamol
(3, 3, 0.350); -- 35% Starch

-- 9. Wholesalers
INSERT INTO Wholesalers (name, address) VALUES
('Apollo Pharmacy Distribution', 'Chennai, TN'),
('MedPlus Logistics', 'Hyderabad, TS'),
('Delhi PharmaLink', 'New Delhi, DL');

-- 10. Sales Orders & Details (10+ entries)
-- These are 'pending' and will be 'shipped' by the user, firing the trigger.
INSERT INTO Sales_Orders (wholesaler_id, order_date, status) VALUES
(1, '2025-11-01', 'pending'),
(2, '2025-11-03', 'pending'),
(3, '2025-11-05', 'shipped'), -- One already shipped
(1, '2025-11-10', 'pending');

-- Prices are hardcoded here, but in the app, they are calculated.
INSERT INTO Order_Details (order_id, medicine_id, quantity, selling_price_per_unit_inr) VALUES
(1, 1, 10000, 2.50), -- Para-Caff
(2, 2, 5000, 4.00),  -- Ibu-Plus
(3, 1, 20000, 2.50), -- Para-Caff (Shipped)
(3, 3, 15000, 2.00), -- Gen-Para (Shipped)
(4, 3, 30000, 2.00); -- Gen-Para

-- -----------------------------------------------------------------
-- STEP 4: CREATE TRIGGERS (Unit 2: Triggers)
-- -----------------------------------------------------------------

-- This trigger auto-updates the Chemical_In_Stock table
-- whenever a new purchase is logged in Chemical_Purchases.
DELIMITER $$
CREATE TRIGGER trg_after_purchase_insert
AFTER INSERT ON Chemical_Purchases
FOR EACH ROW
BEGIN
    UPDATE Chemical_In_Stock
    SET total_quantity_in_stock_kg = total_quantity_in_stock_kg + NEW.quantity_kg
    WHERE chemical_id = NEW.chemical_id;
END$$
DELIMITER ;

-- This trigger auto-updates the Finished_Medicine_Stock table
-- whenever a Sales_Order is marked as 'shipped'.
DELIMITER $$
CREATE TRIGGER trg_after_order_shipped
AFTER UPDATE ON Sales_Orders
FOR EACH ROW
BEGIN
    -- Check if the status was changed TO 'shipped'
    IF NEW.status = 'shipped' AND OLD.status != 'shipped' THEN
        -- Need to loop through all items in Order_Details for this order
        -- This requires a CURSOR, which is advanced and perfect for your project.
        
        DECLARE done INT DEFAULT FALSE;
        DECLARE v_medicine_id INT;
        DECLARE v_quantity INT;
        
        -- Declare the cursor
        DECLARE cur_order_details CURSOR FOR
            SELECT medicine_id, quantity
            FROM Order_Details
            WHERE order_id = NEW.order_id;
            
        -- Declare a handler for when no more rows are found
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
        
        OPEN cur_order_details;
        
        read_loop: LOOP
            FETCH cur_order_details INTO v_medicine_id, v_quantity;
            IF done THEN
                LEAVE read_loop;
            END IF;
            
            -- Update the stock for each medicine in the order
            UPDATE Finished_Medicine_Stock
            SET quantity_in_stock = quantity_in_stock - v_quantity
            WHERE medicine_id = v_medicine_id;
            
        END LOOP;
        
        CLOSE cur_order_details;
    END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------
-- STEP 5: CREATE VIEWS (Unit 2: Views)
-- -----------------------------------------------------------------
-- Views simplify complex queries for the frontend.

-- 1. A View for cleaner stock display
CREATE VIEW Stock_View AS
SELECT
    S.stock_id,
    C.name AS chemical_name,
    S.total_quantity_in_stock_kg,
    S.last_updated
FROM Chemical_In_Stock S
JOIN Raw_Chemicals C ON S.chemical_id = C.chemical_id;

-- 2. A View for cleaner purchase history (JOINs)
CREATE VIEW Chemical_Purchases_View AS
SELECT
    P.purchase_id,
    P.purchase_date,
    C.name AS chemical_name,
    S.name AS supplier_name,
    P.quantity_kg,
    P.price_per_kg_inr
FROM Chemical_Purchases P
JOIN Raw_Chemicals C ON P.chemical_id = C.chemical_id
JOIN Suppliers S ON P.supplier_id = S.supplier_id
ORDER BY P.purchase_date DESC;

-- 3. A View for cleaner sales order history (3-table JOIN)
CREATE VIEW Sales_Orders_View AS
SELECT
    SO.order_id,
    SO.order_date,
    W.name AS wholesaler_name,
    M.name AS medicine_name,
    OD.quantity,
    OD.selling_price_per_unit_inr,
    SO.status
FROM Sales_Orders SO
JOIN Order_Details OD ON SO.order_id = OD.order_id
JOIN Medicines M ON OD.medicine_id = M.medicine_id
JOIN Wholesalers W ON SO.wholesaler_id = W.wholesaler_id
ORDER BY SO.order_date DESC;

-- 4. The ADMIN Profitability Dashboard VIEW (Q1, Q9)
-- This is a very complex view that calculates all your business logic.
CREATE VIEW Admin_Profit_Dashboard AS
SELECT
    M.name AS medicine_name,
    M.medicine_id,
    -- 1. Calculate Raw Material Cost
    (
        SELECT SUM(RC.percentage_composition * 1.0 * COALESCE(avg_prices.avg_price, 0))
        FROM Recipe_Components RC
        LEFT JOIN (
            -- Subquery to get the AVG purchase price of each chemical
            SELECT chemical_id, AVG(price_per_kg_inr) AS avg_price
            FROM Chemical_Purchases
            GROUP BY chemical_id
        ) AS avg_prices ON RC.chemical_id = avg_prices.chemical_id
        WHERE RC.medicine_id = M.medicine_id
    ) AS raw_material_cost_inr,
    
    -- 2. Calculate Selling Price for 60% Gross Margin
    (
        (SELECT raw_material_cost_inr) / (1.0 - 0.60)
    ) AS selling_price_60_margin,
    
    -- 3. Calculate 18% EBITDA (as a target)
    (
        (SELECT selling_price_60_margin) * 0.18
    ) AS ebitda_18_percent
FROM Medicines M;


-- -----------------------------------------------------------------
-- STEP 6: CREATE STORED PROCEDURE (Unit 5: Transactions & ACID)
-- -----------------------------------------------------------------
-- This procedure handles the complex "Produce Medicine" logic
-- as a single, atomic transaction.

DELIMITER $$
CREATE PROCEDURE Produce_Medicine(
    IN p_medicine_id INT,
    IN p_quantity_to_produce INT
)
BEGIN
    -- Declare variables
    DECLARE v_cost_per_unit DECIMAL(10, 2) DEFAULT 0.00;
    DECLARE v_chemical_id INT;
    DECLARE v_percentage DECIMAL(5, 4);
    DECLARE v_kg_required DECIMAL(10, 2);
    DECLARE v_stock_available DECIMAL(10, 2);
    
    -- Declare cursor variables
    DECLARE done INT DEFAULT FALSE;
    
    -- Declare cursor to loop through the medicine's recipe
    DECLARE cur_recipe CURSOR FOR
        SELECT chemical_id, percentage_composition
        FROM Recipe_Components
        WHERE medicine_id = p_medicine_id;
        
    -- Declare handler for NOT FOUND
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- --- 1. START THE TRANSACTION ---
    START TRANSACTION;
    
    -- --- 2. VALIDATION (Check Stock) ---
    -- We must check all ingredients BEFORE consuming any.
    OPEN cur_recipe;
    
    check_loop: LOOP
        FETCH cur_recipe INTO v_chemical_id, v_percentage;
        IF done THEN
            LEAVE check_loop;
        END IF;
        
        -- Calculate how many KG of this chemical are needed
        -- 1 unit = 1 gram, so 1000 units = 1kg
        -- (p_quantity_to_produce / 1000) * percentage = kg required
        SET v_kg_required = (p_quantity_to_produce / 1000.0) * v_percentage;
        
        -- Check if we have enough stock
        SELECT total_quantity_in_stock_kg INTO v_stock_available
        FROM Chemical_In_Stock
        WHERE chemical_id = v_chemical_id;
        
        IF v_stock_available < v_kg_required THEN
            -- NOT ENOUGH STOCK! Abort the transaction.
            ROLLBACK;
            -- Signal an error to the client
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock for all ingredients. Production cancelled.';
        END IF;
        
    END LOOP;
    
    CLOSE cur_recipe;
    SET done = FALSE; -- Reset 'done' for the next loop
    
    -- --- 3. EXECUTION (Consume Stock & Calculate Cost) ---
    -- If we are here, all stock checks passed.
    
    OPEN cur_recipe;
    
    consume_loop: LOOP
        FETCH cur_recipe INTO v_chemical_id, v_percentage;
        IF done THEN
            LEAVE consume_loop;
        END IF;
        
        -- A. Calculate KG required (again)
        SET v_kg_required = (p_quantity_to_produce / 1000.0) * v_percentage;
        
        -- B. Consume the stock (UPDATE DML)
        UPDATE Chemical_In_Stock
        SET total_quantity_in_stock_kg = total_quantity_in_stock_kg - v_kg_required
        WHERE chemical_id = v_chemical_id;
        
        -- C. Add this ingredient's cost to the total batch cost
        -- (using the average price)
        SET v_cost_per_unit = v_cost_per_unit + (
            v_percentage * 1.0 * (
                SELECT AVG(price_per_kg_inr)
                FROM Chemical_Purchases
                WHERE chemical_id = v_chemical_id
            )
        );
        
    END LOOP;
    
    CLOSE cur_recipe;
    
    -- --- 4. LOGGING (Update Finished Goods) ---
    
    -- A. Add the new units to the finished stock
    UPDATE Finished_Medicine_Stock
    SET 
        quantity_in_stock = quantity_in_stock + p_quantity_to_produce,
        last_calculated_cost = v_cost_per_unit
    WHERE medicine_id = p_medicine_id;
    
    -- B. Log this production run
    INSERT INTO Production_Log (medicine_id, quantity_produced, production_date, calculated_cost_per_unit_inr)
    VALUES (p_medicine_id, p_quantity_to_produce, NOW(), v_cost_per_unit);
    
    -- --- 5. COMMIT ---
    -- All steps succeeded. Make the changes permanent.
    COMMIT;
    
END$$
DELIMITER ;

-- -----------------------------------------------------------------
-- STEP 7: Run initial update
-- -----------------------------------------------------------------
-- This manual query will populate the stock table based on the 
-- purchases we inserted, since the trigger only fires on NEW inserts.
-- This is a great way to show you understand how to sync data.
UPDATE Chemical_In_Stock s
SET s.total_quantity_in_stock_kg = (
    SELECT SUM(p.quantity_kg)
    FROM Chemical_Purchases p
    WHERE p.chemical_id = s.chemical_id
    GROUP BY p.chemical_id
);

-- Show a final message
SELECT 'Database setup complete. All tables, views, triggers, and procedures are ready.' AS Status;