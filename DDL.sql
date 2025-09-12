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

CREATE VIEW vw_EmployeeDetails AS
SELECT e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID;
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


BEGIN TRANSACTION;
UPDATE Employees SET Salary = Salary * 1.1 WHERE DepartmentID = 2;
IF @@ERROR <> 0
    ROLLBACK TRANSACTION;
ELSE
    COMMIT TRANSACTION;

BEGIN TRY
    INSERT INTO Employees (FirstName, LastName, Salary) VALUES ('Jane', 'Doe', -500);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrNum,
           ERROR_MESSAGE() AS ErrMsg,
           ERROR_LINE() AS ErrLine;
END CATCH;
