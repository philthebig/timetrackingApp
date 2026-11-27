-- Keeps the original uploaded spreadsheet so Export All can
-- write that same sheet with Directorate beside Contact Name.
-- The application also creates these objects on the first import or export.

IF COL_LENGTH('dbo.ImportBatch', 'SourceHeaders') IS NULL
    ALTER TABLE dbo.ImportBatch ADD SourceHeaders NVARCHAR(MAX) NULL;
GO

IF OBJECT_ID('dbo.TimekeepingSourceRow', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TimekeepingSourceRow (
        SourceRowID INT IDENTITY(1,1) PRIMARY KEY,
        ImportBatchID INT NOT NULL,
        RowNumber INT NOT NULL,
        SourceData NVARCHAR(MAX) NOT NULL
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_TimekeepingSourceRow_Batch'
    AND object_id = OBJECT_ID('dbo.TimekeepingSourceRow')
)
    CREATE INDEX IX_TimekeepingSourceRow_Batch
    ON dbo.TimekeepingSourceRow(ImportBatchID, RowNumber);
GO
