-- =============================================
-- Stored Procedure: Process and Enrich Timekeeping Data
-- =============================================

IF OBJECT_ID('dbo.sp_EnrichTimekeepingData', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_EnrichTimekeepingData;
GO

CREATE PROCEDURE dbo.sp_EnrichTimekeepingData
    @ImportBatchID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MatchedCount INT = 0;
    DECLARE @UnmatchedCount INT = 0;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert matched records into enriched table
        INSERT INTO dbo.TimekeepingEnriched (
            ImportBatchID,
            Category,
            ProjectMatter,
            ClientContact,
            ClientEmail,
            ClientFirstName,
            ClientLastName,
            ClientUserID,
            RecordedHours,
            DirectorateNameE,
            DirectorateNameF,
            DirectorateAcronymE,
            DirectorateAcronymF,
            DirectorateID,
            DivisionNameE,
            DivisionNameF,
            DivisionAcronymE,
            DivisionAcronymF,
            DivisionID,
            BranchNameE,
            BranchNameF,
            BranchAcronymE,
            BranchAcronymF,
            BranchID,
            SectionNameE,
            SectionNameF,
            SectionAcronymE,
            SectionAcronymF,
            SectionID,
            ClientPhone,
            PositionLevel,
            IsManager,
            MatchStatus,
            ProcessedDate
        )
        SELECT 
            s.ImportBatchID,
            s.Category,
            s.ProjectMatter,
            s.ClientContact,
            s.ClientEmail,
            s.ClientFirstName,
            s.ClientLastName,
            u.userID,
            s.RecordedHours,
            u.DirectorateNameE,
            u.DirectorateNameF,
            u.DirectorateAcronymE,
            u.DirectorateAcronymF,
            u.DirectorateID,
            u.DivisionNameE,
            u.DivisionNameF,
            u.DivisionAcronymE,
            u.DivisionAcronymF,
            u.DivisionID,
            u.BranchNameE,
            u.BranchNameF,
            u.BranchAcronymE,
            u.BranchAcronymF,
            u.BranchID,
            u.SectionNameE,
            u.SectionNameF,
            u.SectionAcronymE,
            u.SectionAcronymF,
            u.SectionID,
            u.phone,
            u.PositionLevel,
            u.IsManager,
            'Matched',
            GETDATE()
        FROM dbo.TimekeepingStaging s
        LEFT JOIN [BRANCH_Directory].[dbo].[vUserInfo] u 
            ON LOWER(LTRIM(RTRIM(s.ClientEmail))) = LOWER(LTRIM(RTRIM(u.userID)))
            OR (
                LOWER(LTRIM(RTRIM(s.ClientFirstName))) = LOWER(LTRIM(RTRIM(u.firstName)))
                AND LOWER(LTRIM(RTRIM(s.ClientLastName))) = LOWER(LTRIM(RTRIM(u.lastName)))
            )
        WHERE s.ImportBatchID = @ImportBatchID
            AND s.ProcessingStatus = 'Pending'
            AND u.userID IS NOT NULL;
        
        SET @MatchedCount = @@ROWCOUNT;
        
        -- Update staging table status for matched records
        UPDATE s
        SET ProcessingStatus = 'Matched'
        FROM dbo.TimekeepingStaging s
        WHERE s.ImportBatchID = @ImportBatchID
            AND s.ProcessingStatus = 'Pending'
            AND EXISTS (
                SELECT 1 
                FROM dbo.TimekeepingEnriched e 
                WHERE e.ImportBatchID = s.ImportBatchID 
                    AND e.ClientEmail = s.ClientEmail
            );
        
        -- Insert unmatched records into unmatched table
        INSERT INTO dbo.UnmatchedClients (
            ImportBatchID,
            ClientEmail,
            ClientFirstName,
            ClientLastName,
            ClientContact,
            RecordedHours
        )
        SELECT 
            s.ImportBatchID,
            s.ClientEmail,
            s.ClientFirstName,
            s.ClientLastName,
            s.ClientContact,
            s.RecordedHours
        FROM dbo.TimekeepingStaging s
        WHERE s.ImportBatchID = @ImportBatchID
            AND s.ProcessingStatus = 'Pending';
        
        SET @UnmatchedCount = @@ROWCOUNT;
        
        -- Update staging table status for unmatched records
        UPDATE s
        SET ProcessingStatus = 'Unmatched',
            ErrorMessage = 'No matching user found in vUserInfo'
        FROM dbo.TimekeepingStaging s
        WHERE s.ImportBatchID = @ImportBatchID
            AND s.ProcessingStatus = 'Pending';
        
        -- Update import batch summary
        UPDATE dbo.ImportBatch
        SET MatchedRecords = @MatchedCount,
            UnmatchedRecords = @UnmatchedCount,
            ProcessingStatus = 'Completed',
            CompletedDate = GETDATE()
        WHERE BatchID = @ImportBatchID;
        
        COMMIT TRANSACTION;
        
        -- Return summary
        SELECT 
            @ImportBatchID AS BatchID,
            @MatchedCount AS MatchedRecords,
            @UnmatchedCount AS UnmatchedRecords,
            (@MatchedCount + @UnmatchedCount) AS TotalRecords;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Log error
        UPDATE dbo.ImportBatch
        SET ProcessingStatus = 'Error',
            Notes = ERROR_MESSAGE()
        WHERE BatchID = @ImportBatchID;
        
        -- Re-throw error
        THROW;
    END CATCH
END;
GO

PRINT 'Stored procedure created successfully!';
