-- =============================================
-- Views for Dashboard Statistics
-- =============================================

-- View: Hours by Directorate
IF OBJECT_ID('dbo.vw_HoursByDirectorate', 'V') IS NOT NULL
    DROP VIEW dbo.vw_HoursByDirectorate;
GO

CREATE VIEW dbo.vw_HoursByDirectorate
AS
SELECT 
    DirectorateID,
    DirectorateNameE,
    DirectorateNameF,
    DirectorateAcronymE,
    DirectorateAcronymF,
    COUNT(DISTINCT ClientEmail) AS UniqueClients,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours,
    AVG(RecordedHours) AS AvgHoursPerProject,
    MIN(ImportDate) AS FirstImportDate,
    MAX(ImportDate) AS LastImportDate
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
GROUP BY 
    DirectorateID,
    DirectorateNameE,
    DirectorateNameF,
    DirectorateAcronymE,
    DirectorateAcronymF;
GO

-- View: Hours by Division
IF OBJECT_ID('dbo.vw_HoursByDivision', 'V') IS NOT NULL
    DROP VIEW dbo.vw_HoursByDivision;
GO

CREATE VIEW dbo.vw_HoursByDivision
AS
SELECT 
    DirectorateID,
    DirectorateNameE,
    DivisionID,
    DivisionNameE,
    DivisionNameF,
    DivisionAcronymE,
    DivisionAcronymF,
    COUNT(DISTINCT ClientEmail) AS UniqueClients,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours,
    AVG(RecordedHours) AS AvgHoursPerProject
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
GROUP BY 
    DirectorateID,
    DirectorateNameE,
    DivisionID,
    DivisionNameE,
    DivisionNameF,
    DivisionAcronymE,
    DivisionAcronymF;
GO

-- View: Hours by Branch
IF OBJECT_ID('dbo.vw_HoursByBranch', 'V') IS NOT NULL
    DROP VIEW dbo.vw_HoursByBranch;
GO

CREATE VIEW dbo.vw_HoursByBranch
AS
SELECT 
    DirectorateID,
    DirectorateNameE,
    BranchID,
    BranchNameE,
    BranchNameF,
    BranchAcronymE,
    BranchAcronymF,
    COUNT(DISTINCT ClientEmail) AS UniqueClients,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours,
    AVG(RecordedHours) AS AvgHoursPerProject
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
GROUP BY 
    DirectorateID,
    DirectorateNameE,
    BranchID,
    BranchNameE,
    BranchNameF,
    BranchAcronymE,
    BranchAcronymF;
GO

-- View: Hours by Category
IF OBJECT_ID('dbo.vw_HoursByCategory', 'V') IS NOT NULL
    DROP VIEW dbo.vw_HoursByCategory;
GO

CREATE VIEW dbo.vw_HoursByCategory
AS
SELECT 
    Category,
    COUNT(DISTINCT ClientEmail) AS UniqueClients,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours,
    AVG(RecordedHours) AS AvgHoursPerProject,
    COUNT(DISTINCT DirectorateID) AS DirectoratesInvolved
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
    AND Category IS NOT NULL
GROUP BY Category;
GO

-- View: Top Clients by Hours
IF OBJECT_ID('dbo.vw_TopClientsByHours', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TopClientsByHours;
GO

CREATE VIEW dbo.vw_TopClientsByHours
AS
SELECT 
    ClientEmail,
    ClientFirstName,
    ClientLastName,
    DirectorateNameE,
    DivisionNameE,
    BranchNameE,
    PositionLevel,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours,
    AVG(RecordedHours) AS AvgHoursPerProject
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
GROUP BY 
    ClientEmail,
    ClientFirstName,
    ClientLastName,
    DirectorateNameE,
    DivisionNameE,
    BranchNameE,
    PositionLevel;
GO

-- View: Import Batch Summary
IF OBJECT_ID('dbo.vw_ImportBatchSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ImportBatchSummary;
GO

CREATE VIEW dbo.vw_ImportBatchSummary
AS
SELECT 
    b.BatchID,
    b.FileName,
    b.ImportDate,
    b.TotalRecords,
    b.MatchedRecords,
    b.UnmatchedRecords,
    CASE 
        WHEN b.TotalRecords > 0 
        THEN CAST(b.MatchedRecords AS FLOAT) / b.TotalRecords * 100 
        ELSE 0 
    END AS MatchPercentage,
    b.ProcessingStatus,
    b.CompletedDate,
    b.ImportedBy,
    DATEDIFF(SECOND, b.ImportDate, ISNULL(b.CompletedDate, GETDATE())) AS ProcessingTimeSeconds
FROM dbo.ImportBatch b;
GO

-- View: Directorate Comparison (for period analysis)
IF OBJECT_ID('dbo.vw_DirectorateComparison', 'V') IS NOT NULL
    DROP VIEW dbo.vw_DirectorateComparison;
GO

CREATE VIEW dbo.vw_DirectorateComparison
AS
SELECT 
    DirectorateNameE,
    DirectorateAcronymE,
    YEAR(ImportDate) AS ImportYear,
    MONTH(ImportDate) AS ImportMonth,
    COUNT(DISTINCT ClientEmail) AS UniqueClients,
    COUNT(*) AS TotalProjects,
    SUM(RecordedHours) AS TotalHours
FROM dbo.TimekeepingEnriched
WHERE MatchStatus = 'Matched'
GROUP BY 
    DirectorateNameE,
    DirectorateAcronymE,
    YEAR(ImportDate),
    MONTH(ImportDate);
GO

PRINT 'Dashboard views created successfully!';
