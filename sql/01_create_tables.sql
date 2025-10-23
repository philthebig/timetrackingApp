-- =============================================
-- Timekeeping Import and Enrichment System
-- Database Setup Script
-- =============================================

-- Create staging table for imported Excel data
IF OBJECT_ID('dbo.TimekeepingStaging', 'U') IS NOT NULL
    DROP TABLE dbo.TimekeepingStaging;
GO

CREATE TABLE dbo.TimekeepingStaging (
    StagingID INT IDENTITY(1,1) PRIMARY KEY,
    ImportBatchID INT NOT NULL,
    RowNumber INT,
    Category NVARCHAR(255),
    ProjectMatter NVARCHAR(500),
    ClientContact NVARCHAR(1000),
    ClientEmail NVARCHAR(255),
    ClientFirstName NVARCHAR(100),
    ClientLastName NVARCHAR(100),
    RecordedHours DECIMAL(10,2),
    ImportDate DATETIME DEFAULT GETDATE(),
    ProcessingStatus NVARCHAR(50) DEFAULT 'Pending',
    ErrorMessage NVARCHAR(MAX)
);
GO

-- Create enriched timekeeping table (with directorate info)
IF OBJECT_ID('dbo.TimekeepingEnriched', 'U') IS NOT NULL
    DROP TABLE dbo.TimekeepingEnriched;
GO

CREATE TABLE dbo.TimekeepingEnriched (
    RecordID INT IDENTITY(1,1) PRIMARY KEY,
    ImportBatchID INT NOT NULL,
    Category NVARCHAR(255),
    ProjectMatter NVARCHAR(500),
    ClientContact NVARCHAR(1000),
    ClientEmail NVARCHAR(255),
    ClientFirstName NVARCHAR(100),
    ClientLastName NVARCHAR(100),
    ClientUserID NVARCHAR(50),
    RecordedHours DECIMAL(10,2),
    
    -- Directorate Information
    DirectorateNameE NVARCHAR(255),
    DirectorateNameF NVARCHAR(255),
    DirectorateAcronymE NVARCHAR(50),
    DirectorateAcronymF NVARCHAR(50),
    DirectorateID INT,
    
    -- Division Information
    DivisionNameE NVARCHAR(255),
    DivisionNameF NVARCHAR(255),
    DivisionAcronymE NVARCHAR(50),
    DivisionAcronymF NVARCHAR(50),
    DivisionID INT,
    
    -- Branch Information
    BranchNameE NVARCHAR(255),
    BranchNameF NVARCHAR(255),
    BranchAcronymE NVARCHAR(50),
    BranchAcronymF NVARCHAR(50),
    BranchID INT,
    
    -- Section Information
    SectionNameE NVARCHAR(255),
    SectionNameF NVARCHAR(255),
    SectionAcronymE NVARCHAR(50),
    SectionAcronymF NVARCHAR(50),
    SectionID INT,
    
    -- Additional client info
    ClientPhone NVARCHAR(50),
    PositionLevel NVARCHAR(50),
    IsManager BIT,
    
    MatchStatus NVARCHAR(50) DEFAULT 'Matched',
    ImportDate DATETIME DEFAULT GETDATE(),
    ProcessedDate DATETIME
);
GO

-- Create import batch tracking table
IF OBJECT_ID('dbo.ImportBatch', 'U') IS NOT NULL
    DROP TABLE dbo.ImportBatch;
GO

CREATE TABLE dbo.ImportBatch (
    BatchID INT IDENTITY(1,1) PRIMARY KEY,
    FileName NVARCHAR(255) NOT NULL,
    ImportDate DATETIME DEFAULT GETDATE(),
    TotalRecords INT,
    MatchedRecords INT,
    UnmatchedRecords INT,
    ProcessingStatus NVARCHAR(50) DEFAULT 'Processing',
    CompletedDate DATETIME,
    ImportedBy NVARCHAR(100),
    Notes NVARCHAR(MAX)
);
GO

-- Create unmatched clients log
IF OBJECT_ID('dbo.UnmatchedClients', 'U') IS NOT NULL
    DROP TABLE dbo.UnmatchedClients;
GO

CREATE TABLE dbo.UnmatchedClients (
    UnmatchedID INT IDENTITY(1,1) PRIMARY KEY,
    ImportBatchID INT NOT NULL,
    ClientEmail NVARCHAR(255),
    ClientFirstName NVARCHAR(100),
    ClientLastName NVARCHAR(100),
    ClientContact NVARCHAR(1000),
    RecordedHours DECIMAL(10,2),
    ImportDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (ImportBatchID) REFERENCES dbo.ImportBatch(BatchID)
);
GO

-- Create indexes for performance
CREATE INDEX IX_TimekeepingEnriched_DirectorateID ON dbo.TimekeepingEnriched(DirectorateID);
CREATE INDEX IX_TimekeepingEnriched_DivisionID ON dbo.TimekeepingEnriched(DivisionID);
CREATE INDEX IX_TimekeepingEnriched_BranchID ON dbo.TimekeepingEnriched(BranchID);
CREATE INDEX IX_TimekeepingEnriched_ImportBatchID ON dbo.TimekeepingEnriched(ImportBatchID);
CREATE INDEX IX_TimekeepingEnriched_ClientEmail ON dbo.TimekeepingEnriched(ClientEmail);
CREATE INDEX IX_UnmatchedClients_ImportBatchID ON dbo.UnmatchedClients(ImportBatchID);
GO

PRINT 'Tables created successfully!';
