CREATE DATABASE [MyDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'MyDB', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\MyDB.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'MyDB_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\MyDB_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 WITH LEDGER = OFF
GO
ALTER DATABASE [MyDB] SET COMPATIBILITY_LEVEL = 160
GO
ALTER DATABASE [MyDB] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [MyDB] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [MyDB] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [MyDB] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [MyDB] SET ARITHABORT OFF 
GO
ALTER DATABASE [MyDB] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [MyDB] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [MyDB] SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF)
GO
ALTER DATABASE [MyDB] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [MyDB] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [MyDB] SET CURSOR_DEFAULT  LOCAL 
GO
ALTER DATABASE [MyDB] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [MyDB] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [MyDB] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [MyDB] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [MyDB] SET  DISABLE_BROKER 
GO
ALTER DATABASE [MyDB] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [MyDB] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [MyDB] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [MyDB] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [MyDB] SET  READ_WRITE 
GO
ALTER DATABASE [MyDB] SET RECOVERY FULL 
GO
ALTER DATABASE [MyDB] SET  MULTI_USER 
GO
ALTER DATABASE [MyDB] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [MyDB] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [MyDB] SET DELAYED_DURABILITY = DISABLED 
GO
USE [MyDB]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [MyDB] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO

CREATE TABLE dbo.Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    DateOfBirth DATE NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Customers_DateOfBirth CHECK (DateOfBirth <= GETDATE())
);

CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    HireDate DATE,
    Salary DECIMAL(10,2),
    DepartmentID INT
);

ALTER TABLE Employees ADD CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID);
ALTER TABLE Employees ADD CONSTRAINT UQ_Email UNIQUE (Email);
ALTER TABLE Employees ADD CONSTRAINT CK_Salary CHECK (Salary > 0);

-- Alter table
ALTER TABLE Employees ADD Email NVARCHAR(100);
ALTER TABLE Employees DROP COLUMN Email;
ALTER TABLE Employees ALTER COLUMN LastName NVARCHAR(100);
GO
/*
CREATE TABLE schema_name.table_name (
    column_name data_type [ (precision [, scale]) ] [ NULL | NOT NULL ]
        [ IDENTITY(seed, increment) ]
        [ PRIMARY KEY | UNIQUE ]
        [ DEFAULT default_value ]
        [ CHECK (logical_expression) ]
        [ FOREIGN KEY REFERENCES other_table(column_name) ],
    -- more columns ...
    
    [ CONSTRAINT constraint_name PRIMARY KEY (column1, column2, ...) ],
    [ CONSTRAINT constraint_name FOREIGN KEY (column_name) REFERENCES other_table(column_name) ],
    [ CONSTRAINT constraint_name CHECK (logical_expression) ],
    [ CONSTRAINT constraint_name UNIQUE (column_name) ]
);
*/

-- Create login
CREATE LOGIN MyLogin WITH PASSWORD = 'StrongP@ssword123';
-- Create user
CREATE USER MyUser FOR LOGIN MyLogin;

-- Grant permissions
GRANT SELECT, INSERT ON Employees TO MyUser;

-- Revoke: after GRANT
REVOKE INSERT ON Employees FROM MyUser;

-- Deny: blocks regardless of GRANT before or after
DENY DELETE ON Employees TO MyUser;
--You must remove the DENY first:
REVOKE DENY SELECT ON Employees TO UserA;  -- removes the deny
GRANT SELECT ON Employees TO UserA;        -- now grant works
GO

/*
When you run CREATE PROCEDURE, SQL Server does a syntactic parse of the T-SQL text,
but it does not fully validate object names (tables, columns, etc.) at that point.
By default, SQL Server defers validation of schema elements until execution time.
CREATE PROCEDURE BadProc AS
BEGIN
    SELECT NonExistentColumn FROM Accounts; -- column doesn't exist
END;
GO
-- Procedure is created successfully
EXEC BadProc;  -- Runtime error: "Invalid column name 'NonExistentColumn'"

Can do
CREATE PROCEDURE BadProc WITH SCHEMABINDING AS
Same schema-qualification requirements.
Ensures that if you try to change the table definition, you’ll have to drop/alter the function first.

Use sp_refreshsqlmodule or static analysis tools to validate stored procedure dependencies after deployment.
*/

CREATE VIEW vw_EmployeeDetails
AS
SELECT e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID;
GO

-- Trigger
--AFTER, INSTEAD OF.
--inserted, deleted pseudo-tables hold affected rows.
CREATE TRIGGER trg_Audit
ON Employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Example: Insert audit log entry
    INSERT INTO AuditLog (EmpID, ActionType, ActionDate)
    SELECT EmployeeID, 'INSERT/UPDATE/DELETE', GETDATE()
    FROM inserted;
END;
GO

-- No FOR EACH ROW trigger like Oracle
-- To achieve row-level logic, you must explicitly handle it by joining inserted and deleted pseudo-tables,
-- which can contain multiple rows.

CREATE TRIGGER trg_emp_audit
ON Employees
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO emp_audit (emp_id, old_sal, new_sal)
    SELECT d.EmpID, d.Salary, i.Salary
    FROM deleted d
    JOIN inserted i ON d.EmpID = i.EmpID
    WHERE d.Salary <> i.Salary; -- only log real changes
END;
GO

-- Stored procedure
CREATE PROCEDURE GetEmployeesByDept @DeptID INT
AS
BEGIN
    SELECT * FROM Employees WHERE DepartmentID = @DeptID;
END;
GO
EXEC GetEmployeesByDept @DeptID = 1;
GO
-- Function (scalar)
CREATE FUNCTION GetFullName (@First NVARCHAR(50), @Last NVARCHAR(50))
RETURNS NVARCHAR(101)
AS
BEGIN
    RETURN @First + ' ' + @Last;
END;
GO
SELECT dbo.GetFullName(FirstName, LastName) FROM Employees;
GO

-- Table valued function: single statement, prefered
CREATE FUNCTION fn_EmployeesByDept (@DeptID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT EmployeeID, FirstName, Salary
    FROM Employees
    WHERE DepartmentID = @DeptID
);
GO
-- Usage
SELECT * FROM fn_EmployeesByDept(10);
GO

-- Table valued function: multi statement, only when you need complex logic that can’t fit in one query
CREATE FUNCTION fn_EmployeesSummary (@DeptID INT)
RETURNS @Result TABLE
(
    EmployeeID INT,
    Salary INT,
    SalaryCategory VARCHAR(20)
)
AS
BEGIN
    INSERT INTO @Result
    SELECT EmployeeID, Salary,
           CASE 
               WHEN Salary < 5000 THEN 'Low'
               WHEN Salary BETWEEN 5000 AND 7000 THEN 'Medium'
               ELSE 'High'
           END
    FROM Employees
    WHERE DepartmentID = @DeptID;

    RETURN;
END;
GO
--Use
SELECT * FROM fn_EmployeesSummary(10);


SELECT EmployeeID, DepartmentID, Salary,
       SUM(Salary)  -- analytic function
                    -- Ranking functions
                    -- ROW_NUMBER() Unique sequential number per row
                    -- RANK() Ranks rows, gaps if ties
                    -- DENSE_RANK() Ranks rows, no gaps for ties
                    -- NTILE(n) Divides rows into n buckets
                    -- Aggregate Functions
                    -- SUM(column) Cumulative or partitioned sum
                    -- AVG(column) Cumulative or partitioned average
                    -- COUNT(column) Running or partitioned count
                    -- MAX/MIN(column) Running or partitioned min/max
                    -- Offset functions
                    -- LAG(column, offset, default)	Access previous row value
                    -- LEAD(column, offset, default) Access next row value
                    -- offset = number of rows before/after (default 1)
                    -- default = value if row doesn’t exist
       OVER (      -- windowing clause
           PARTITION BY DepartmentID   -- partition
           ORDER BY EmployeeID         -- ordering
           ROWS BETWEEN 1 PRECEDING AND CURRENT ROW  --framing ROWS BETWEEN or RANGE BETWEEN
                                                     --UNBOUNDED PRECEDING → goes all the way left.
                                                     --N PRECEDING → limited number of rows to the left.
                                                     --CURRENT ROW → just this row.
                                                     --N FOLLOWING → limited number of rows to the right.
                                                     --UNBOUNDED FOLLOWING → all the way right.
       ) AS RunningTotal
FROM Employees;


/*
<analytic function> OVER ( [ PARTITION BY column1, column2, ... ] 
       [ ORDER BY column1 [ASC|DESC], ... ] 
       [ ROWS | RANGE frame_specification ] )
*/



-- Row numbering
SELECT EmployeeID, FirstName, Salary,
       ROW_NUMBER() OVER (ORDER BY Salary DESC) AS RowNum
FROM Employees;

-- Ranking
SELECT EmployeeID, Salary,
       RANK() OVER (ORDER BY Salary DESC) AS Rank,
       DENSE_RANK() OVER (ORDER BY Salary DESC) AS DenseRank
FROM Employees;

-- Running totals
SELECT EmployeeID, Salary,
       SUM(Salary) OVER (ORDER BY EmployeeID) AS RunningTotal
FROM Employees;

-- Partition
SELECT DepartmentID, Salary,
       AVG(Salary) OVER (PARTITION BY DepartmentID) AS DeptAvg
FROM Employees;


SELECT EmployeeID, DepartmentID, Salary,
       SUM(Salary) 
       OVER (
           PARTITION BY DepartmentID
           ORDER BY EmployeeID
           ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
       ) AS RunningTotal
FROM Employees;

-- useful functions
SELECT GETDATE(), SYSDATETIME();
SELECT SUSER_NAME(), USER_NAME(); -- log in,db user name
SELECT CAST(123.45 AS INT), CONVERT(VARCHAR, GETDATE(), 120);
SELECT LEN('Hello'), UPPER('hello'), LOWER('HELLO'), LTRIM('  hi  '), RTRIM('hi  ');
SELECT ISNULL(NULL, 'Default'), COALESCE(NULL, NULL, 'FirstNotNull');


-- Cursor
-- cursors are nor updatable when
-- declared as READ_ONLY, FAST_FORWARD, STATIC (DYNAMIC and KEYSET are updatable)
-- the SELECT Query is Non-Updatable (use FOR UPDATE OF to make updatable):
    --Query uses a JOIN (multiple tables)
    --Query has DISTINCT, GROUP BY, HAVING, UNION, ORDER BY.
    --Query references a view without an INSTEAD OF trigger.
    --Query selects from a read-only database or filegroup.
    --Query includes computed columns, aggregate functions, or subqueries.

DECLARE myCursor CURSOR LOCAL FAST_FORWARD FOR SELECT EmployeeID, Salary FROM Employees;
-- Use LOCAL FAST_FORWARD cursors for efficiency, not updatable, fastest
-- Forward-only: Default, can only move forward.
-- Static: Takes a snapshot, no changes visible. Can scroll forward and backward
-- Dynamic: Reflects changes in underlying data. Can scroll forward and backward
-- Keyset: Fixed set of rows, but values can change.
    -- Creates a set of keys (primary keys/unique identifiers) at cursor open time.
    -- Membership of rows is fixed → new inserts won’t appear, deletes are removed.
    -- But updates to existing rows are visible.
    -- Can scroll forward and backward.
OPEN myCursor;
FETCH NEXT FROM myCursor INTO @EmpID, @Salary;
-- Can FETCH NEXT/PREVIOUS/FIRST/LAST
WHILE @@FETCH_STATUS = 0  -- (0 = success, -1 = no row, -2 = row missing).
BEGIN
    -- Do something with @EmpID, @Salary
    FETCH NEXT FROM myCursor INTO @EmpID, @Salary;
END
CLOSE myCursor;  --release current result set
DEALLOCATE myCursor;  --free resources


-- Updating cursor
DECLARE cur CURSOR KEYSET FOR
SELECT e.EmployeeID, e.Salary
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
FOR UPDATE OF Salary;   -- Need FOR UPDATE if
                        -- Query is not updatable and you want to use WHERE CURRENT OF
                        -- When you want to restrict which columns 
                        -- (If FOR UPDATE without the column list, all columns in the cursor may be updatable)
OPEN cur;

-- Update using WHERE CURRENT OF, nice but only works with updatable cursor
FETCH NEXT FROM cur;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE Employees SET Salary = Salary * 1.10 WHERE CURRENT OF cur;   -- ✅ Works if FOR UPDATE but fails without it
    FETCH NEXT FROM cur;
END

-- Alternately, update using PK, works with any cursor type
DECLARE @EmpID INT, @Sal DECIMAL(10,2);
FETCH NEXT FROM cur INTO @EmpID, @Sal;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Update using the primary key instead of CURRENT OF
    UPDATE Employees SET Salary = Salary * 1.10 WHERE EmployeeID = @EmpID;
    FETCH NEXT FROM cur INTO @EmpID, @Sal;
END

CLOSE cur;
DEALLOCATE cur;




/*
Nested Transactions
===================
SQL Server doesn’t support true nested transactions (like Oracle).
Each BEGIN TRAN increments a counter: @@TRANCOUNT.
Each COMMIT TRAN decrements the counter.
But ROLLBACK TRAN resets @@TRANCOUNT to 0, no matter how many nested levels you had.
So there’s really only one transaction scope — nesting is only a counter illusion.

Pattern: Only the Outer Procedure Controls the Transaction
Outer procedure is responsible for starting, committing, or rolling back the transaction.
If you need an inner procedure to undo only its own work without affecting outer work,
use SAVE TRANSACTION savepoint_name and ROLLBACK TRANSACTION savepoint_name.
*/


/*
Error Categories
================
1. Statement-terminating errors: Only the current statement fails.
Examples: Constraint violation, zero div (8134), conv error (245), RAISERROR with severity 11–19
Note on RAISERROR with severity 11–19: Considered user-correctable runtime errors. SQL Server treats them the same as other runtime
statement-terminating errors like PK/FK violations, divide-by-zero.

BEGIN TRY
    BEGIN TRAN;
    INSERT INTO Orders(OrderID, CustomerID) VALUES (1, 9999); -- invalid FK
    COMMIT;
END TRY
BEGIN CATCH
    SELECT @@TRANCOUNT AS TranCount, XACT_STATE() AS TranState;
END CATCH;

Flow: The batch continues unless you’re in a TRY…CATCH, in which case control moves to CATCH.
Transaction: If inside an explicit transaction:
With XACT_ABORT ON → the entire transaction is rolled back automatically.
    @@TRANCOUNT = 1 (transaction closed), XACT_STATE() = 0 (no active transaction)
With XACT_ABORT OFF → transaction remains active, but may be in an uncommittable state (XACT_STATE() = -1).
    @@TRANCOUNT = 1 (transaction still open), XACT_STATE() = -1 (uncommittable, must ROLLBACK)
--------------------------------------------------------------------------------------------------------------------------------
2. Batch-aborting / transaction-aborting errors: End not just the statement, but the entire batch or the active transaction.
Examples:
Syntax errors (compile time) SELEX * FROM ...: Query never makes it into execution — SQL Server fails before the TRY block can start.
Deferred name resolution errors (execution time) SELECT BadColumn FROM dbo.Employees: Considered a compile-time/batch-abort, not a run-time error.
Errors that explicitly abort a batch: DBCC CHECKIDENT with bad arguments, Some SET options invalid in context, KILL command
Severe constraint metadata corruption, Explicit SET OFFSETS/COMPILE issues

SET XACT_ABORT OFF; -- or ON
BEGIN TRY
    BEGIN TRAN;
    SELECT BadColumn FROM Employees; -- invalid column
    COMMIT;
END TRY
BEGIN CATCH --@@TRANCOUNT stays as-is, but you never reach CATCH to check it
    SELECT @@TRANCOUNT AS TranCount, XACT_STATE() AS TranState;
    ROLLBACK;
END CATCH;

Flow: Control does not pass to CATCH in some cases (batch stops immediately)
Transaction: XACT_ABORT doesn’t apply, ON and OFF the same. The batch aborts immediately. @@TRANCOUNT stays as-is, but you never reach CATCH to check it
Connection may remain alive or may be killed, depending on severity.
--------------------------------------------------------------------------------------------------------------------------------
3. Connection-terminating (Severity ≥ 20)
Example: serious system-level error, network, RAISERROR('Fatal error', 20, 1) WITH LOG; -- sysadmin required
Flow: Kill the entire session/connection. No CATCH possible — session ends immediately.
Transaction: Rolled back automatically by SQL Server engine.

Summary of interaction with CATCH
Statement-terminating errors → If no TRY CATCH, continue, otherwise jump to CATCH block.
Batch-aborting errors → Skip CATCH, batch stops immediately.
Connection-terminating errors → No chance for CATCH, connection gone.
*/

-- error handling
-- Before SQL Server 2005, you had to check @@ERROR after every statement.
-- Don’t use it in new code — TRY…CATCH is much better.
-- try catch 

/*
With XACT_ABORT ON, when an error occurs inside a TRY, SQL Server:
Rolls back the transaction automatically for most run-time errors.
Transfers control into the CATCH block.
By the time your code runs inside CATCH, the transaction is already gone (@@TRANCOUNT = 0).
*/

/*
With XACT_ABORT OFF: FK violation jumps to CATCH.
Transaction is still open → you must ROLLBACK (because it’s in an “uncommittable” state: XACT_STATE() = -1).
With XACT_ABORT ON: FK violation also jumps to CATCH.
But SQL Server already rolled back the transaction before entering CATCH (@@TRANCOUNT = 0).
*/

/*
XACT_ABORT ON
    Errors that it rolls back:
        Divide by zero, Arithmetic overflow, Conversion errors (e.g., CAST('abc' AS INT))
        Constraint violations (primary key, foreign key, check)
        Deadlock victim
        Explicit THROW inside a transaction
        User-defined RAISERROR with severity 11–19
        Network-level errors, Severe system-level errors (severity 20+), E.g., memory allocation failure
    Errors that it does not roll back:
        Compile-time errors: Syntax errors, Invalid object/column names at creation time
        RAISERROR with severity ≤ 10: These are informational messages, not considered run-time errors, so no rollback occurs
        login errors
        Errors that terminate the connection: SQL Server always rolls back, but not via XACT_ABORT. It’s handled by the engine itself.
*/

/*
                                                                    SET XACT_ABORT ON roll backs                  CATCH
Errors that it rolls back:
    Div by zero, Ari overflow, Convert/cast                                        Y                               Y
    Constraint violations                                                          Y                               Y
    Deadlock victim                                                                Y                               Y
    Explicit THROW inside a transaction                                            Y                               Y
    User-defined RAISERROR with severity 11–19                                     Y                               Y
    Network-level errors,                                                          Y                               N
    Severe system-level errors (severity 20+), E.g., memory alloc                  Y                               N
    Errors that terminate the connection: SQL Server always rolls back,            Y but by DB engine              N
    but not via XACT_ABORT. It’s handled by the engine itself.
Errors that it does not roll back:
    Compile-time errors: Syntax, Invalid object/column names at creation           N                               N
    RAISERROR with severity ≤ 10: info, not considered run-time errors             N                               N
    login errors
*/

BEGIN TRANSACTION;

-- Before SQL Server 2005
UPDATE Employees SET Salary = Salary * 1.1 WHERE DepartmentID = 2;
IF @@ERROR <> 0
    ROLLBACK TRANSACTION;
ELSE
    COMMIT TRANSACTION;

-- Now use TRY CATCH and SET XACT_ABORT ON
-- Best Practice Template
SET XACT_ABORT ON;  -- should use this, rollback automatically on error
                    -- Without XACT_ABORT ON, behavior depends on the type of error (some abort immediately, some don’t).
                    -- With XACT_ABORT ON, all run-time errors behave the same way: rollback + jump to CATCH.
                    -- SET XACT_ABORT is a session-level setting, not local to a procedure
BEGIN TRY
    BEGIN TRAN;
    -- your work
    COMMIT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrNum,
        ERROR_MESSAGE() AS ErrMsg,
        ERROR_LINE() AS ErrLine;
    IF @@TRANCOUNT > 0
        ROLLBACK;   -- still needed!
    THROW;          -- rethrow for caller
END CATCH
GO



-- Error handling template
CREATE PROCEDURE TransferFunds
    @FromAcc INT,
    @ToAcc INT,
    @Amount DECIMAL(10,2)
AS
BEGIN
    SET XACT_ABORT ON; -- should use this, rollback automatically on error
    --Why XACT_ABORT ON Matters Even with a CATCH Rollback:
    --0. Error Consistency
    --Without XACT_ABORT ON, behavior depends on the type of error (some abort immediately, some don’t).
    --With XACT_ABORT ON, all run-time errors behave the same way:
    --→ rollback + jump to CATCH.
    --1. Not All Errors Go to the CATCH Block
    --Certain errors in SQL Server do not transfer control to CATCH at all.
    --Compilation errors (bad column names, syntax issues).
    --Some constraint violations inside multi-statement batches.
    --Without XACT_ABORT ON, those errors may leave the transaction open and uncommittable (“doomed”).
    --2. Non-fatal Errors Don’t Abort Execution
    --Without XACT_ABORT, if a non-fatal error occurs (e.g., a foreign key violation), SQL Server:
    --Cancels that one statement, Leaves the transaction open, Moves on to the next statement in the TRY block.
    --The CATCH block may not run at all → leaving you with a partially applied transaction.

    --Does XACT_ABORT ON Make the ROLLBACK in CATCH Redundant?
    --No, you should not omit it — even if XACT_ABORT ON is enabled.
    --1. XACT_ABORT ON rolls back automatically, but only for some errors
    --When a run-time error occurs with XACT_ABORT ON, SQL Server immediately rolls back the current transaction.
    --However, if you were already in a nested transaction (or a caller procedure had started the transaction), the outer scope will still see a non-zero @@TRANCOUNT.
    --2. Consistency of Error Handling
    --Including IF @@TRANCOUNT > 0 ROLLBACK; in every CATCH block ensures:
    --No matter how the procedure was called (stand-alone vs inside another transaction), the procedure always cleans up its own mess.
    --Without it, you could leave the session in an “in-doubt” state, blocking future statements until the caller rolls back.

    --Best Practice Template
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        -- your work
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;   -- still needed!
        THROW;          -- rethrow for caller
    END CATCH


    -- Before SQL Server 2005, you had to check @@ERROR after every statement.
    -- Don’t use it in new code — TRY…CATCH is much better.
    BEGIN TRY
        IF @Amount <= 0
            THROW 50001, 'Amount must be greater than zero', 1;
            -- Use THROW Instead of RAISERROR
            -- RAISERROR is legacy for backward compatibility, but less clean.
            -- RAISERROR('Something went wrong', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM Accounts WHERE AccID = @FromAcc)
            THROW 50002, 'Source account does not exist', 1;

        IF NOT EXISTS (SELECT 1 FROM Accounts WHERE AccID = @ToAcc)
            THROW 50003, 'Target account does not exist', 1;

        IF (SELECT Balance FROM Accounts WHERE AccID = @FromAcc) < @Amount
            THROW 50004, 'Insufficient funds', 1;

        BEGIN TRANSACTION;

        UPDATE Accounts WITH (ROWLOCK, XLOCK)
        SET Balance = Balance - @Amount
        WHERE AccID = @FromAcc;

        UPDATE Accounts WITH (ROWLOCK, XLOCK)
        SET Balance = Balance + @Amount
        WHERE AccID = @ToAcc;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- check to avoid avoid rolling back when there’s no transaction open 
                                                 -- (otherwise, it raises an error)
        THROW; -- rethrow original error
        -- RAISERROR creates a new error → you lose the original error context unless you log and rebuild it.
    END CATCH
END;
GO

/*
Best Practice Pattern
1. Let inner procs just THROW
Inner procedures shouldn’t “rewrite” errors; they should just bubble them up.
Keeps them reusable and focused.

2. Outer (top-level) procedure formats the error
Catch the error.
Collect error details with ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE().
Re-throw with a custom error number and a user-friendly message.
Use error numbers ≥ 50000 for custom app errors.
Keep original message appended for troubleshooting.

3. Log full error details somewhere (audit table, error log) if the app hides details from the end-user.
*/

/*🔹 How SQL Server treats error codes
1. System-defined errors (below 50000)
These are built-in SQL Server errors (e.g., divide by zero = 8134, deadlock victim = 1205).
They have predefined severity, messages, and behavior.
You cannot redefine or override them.

2. User-defined errors (50000 and above)
Reserved for application/business logic.
When you use THROW or RAISERROR with a number ≥ 50000, SQL Server interprets it as a custom error.
Behavior:
THROW always raises them at severity 16 (general user error).
RAISERROR lets you specify severity (e.g., 10–25), but 16 is most common.
They do not have built-in meanings — only what your application assigns.
*/

-- Inner procedure: does NOT start or commit/rollback
CREATE PROCEDURE InnerProc
AS
BEGIN
    BEGIN TRY
        -- Business logic
        UPDATE Employees SET Salary = Salary * 1.1;
    END TRY
    BEGIN CATCH
        -- Log and rethrow only
        INSERT INTO ErrorLog (ErrMsg) VALUES (ERROR_MESSAGE());
        THROW;
    END CATCH
END;
GO

-- Outer procedure: controls transaction
CREATE PROCEDURE OuterProc
AS
BEGIN
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC InnerProc; -- may throw

        -- more logic
        UPDATE Departments SET Budget = Budget - 1000;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- use SAVE TRANSACTION savepoint_name and ROLLBACK TRANSACTION savepoint_name.
CREATE PROCEDURE InnerWithSavepoint
AS
BEGIN
    SAVE TRANSACTION InnerSave;

    BEGIN TRY
        -- risky operation
        UPDATE Employees SET Salary = -1; -- invalid
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION InnerSave; -- rollback to before this proc
        THROW;
    END CATCH
END;
GO

--Detect if Caller Already Has a Transaction
-- Sometimes you want a procedure to optionally join a caller’s transaction. Use @@TRANCOUNT to detect
CREATE PROCEDURE DoSomething
AS
BEGIN
    DECLARE @StartTranCount INT = @@TRANCOUNT;
    DECLARE @LocalTran BIT = 0;

    IF @StartTranCount = 0
    BEGIN
        BEGIN TRANSACTION;  -- only start if none exists
        SET @LocalTran = 1;
    END

    BEGIN TRY
        -- your logic here
        UPDATE Accounts SET Balance = Balance - 100;

        IF @LocalTran = 1
            COMMIT TRANSACTION;  -- commit only if we started it
    END TRY
    BEGIN CATCH
        IF @LocalTran = 1 AND @@TRANCOUNT > 0
            ROLLBACK TRANSACTION; -- rollback only if we started it
        THROW;
    END CATCH
END;
GO

/*
Reporting error
Best Practice Pattern for Nested Procedures
Inner Procedure (B)
Use SAVE TRANSACTION instead of starting its own transaction.
Roll back only its part if something goes wrong.
Rethrow the error for the caller to decide final handling.
Outer Procedure (A)
Responsible for the real transaction scope.
Calls inner procs, lets them rethrow errors.
On error, it performs full rollback and returns a meaningful message to the client.
*/

CREATE PROCEDURE ProcB AS
BEGIN
    SET XACT_ABORT ON;

    SAVE TRANSACTION ProcBSave;  -- marks rollback point

    BEGIN TRY
        -- Some risky DML
        UPDATE Accounts SET Balance = Balance - 100 WHERE AccID = 1;
        UPDATE Accounts SET Balance = Balance + 100 WHERE AccID = 999; -- bad FK
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION ProcBSave;  -- undo only this part
        THROW;  -- bubble up error
    END CATCH
END;
GO

CREATE PROCEDURE ProcA AS
BEGIN
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC ProcB;   -- inner work
        EXEC ProcC;   -- another inner proc

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE 
            @ErrMsg NVARCHAR(4000),
            @ErrSeverity INT,
            @ErrState INT;

        SELECT 
            @ErrMsg = ERROR_MESSAGE(),
            @ErrSeverity = ERROR_SEVERITY(),
            @ErrState = ERROR_STATE();

        -- Return a meaningful message to client
        THROW 50001, 'Transfer failed: ' + @ErrMsg, 1;
    END CATCH
END;

CREATE TABLE ErrorCatalog (
    ErrorCode INT PRIMARY KEY,
    ErrorName SYSNAME NOT NULL,
    ErrorMessage NVARCHAR(2048) NOT NULL
);

INSERT INTO ErrorCatalog VALUES
(50001, 'InsufficientFunds', 'Transfer failed: insufficient funds.'),
(50002, 'InvalidAccount',    'Transfer failed: account not found.');

/*
public enum SqlErrorCodes
{
    InsufficientFunds = 50001,
    InvalidAccount = 50002
}

catch (SqlException ex) when (ex.Number == (int)SqlErrorCodes.InsufficientFunds)
{
    // handle business logic
}

For large systems → maintain a central ErrorCatalog in the database + application-level constants.

For small systems → at least reserve a number range and keep constants in app code.

Never scatter THROW 50001, '...' everywhere — that’s a maintenance headache.
*/