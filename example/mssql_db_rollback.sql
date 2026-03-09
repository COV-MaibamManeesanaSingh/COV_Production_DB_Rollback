-- 1. SETUP & INITIALIZATION
USE master;

GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'PROD_sales')
    DROP DATABASE PROD_sales;
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RECOVERED_Sales')
    DROP DATABASE RECOVERED_Sales;
GO

CREATE DATABASE PROD_sales;
GO
ALTER DATABASE PROD_sales SET RECOVERY FULL;
GO

-- 2. THE ANCHOR: Initial Full Backup
-- You MUST take this before doing anything else to start the LSN chain properly.
BACKUP DATABASE PROD_sales 
TO DISK = '/var/opt/mssql/backup/full_initial_DB_backup.bak' 
WITH FORMAT, INIT;
GO

-- 3. THE "GOOD" STATE
USE PROD_sales;

CREATE TABLE Orders (
  order_id INT PRIMARY KEY,
  customer_name varchar(30),
  amount DECIMAL(10,2),
  order_date DATETIME NOT NULL,
  created_at DATETIME DEFAULT GETDATE(),
  updated_at DATETIME NULL
);

--- SELECT * From Orders

INSERT INTO Orders (order_id, customer_name, amount, order_date)
VALUES 
(1, 'Alice', 150.00, '2026-03-01 14:00:00.000'),
(2, 'Bob', 200.00, '2026-03-01 16:30:00.000');

-- Capture the "Safe Time"
SELECT GETDATE() AS 'Safe_Point_In_Time'; 
-- Let's assume this returns 2026-03-02 11:40:08.767
GO

-- 4. LOG BACKUP (Captures the Inserts)
BACKUP LOG PROD_sales 
TO DISK = '/var/opt/mssql/backup/before_disaster_log.trn' 
WITH INIT;
GO

-- 5. THE DISASTER

--- SELECT * From Orders
UPDATE Orders SET amount = 0.00; -- Oops!
INSERT INTO Orders (order_id, customer_name, amount, order_date)
VALUES (3, 'Maibam', 500.00, '2026-03-02 16:30:00.000');
GO

-- use PROD_sales
-- SELECT * FROM Orders

-- 6. TAIL LOG BACKUP
-- 1. Force disconnect all users
--ALTER DATABASE PROD_sales 
--SET SINGLE_USER 
--WITH ROLLBACK IMMEDIATE;



USE master;
BACKUP LOG PROD_sales 
TO DISK = '/var/opt/mssql/backup/after_disaster_TailLog.trn' 
WITH NORECOVERY, INIT;

GO

-- 7. THE RECOVERY (TO NEW DB)
RESTORE DATABASE [RECOVERED_Sales]
FROM DISK = '/var/opt/mssql/backup/full_initial_DB_backup.bak'
WITH NORECOVERY,
MOVE 'PROD_sales' TO '/var/opt/mssql/data/RECOVERED_Sales.mdf',
MOVE 'PROD_sales_log' TO '/var/opt/mssql/data/RECOVERED_Sales_log.ldf';

-- Restore first log (The Inserts)
RESTORE LOG [RECOVERED_Sales]
FROM DISK = '/var/opt/mssql/backup/before_disaster_log.trn'
WITH NORECOVERY;

-- Restore tail log (Stopping BEFORE the update)
-- IMPORTANT: Use the time from Step 3 here!
RESTORE LOG [RECOVERED_Sales]
FROM DISK = '/var/opt/mssql/backup/after_disaster_TailLog.trn'
WITH RECOVERY,
STOPAT = '2026-03-02 11:40:08.767'; -- Adjusted to the "Safe_Point_In_Time"
GO

--  RESTORE DATABASE [PROD_Sales] WITH RECOVERY;
-- 8. VERIFY
SELECT * FROM [RECOVERED_Sales].dbo.Orders;


----
-- Setting back DB to normal mode
USE master;
GO
ALTER DATABASE [dbo].[PROD_sales] SET MULTI_USER;
GO

USE master;
GO
ALTER DATABASE [dbo].[RECOVERED_sales] SET MULTI_USER;
GO


SELECT * FROM [PROD_Sales].dbo.Orders;

SELECT * FROM [RECOVERED_Sales].dbo.Orders;



