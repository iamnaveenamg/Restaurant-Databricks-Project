/**
 * CONTRIBUTION NOTE:
 * If you edit this file, create a ticket for the Doc Team to update the public-facing script
 *  - Project: Documentation (DOC)
 *  - Component: Ingestion
 *  - Label: lakeflow-connect-docs
 *
 * SQL Server Utility Objects Script for Databricks Lakeflow Connect
 * Version 1.1
 *
 * This script creates versioned utility stored procedures that can be used
 * to automatically remediate common SQL Server setup issues for ingestion.
 *
 * FEATURES:
 * - Automatic table discovery with @Tables = 'ALL', 'SCHEMAS:Sales,HR', wildcards
 * - Smart CT/CDC selection based on primary key presence
 * - Table-level CT/CDC enablement and DDL support objects
 * - Multi-platform detection and optimization
 * - Idempotent
 *
 * Platform Support:
 * - On-premises SQL Server
 * - Azure SQL Database
 * - Azure SQL Managed Instance
 * - Amazon RDS for SQL Server
 *
 */

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN
    PRINT N'Starting Lakeflow Connect Utility Objects installation...';
    PRINT N'Version: 1.1';
    PRINT N'Catalog: ' + DB_NAME();
    PRINT N'Executed by: ' + SUSER_NAME();
    PRINT N'Date/Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT N'';

    -- Detect platform
    DECLARE @engineEdition INT = CAST(SERVERPROPERTY('EngineEdition') AS INT);
    DECLARE @serverName NVARCHAR(255) = @@SERVERNAME;
    DECLARE @currentPlatform NVARCHAR(50);

    IF @engineEdition = 5
        SET @currentPlatform = 'AZURE_SQL_DATABASE';
    ELSE
        IF @engineEdition = 8
            SET @currentPlatform = 'AZURE_SQL_MANAGED_INSTANCE';
        ELSE
            IF @serverName LIKE '%.rds.amazonaws.com'
                SET @currentPlatform = 'AMAZON_RDS';
            ELSE
                IF @engineEdition IN (1, 2, 3, 4)
                    SET @currentPlatform = 'ON_PREMISES';
                ELSE
                    SET @currentPlatform = 'UNKNOWN';

    PRINT N'Detected platform: ' + @currentPlatform;

    -- Validate that current user has sufficient privileges
    IF (IS_ROLEMEMBER('db_owner') = 0)
        BEGIN
            RAISERROR ('User executing this script is not a ''db_owner'' role member. To execute this script, please use a user that is a member of the db_owner role.', 16, 1);
            RETURN;
        END

    -- Cleanup existing objects
    PRINT N'Cleaning up existing utility objects (all versions)...';

    DECLARE @dropSql NVARCHAR(MAX) = '';

    -- Drop lakeflowFixPermissions procedures
    SELECT @dropSql = @dropSql + 'DROP PROCEDURE dbo.[' + name + '];' + CHAR(13)
    FROM sys.procedures
    WHERE name = 'lakeflowFixPermissions';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing lakeflowFixPermissions procedures';
        END

    -- Drop lakeflowSetupChangeTracking procedures
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP PROCEDURE dbo.[' + name + '];' + CHAR(13)
    FROM sys.procedures
    WHERE name = 'lakeflowSetupChangeTracking';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing lakeflowSetupChangeTracking procedures';
        END

    -- Drop lakeflowSetupChangeDataCapture procedures
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP PROCEDURE dbo.[' + name + '];' + CHAR(13)
    FROM sys.procedures
    WHERE name = 'lakeflowSetupChangeDataCapture';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing lakeflowSetupChangeDataCapture procedures';
        END

    -- Drop lakeflowDetectPlatform functions
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP FUNCTION dbo.[' + name + '];' + CHAR(13)
    FROM sys.objects
    WHERE name = 'lakeflowDetectPlatform'
      AND type = 'FN';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing lakeflowDetectPlatform functions';
        END

    -- Drop lakeflowUtilityVersion functions
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP FUNCTION dbo.[' + name + '];' + CHAR(13)
    FROM sys.objects
    WHERE name LIKE 'lakeflowUtilityVersion_%_%'
      AND type = 'FN';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing lakeflowUtilityVersion functions';
        END

    -- Drop older versions of change tracking DDL objects
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP TABLE [dbo].[' + name + '];' + CHAR(13)
    FROM sys.tables
    WHERE name LIKE 'lakeflowDdlAudit_%_%';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing DDL audit tables from all versions';
        END

    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP TRIGGER [' + name + '] ON DATABASE;' + CHAR(13)
    FROM sys.triggers
    WHERE name LIKE 'lakeflowDdlAuditTrigger_%_%' AND parent_class = 0;

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing DDL audit triggers from all versions';
        END

    -- Drop older versions of CDC objects
    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP PROCEDURE dbo.[' + name + '];' + CHAR(13)
    FROM sys.procedures
    WHERE name LIKE 'lakeflowDisableOldCaptureInstance_%_%'
       OR name LIKE 'lakeflowMergeCaptureInstances_%_%'
       OR name LIKE 'lakeflowRefreshCaptureInstance_%_%';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing CDC procedures from all versions';
        END

    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP TABLE [dbo].[' + name + '];' + CHAR(13)
    FROM sys.tables
    WHERE name LIKE 'lakeflowCaptureInstanceInfo_%_%';

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing capture instance tables from all versions';
        END

    SET @dropSql = '';
    SELECT @dropSql = @dropSql + 'DROP TRIGGER [' + name + '] ON DATABASE;' + CHAR(13)
    FROM sys.triggers
    WHERE name LIKE 'lakeflowAlterTableTrigger_%_%' AND parent_class = 0;

    IF LEN(@dropSql) > 0
        BEGIN
            EXEC sp_executesql @dropSql;
            PRINT N'Dropped existing ALTER TABLE triggers from all versions';
        END

    PRINT N'Cleanup completed.';
    PRINT N'';
END

-- Create versioned functions first (dependencies)
PRINT N'Creating lakeflowDetectPlatform function...';
EXEC sp_executesql N'
CREATE FUNCTION dbo.lakeflowDetectPlatform()
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @engineEdition INT = CAST(SERVERPROPERTY(''EngineEdition'') AS INT);
    DECLARE @serverName NVARCHAR(255) = @@SERVERNAME;
    DECLARE @platform NVARCHAR(50);

    IF @engineEdition = 5
        SET @platform = ''AZURE_SQL_DATABASE'';
    ELSE IF @engineEdition = 8
        SET @platform = ''AZURE_SQL_MANAGED_INSTANCE'';
    ELSE IF @serverName LIKE ''%.rds.amazonaws.com''
        SET @platform = ''AMAZON_RDS'';
    ELSE IF @engineEdition IN (1, 2, 3, 4)
        SET @platform = ''ON_PREMISES'';
    ELSE
        SET @platform = ''UNKNOWN'';

    RETURN @platform;
END';
PRINT N'Created lakeflowDetectPlatform function';

PRINT N'Creating lakeflowUtilityVersion_1_1 function...';
EXEC sp_executesql N'
CREATE FUNCTION dbo.lakeflowUtilityVersion_1_1()
RETURNS NVARCHAR(10)
AS
BEGIN
    RETURN ''1.1'';
END';
PRINT N'Created lakeflowUtilityVersion_1_1 function';

-- Create lakeflowFixPermissions
PRINT N'Creating lakeflowFixPermissions procedure...';
EXEC sp_executesql N'
CREATE PROCEDURE dbo.lakeflowFixPermissions
    @User NVARCHAR(128),
    @Tables NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseUser NVARCHAR(128) = @User;
    DECLARE @Platform NVARCHAR(50) = dbo.lakeflowDetectPlatform();
    DECLARE @CatalogName NVARCHAR(128) = DB_NAME();
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CurrentObject NVARCHAR(255);

    -- Error codes and messages
    DECLARE @invalidModeErrorCode INT = 100000;
    DECLARE @insufficientUserPrivilegesCode INT = 100400;
    DECLARE @insufficientUserPrivilegesErrorMessage NVARCHAR(200);

    SET @insufficientUserPrivilegesErrorMessage = ''User executing this script is not a ''''db_owner'''' role member. To execute this script, please use a user that is.'';

    PRINT N''Starting permission fixes for: '' + @CatalogName;
    PRINT N''Platform: '' + @Platform;
    PRINT N''User: '' + @User;
    IF @Tables IS NOT NULL
        PRINT N''Tables parameter: '' + @Tables;

    BEGIN TRY
        -- Validate that current user is db_owner
        IF (IS_ROLEMEMBER(''db_owner'') = 0)
        BEGIN
            THROW @insufficientUserPrivilegesCode, @insufficientUserPrivilegesErrorMessage, 1;
        END

        -- User resolution
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @User)
        BEGIN
            -- Check if user exists as database user
            SELECT @DatabaseUser = dp.name
            FROM sys.database_principals dp
            INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
            WHERE sp.name = @User
                AND dp.type IN (''S'', ''U'', ''G'')
                AND dp.name NOT IN (''guest'');

            -- If still no database user found, warn and skip
            IF @DatabaseUser IS NULL OR @DatabaseUser = @User
            BEGIN
                PRINT N''⚠ Warning: User/Login ['' + @User + ''] not found as database user. Skipping permission grants.'';
                PRINT N''  To fix: CREATE USER ['' + @User + ''] FOR LOGIN ['' + @User + ''];'';
                RETURN;
            END
            ELSE
            BEGIN
                PRINT N''Server login ['' + @User + ''] maps to database user ['' + @DatabaseUser + ''].'';
            END
        END

        IF @DatabaseUser = ''dbo''
        BEGIN
            PRINT N''Skipping permission grants (dbo already has all permissions).'';
            PRINT N''Permission setup completed for user: '' + @User;
            RETURN;
        END

        -- Grant SELECT permissions on required system views and tables
        DECLARE @SystemObjects TABLE (ObjectName NVARCHAR(255), IsServerScoped BIT);
        INSERT INTO @SystemObjects VALUES
            (''sys.objects'', 0), (''sys.schemas'', 0), (''sys.tables'', 0), (''sys.columns'', 0),
            (''sys.key_constraints'', 0), (''sys.foreign_keys'', 0), (''sys.check_constraints'', 0),
            (''sys.default_constraints'', 0), (''sys.triggers'', 0), (''sys.indexes'', 0),
            (''sys.index_columns'', 0), (''sys.fulltext_index_columns'', 0), (''sys.fulltext_indexes'', 0),
            (''sys.change_tracking_databases'', 1), (''sys.change_tracking_tables'', 0),
            (''cdc.change_tables'', 0), (''cdc.captured_columns'', 0), (''cdc.index_columns'', 0);

        -- Grant EXECUTE permissions on required system stored procedures (all server-scoped)
        DECLARE @SystemProcedures TABLE (ProcedureName NVARCHAR(255));
        INSERT INTO @SystemProcedures VALUES
            (''sp_tables''), (''sp_columns_100''), (''sp_pkeys''), (''sp_statistics_100'');

        PRINT N'''';
        PRINT N''=== System Object Permissions ==='';

        DECLARE sys_cursor CURSOR FOR
            SELECT ObjectName FROM @SystemObjects
            WHERE IsServerScoped = 0 OR @Platform NOT IN (''AZURE_SQL_DATABASE'');

        OPEN sys_cursor;
        FETCH NEXT FROM sys_cursor INTO @CurrentObject;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                -- Check if object exists before trying to grant (helps with CDC objects)
                IF @CurrentObject LIKE ''cdc.%''
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = ''cdc'')
                    BEGIN
                        PRINT N''ℹ Skipping '' + @CurrentObject + '' (CDC not enabled)'';
                        FETCH NEXT FROM sys_cursor INTO @CurrentObject;
                        CONTINUE;
                    END
                END

                SET @SQL = ''GRANT SELECT ON '' + @CurrentObject + '' TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Granted SELECT on '' + @CurrentObject;
            END TRY
            BEGIN CATCH
                PRINT N''⚠ Could not grant SELECT on '' + @CurrentObject + '': '' + ERROR_MESSAGE();
            END CATCH

            FETCH NEXT FROM sys_cursor INTO @CurrentObject;
        END

        CLOSE sys_cursor;
        DEALLOCATE sys_cursor;

        -- Grant EXECUTE permissions on system procedures (skip for Azure SQL Database - implicit access)
        IF @Platform NOT IN (''AZURE_SQL_DATABASE'')
        BEGIN
            DECLARE proc_cursor CURSOR FOR
                SELECT ProcedureName FROM @SystemProcedures;

            OPEN proc_cursor;
            FETCH NEXT FROM proc_cursor INTO @CurrentObject;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                BEGIN TRY
                    SET @SQL = ''GRANT EXECUTE ON '' + @CurrentObject + '' TO ['' + @DatabaseUser + '']'';
                    EXEC sp_executesql @SQL;
                    PRINT N''✓ Granted EXECUTE on '' + @CurrentObject;
                END TRY
                BEGIN CATCH
                    PRINT N''⚠ Could not grant EXECUTE on '' + @CurrentObject + '': '' + ERROR_MESSAGE();
                END CATCH

                FETCH NEXT FROM proc_cursor INTO @CurrentObject;
            END

            CLOSE proc_cursor;
            DEALLOCATE proc_cursor;
        END
        ELSE
        BEGIN
            PRINT N''ℹ Skipping system stored procedure permissions on Azure SQL Database'';
            PRINT N''  Database users have implicit EXECUTE access to system stored procedures'';
        END

        -- Handle table-specific permissions if @Tables parameter is provided
        IF @Tables IS NOT NULL
        BEGIN
            PRINT N'''';
            PRINT N''=== Table-Level SELECT Permissions ==='';

            DECLARE @TargetTables TABLE (
                SchemaName NVARCHAR(128),
                TableName NVARCHAR(128),
                FullName NVARCHAR(261),
                ObjectId INT
            );

            -- Table discovery logic
            IF @Tables = ''ALL''
            BEGIN
                PRINT N''Discovering all user tables in database...'';
                INSERT INTO @TargetTables (SchemaName, TableName, FullName, ObjectId)
                SELECT
                    s.name, t.name,
                    QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name),
                    t.object_id
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.type = ''U''
                    AND s.name NOT IN (''sys'', ''information_schema'', ''cdc'', ''INFORMATION_SCHEMA'', ''guest'');
            END
            ELSE IF @Tables LIKE ''SCHEMAS:%''
            BEGIN
                DECLARE @SchemaList NVARCHAR(MAX) = SUBSTRING(@Tables, 9, LEN(@Tables));
                PRINT N''Discovering tables in schemas: '' + @SchemaList;
                DECLARE @SchemaXML XML;
                SET @SchemaXML = CAST(''<schema>'' + REPLACE(@SchemaList, '','', ''</schema><schema>'') + ''</schema>'' AS XML);
                INSERT INTO @TargetTables (SchemaName, TableName, FullName, ObjectId)
                SELECT
                    s.name, t.name,
                    QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name),
                    t.object_id
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.type = ''U''
                    AND s.name IN (
                        SELECT LTRIM(RTRIM(x.value(''(./text())[1]'', ''NVARCHAR(MAX)'')))
                        FROM @SchemaXML.nodes(''/schema'') AS T(x)
                        WHERE LTRIM(RTRIM(x.value(''(./text())[1]'', ''NVARCHAR(MAX)''))) != ''''
                    );
            END
            ELSE
            BEGIN
                PRINT N''Processing specified tables: '' + @Tables;
                DECLARE @TableList TABLE (FullTableName NVARCHAR(261));
                INSERT INTO @TableList (FullTableName)
                SELECT LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) AS value
                FROM (
                    SELECT CAST(''<M>'' + REPLACE(@Tables, '','', ''</M><M>'') + ''</M>'' AS XML) AS Data
                ) AS A
                CROSS APPLY Data.nodes(''/M'') AS Split(a)
                WHERE LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) != '''';

                INSERT INTO @TargetTables (SchemaName, TableName, FullName, ObjectId)
                SELECT
                    s.name, t.name,
                    QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name),
                    t.object_id
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                INNER JOIN @TableList tl ON
                    (tl.FullTableName = s.name + ''.*'' OR
                     tl.FullTableName = s.name + ''.'' + t.name OR
                     (CHARINDEX(''.'', tl.FullTableName) = 0 AND tl.FullTableName = t.name AND s.name = ''dbo''))
                WHERE t.type = ''U'';
            END

            -- Grant SELECT permissions on discovered tables
            DECLARE @ProcessedCount INT = 0, @ErrorCount INT = 0;
            DECLARE @CurrentSchema NVARCHAR(128), @CurrentTable NVARCHAR(128), @CurrentFullName NVARCHAR(261);

            DECLARE table_cursor CURSOR FOR
                SELECT SchemaName, TableName, FullName FROM @TargetTables ORDER BY SchemaName, TableName;

            OPEN table_cursor;
            FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable, @CurrentFullName;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                BEGIN TRY
                    SET @SQL = N''GRANT SELECT ON '' + @CurrentFullName + '' TO ['' + @DatabaseUser + '']'';
                    EXEC sp_executesql @SQL;
                    PRINT N''✓ Granted SELECT on '' + @CurrentFullName;
                    SET @ProcessedCount = @ProcessedCount + 1;
                END TRY
                BEGIN CATCH
                    PRINT N''✗ Error granting SELECT on '' + @CurrentFullName + '': '' + ERROR_MESSAGE();
                    SET @ErrorCount = @ErrorCount + 1;
                END CATCH

                FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable, @CurrentFullName;
            END

            CLOSE table_cursor;
            DEALLOCATE table_cursor;

            -- Summary for table permissions
            PRINT N'''';
            PRINT N''Table permission summary:'';
            PRINT N''  - Tables processed: '' + CAST(@ProcessedCount AS NVARCHAR(10));
            PRINT N''  - Tables with errors: '' + CAST(@ErrorCount AS NVARCHAR(10));
        END

        PRINT N'''';
        PRINT N''Permission fixes completed for user: '' + @User;

        -- Platform-specific guidance
        IF @Platform = ''AZURE_SQL_DATABASE''
        BEGIN
            PRINT N'''';
            PRINT N''=== Azure SQL Database Platform Notes ==='';
            PRINT N''• System stored procedures: Accessible by default to database users (no grants needed)'';
            PRINT N''• Server-scoped catalog views: Limited access in Azure SQL Database'';
            PRINT N''• Consider granting db_datareader role for broader access'';
            PRINT N''• CDC objects are only available when CDC is enabled on the database'';
            PRINT N'''';
            PRINT N''=== Recommended Additional Access ==='';
            PRINT N''-- Grant broader database-level access for comprehensive permissions:'';
            PRINT N''USE ['' + @CatalogName + ''];'';
            PRINT N''ALTER ROLE db_datareader ADD MEMBER ['' + @DatabaseUser + ''];'';
            PRINT N'''';
            PRINT N''=== Server-Scoped Limitations ==='';
            PRINT N''• sys.change_tracking_databases: Requires server-level access (typically not available)'';
            PRINT N''• Most Azure SQL Database deployments cannot grant server-level permissions'';
            PRINT N''• Contact your Azure administrator if server-level access is specifically required'';
        END
        ELSE IF @Platform = ''AZURE_SQL_MANAGED_INSTANCE''
        BEGIN
            PRINT N'''';
            PRINT N''=== Azure SQL Managed Instance Platform Notes ==='';
            PRINT N''• Most permissions granted successfully at database level'';
            PRINT N''• If server-scoped permissions are needed, connect to master:'';
            PRINT N''USE master;'';
            PRINT N''GRANT SELECT ON sys.change_tracking_databases TO ['' + @DatabaseUser + ''];'';
        END
        ELSE
        BEGIN
            PRINT N'''';
            PRINT N''=== Platform Notes ==='';
            PRINT N''• All permissions granted successfully at database level'';
            PRINT N''• No additional server-level configuration required'';
        END

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ''Error in lakeflowFixPermissions: '' + ERROR_MESSAGE();
        PRINT @ErrorMessage;
        THROW;
    END CATCH
END';
PRINT N'Created lakeflowFixPermissions procedure';

-- Create lakeflowSetupChangeTracking
PRINT N'Creating lakeflowSetupChangeTracking procedure...';
EXEC sp_executesql N'
CREATE PROCEDURE dbo.lakeflowSetupChangeTracking
    @Tables NVARCHAR(MAX) = NULL,
    @User NVARCHAR(128) = NULL,
    @Retention NVARCHAR(50) = ''2 DAYS'',
    @Mode NVARCHAR(10) = ''INSTALL''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseUser NVARCHAR(128) = @User;
    DECLARE @Platform NVARCHAR(50) = dbo.lakeflowDetectPlatform();
    DECLARE @CatalogName NVARCHAR(128) = DB_NAME();
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @versionSuffix NVARCHAR(10) = ''_1_3'';
    DECLARE @ddlAuditTableName NVARCHAR(100) = ''lakeflowDdlAudit'' + @versionSuffix;
    DECLARE @ddlAuditTriggerName NVARCHAR(100) = ''lakeflowDdlAuditTrigger'' + @versionSuffix;

    -- Error codes and messages
    DECLARE @invalidModeErrorCode INT = 100000;
    DECLARE @invalidModeErrorMessage NVARCHAR(200);
    DECLARE @insufficientUserPrivilegesCode INT = 100400;
    DECLARE @insufficientUserPrivilegesErrorMessage NVARCHAR(200);

    SET @invalidModeErrorMessage = CONCAT(''Provided execution mode: '', @Mode, '', is not recognized. Allowed values are: INSTALL, CLEANUP'');
    SET @insufficientUserPrivilegesErrorMessage = ''User executing this script is not a ''''db_owner'''' role member. To execute this script, please use a user that is.'';

    PRINT N''Starting change tracking setup for: '' + @CatalogName;
    PRINT N''Platform: '' + @Platform;
    PRINT N''Mode: '' + @Mode;
    IF @Tables IS NOT NULL
        PRINT N''Tables: '' + @Tables;

    BEGIN TRY
        -- Validate execution mode
        IF (@Mode != ''INSTALL'' AND @Mode != ''CLEANUP'')
        BEGIN
            THROW @invalidModeErrorCode, @invalidModeErrorMessage, 1;
        END

        -- Validate that current user is db_owner
        IF (IS_ROLEMEMBER(''db_owner'') = 0)
        BEGIN
            THROW @insufficientUserPrivilegesCode, @insufficientUserPrivilegesErrorMessage, 1;
        END

        -- Cleanup legacy DDL support objects
        IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''replicate_io_audit_ddl_trigger_1'' AND parent_class = 0)
            OR OBJECT_ID(''dbo.replicate_io_audit_ddl_1'', ''U'') IS NOT NULL
            OR OBJECT_ID(''dbo.replicate_io_audit_tbl_cons_1'', ''U'') IS NOT NULL
            OR OBJECT_ID(''dbo.replicate_io_audit_tbl_schema_1'', ''U'') IS NOT NULL
            OR EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''alterTableTrigger_1'' AND parent_class = 0)
            OR OBJECT_ID(''dbo.disableOldCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.refreshCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.mergeCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.captureInstanceTracker_1'', ''U'') IS NOT NULL
        BEGIN
            PRINT N''Cleaning up legacy DDL support objects...'';

            IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''replicate_io_audit_ddl_trigger_1'' AND parent_class = 0)
            BEGIN
                EXEC(''DROP TRIGGER replicate_io_audit_ddl_trigger_1 ON DATABASE'');
                PRINT N''✓ Dropped legacy trigger: replicate_io_audit_ddl_trigger_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_ddl_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_ddl_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_ddl_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_tbl_cons_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_tbl_cons_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_tbl_cons_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_tbl_schema_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_tbl_schema_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_tbl_schema_1'';
            END

            IF EXISTS (SELECT name FROM sys.triggers WHERE name = ''alterTableTrigger_1'' AND type = ''TR'')
            BEGIN
                EXEC(''DROP TRIGGER alterTableTrigger_1 ON DATABASE'');
                PRINT N''✓ Dropped legacy trigger: alterTableTrigger_1'';
            END

            IF OBJECT_ID(''dbo.disableOldCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.disableOldCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: disableOldCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.refreshCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.refreshCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: refreshCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.mergeCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.mergeCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: mergeCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.captureInstanceTracker_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.captureInstanceTracker_1'');
                PRINT N''✓ Dropped legacy table: captureInstanceTracker_1'';
            END

            PRINT N''Legacy DDL support objects cleanup completed'';
        END

        -- Cleanup mode: Remove DDL support objects
        IF @Mode = ''CLEANUP''
        BEGIN
            PRINT N''Cleaning up CT DDL support objects...'';

            -- Drop DDL audit trigger
            IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = @ddlAuditTriggerName AND parent_class = 0)
            BEGIN
                SET @SQL = N''DROP TRIGGER ['' + @ddlAuditTriggerName + ''] ON DATABASE'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped trigger: '' + @ddlAuditTriggerName;
            END

            -- Drop DDL audit table
            IF OBJECT_ID(''dbo.'' + @ddlAuditTableName, ''U'') IS NOT NULL
            BEGIN
                SET @SQL = N''DROP TABLE [dbo].['' + @ddlAuditTableName + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped table: '' + @ddlAuditTableName;
            END

            -- Pattern-based cleanup for any remaining CT objects across versions
            DECLARE @ctCleanupSql NVARCHAR(MAX) = '''';

            -- Clean up any remaining DDL audit tables across versions (excluding current and legacy)
            SELECT @ctCleanupSql = @ctCleanupSql + ''DROP TABLE [dbo].['' + name + ''];'' + CHAR(13)
            FROM sys.tables
            WHERE name LIKE ''lakeflowDdlAudit_%_%''
              AND name != @ddlAuditTableName;

            IF LEN(@ctCleanupSql) > 0
            BEGIN
                EXEC sp_executesql @ctCleanupSql;
                PRINT N''✓ Cleaned up remaining DDL audit tables across versions'';
            END

            -- Clean up any remaining DDL audit triggers across versions (excluding current and legacy)
            SET @ctCleanupSql = '''';
            SELECT @ctCleanupSql = @ctCleanupSql + ''DROP TRIGGER ['' + name + ''] ON DATABASE;'' + CHAR(13)
            FROM sys.triggers
            WHERE name LIKE ''lakeflowDdlAuditTrigger_%_%''
              AND name != @ddlAuditTriggerName
              AND parent_class = 0;

            IF LEN(@ctCleanupSql) > 0
            BEGIN
                EXEC sp_executesql @ctCleanupSql;
                PRINT N''✓ Cleaned up remaining DDL audit triggers across versions'';
            END

            PRINT N''CT DDL support objects cleanup completed'';
            RETURN;
        END

        -- Install mode continues here
        PRINT N''Setting up change tracking infrastructure...'';

        -- Check if change tracking is enabled at database level
        IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases ctd
                       INNER JOIN sys.databases d ON ctd.database_id = d.database_id
                       WHERE d.name = DB_NAME())
        BEGIN
            PRINT N''Enabling change tracking at database level...'';
            SET @SQL = N''ALTER DATABASE '' + QUOTENAME(@CatalogName) + '' SET CHANGE_TRACKING = ON (CHANGE_RETENTION = '' + @Retention + '', AUTO_CLEANUP = ON)'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Change tracking enabled at database level'';
        END
        ELSE
        BEGIN
            PRINT N''ℹ Change tracking already enabled at database level'';
        END

        -- Create DDL audit table if it does not exist
        IF OBJECT_ID(''dbo.'' + @ddlAuditTableName, ''U'') IS NULL
        BEGIN
            SET @sql = N''CREATE TABLE [dbo].['' + @ddlAuditTableName + ''](
                [SERIAL_NUMBER] INT IDENTITY NOT NULL,
                [CURRENT_USER] NVARCHAR(128) NULL,
                [SCHEMA_NAME] NVARCHAR(128) NULL,
                [TABLE_NAME] NVARCHAR(128) NULL,
                [TYPE] NVARCHAR(30) NULL,
                [OPERATION_TYPE] NVARCHAR(30) NULL,
                [SQL_TXT] NVARCHAR(2000) NULL,
                [LOGICAL_POSITION] BIGINT NOT NULL,
                CONSTRAINT [replicantDdlAuditPrimaryKey_'' + @versionSuffix + ''] PRIMARY KEY ([SERIAL_NUMBER], [LOGICAL_POSITION]))'';
            EXEC sp_executesql @sql;
            PRINT N''✓ Created DDL audit table: '' + @ddlAuditTableName;

            -- Enable change tracking on DDL audit table
            SET @sql = N''ALTER TABLE [dbo].['' + @ddlAuditTableName + ''] ENABLE CHANGE_TRACKING'';
            EXEC sp_executesql @sql;
            PRINT N''✓ Enabled change tracking on DDL audit table'';
        END

        -- Create DDL audit trigger
        IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = @ddlAuditTriggerName)
        BEGIN
            DECLARE @QuotedDbName NVARCHAR(255) = QUOTENAME(DB_NAME());
            SET @sql = N''CREATE TRIGGER ['' + @ddlAuditTriggerName + ''] ON DATABASE
                FOR ALTER_TABLE
                AS
                SET NOCOUNT ON;
                DECLARE @DbName NVARCHAR(255),
                        @SchemaName NVARCHAR(max),
                        @TableName NVARCHAR(255),
                        @QuotedFullName NVARCHAR(max),
                        @objectType NVARCHAR(30),
                        @data XML,
                        @changeVersion NVARCHAR(30),
                        @operation NVARCHAR(30),
                        @capturedSql NVARCHAR(2000),
                        @isCTEnabledDBLevel bit,
                        @isCTEnabledTableLevel bit,
                        @isColumnAdd nvarchar(255),
                        @isAlterColumn nvarchar(255),
                        @isDropColumn nvarchar(255);

                    SET @data = EVENTDATA();
                    SET @changeVersion = CHANGE_TRACKING_CURRENT_VERSION();
                    SET @DbName = DB_NAME();
                    SET @SchemaName = @data.value(''''(/EVENT_INSTANCE/SchemaName)[1]'''',  ''''NVARCHAR(MAX)'''');
                    SET @TableName = @data.value(''''(/EVENT_INSTANCE/ObjectName)[1]'''',  ''''NVARCHAR(255)'''');
                    SET @objectType = @data.value(''''(/EVENT_INSTANCE/ObjectType)[1]'''', ''''NVARCHAR(30)'''');
                    SET @QuotedFullName = QUOTENAME(@SchemaName) + ''''.'''' + QUOTENAME(@TableName);
                    SET @operation = @data.value(''''(/EVENT_INSTANCE/EventType)[1]'''', ''''NVARCHAR(30)'''');
                    SET @capturedSql = @data.value(''''(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]'''', ''''NVARCHAR(2000)'''');
                    SET @isCTEnabledDBLevel = (SELECT COUNT(*) FROM sys.change_tracking_databases ctd
                                                INNER JOIN sys.databases d ON ctd.database_id = d.database_id
                                                WHERE d.name = @DbName);
                    SET @isCTEnabledTableLevel = (SELECT COUNT(*) FROM sys.change_tracking_tables WHERE object_id = object_id(@QuotedFullName));
                    SET @isColumnAdd = @data.value(''''(/EVENT_INSTANCE/AlterTableActionList/Create)[1]'''', ''''NVARCHAR(255)'''');
                    SET @isAlterColumn = @data.value(''''(/EVENT_INSTANCE/AlterTableActionList/Alter)[1]'''', ''''NVARCHAR(255)'''');
                    SET @isDropColumn = @data.value(''''(/EVENT_INSTANCE/AlterTableActionList/Drop)[1]'''', ''''NVARCHAR(255)'''');

                IF ((@isCTEnabledDBLevel = 1 AND @isCTEnabledTableLevel = 1) AND ((@isColumnAdd IS NOT NULL) OR (@isAlterColumn IS NOT NULL) OR (@isDropColumn IS NOT NULL)))
                BEGIN
                    INSERT INTO '' + @QuotedDbName + ''.dbo.['' + @ddlAuditTableName + ''] (
                        [CURRENT_USER],
                        [SCHEMA_NAME],
                        [TABLE_NAME],
                        [TYPE],
                        [OPERATION_TYPE],
                        [SQL_TXT],
                        [LOGICAL_POSITION]
                    )
                    VALUES (
                        SUSER_NAME(),
                        @SchemaName,
                        @TableName,
                        @objectType,
                        @operation,
                        @capturedSql,
                        @changeVersion
                    );
                END'';
            EXEC sp_executesql @sql;
            PRINT N''✓ Created DDL audit trigger: '' + @ddlAuditTriggerName;
        END

        -- User resolution
        IF @User IS NOT NULL AND @User != ''''
        BEGIN
            -- Check if user exists as database user
            IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @User)
            BEGIN
                -- Check if it is a server login and find its mapped database user
                SELECT @DatabaseUser = dp.name
                FROM sys.database_principals dp
                INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
                WHERE sp.name = @User
                    AND dp.type IN (''S'', ''U'', ''G'')
                    AND dp.name NOT IN (''guest'');

                -- If still no database user found, warn
                IF @DatabaseUser IS NULL OR @DatabaseUser = @User
                BEGIN
                    PRINT N''⚠ Warning: User/Login ['' + @User + ''] not found as database user. Skipping permission grants.'';
                    PRINT N''  To fix: CREATE USER ['' + @User + ''] FOR LOGIN ['' + @User + ''];'';
                    SET @DatabaseUser = NULL;
                END
                ELSE
                BEGIN
                    PRINT N''Server login ['' + @User + ''] maps to database user ['' + @DatabaseUser + ''].'';
                END
            END

            IF @DatabaseUser = ''dbo''
            BEGIN
                PRINT N''Skipping permission grants (dbo already has all permissions).'';
                SET @DatabaseUser = NULL;
            END
        END

        -- Grant permissions to user if specified
        IF @DatabaseUser IS NOT NULL
        BEGIN
            PRINT N''Granting permissions to user: '' + @DatabaseUser;

            -- Grant SELECT on DDL audit table
            SET @SQL = N''GRANT SELECT ON [dbo].['' + @ddlAuditTableName + ''] TO '' + QUOTENAME(@DatabaseUser);
            EXEC sp_executesql @SQL;
            PRINT N''✓ Granted SELECT on '' + @ddlAuditTableName + '' to '' + @DatabaseUser;

            -- Grant VIEW CHANGE TRACKING on DDL audit table
            SET @SQL = N''GRANT VIEW CHANGE TRACKING ON [dbo].['' + @ddlAuditTableName + ''] TO '' + QUOTENAME(@DatabaseUser);
            EXEC sp_executesql @SQL;
            PRINT N''✓ Granted VIEW CHANGE TRACKING on '' + @ddlAuditTableName + '' to '' + @DatabaseUser;

            -- Grant VIEW DEFINITION to see database-level triggers
            SET @SQL = N''GRANT VIEW DEFINITION TO '' + QUOTENAME(@DatabaseUser);
            EXEC sp_executesql @SQL;
            PRINT N''✓ Granted VIEW DEFINITION to '' + @DatabaseUser;
        END

        -- Process tables if specified
        IF @Tables IS NOT NULL
        BEGIN
            PRINT N''Processing tables for change tracking enablement...'';

            -- Declare variables for table processing
            DECLARE @TargetTables TABLE (
                SchemaName NVARCHAR(128),
                TableName NVARCHAR(128),
                HasPrimaryKey BIT
            );

            DECLARE @SkippedTables NVARCHAR(MAX) = '''';
            DECLARE @SkippedTablesCount INT = 0;
            DECLARE @CurrentSchema NVARCHAR(128);
            DECLARE @CurrentTable NVARCHAR(128);
            DECLARE @ProcessedCount INT = 0;
            DECLARE @SkippedCount INT = 0;
            DECLARE @ErrorCount INT = 0;

            -- Parse table list and populate target tables
            IF @Tables = ''ALL''
            BEGIN
                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name,
                    t.name,
                    CASE WHEN EXISTS (
                        SELECT 1 FROM sys.key_constraints kc
                        WHERE kc.parent_object_id = t.object_id
                        AND kc.type = ''PK''
                    ) THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.is_ms_shipped = 0;
            END
            ELSE IF @Tables LIKE ''SCHEMAS:%''
            BEGIN
                DECLARE @SchemaList NVARCHAR(MAX) = SUBSTRING(@Tables, 9, LEN(@Tables));
                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name, t.name,
                    CASE WHEN pk.CONSTRAINT_NAME IS NOT NULL THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ON
                    pk.TABLE_SCHEMA = s.name AND pk.TABLE_NAME = t.name AND pk.CONSTRAINT_TYPE = ''PRIMARY KEY''
                WHERE t.type = ''U''
                    AND s.name IN (SELECT LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) AS value
                FROM (
                    SELECT CAST(''<M>'' + REPLACE(@SchemaList, '','', ''</M><M>'') + ''</M>'' AS XML) AS Data
                ) AS A
                CROSS APPLY Data.nodes(''/M'') AS Split(a)
                WHERE LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) != '''');
            END
            ELSE
            BEGIN
                PRINT N''Processing specified tables: '' + @Tables;
                DECLARE @TableList TABLE (FullTableName NVARCHAR(261));
                INSERT INTO @TableList (FullTableName)
                SELECT LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) AS value
                FROM (
                    SELECT CAST(''<M>'' + REPLACE(@Tables, '','', ''</M><M>'') + ''</M>'' AS XML) AS Data
                ) AS A
                CROSS APPLY Data.nodes(''/M'') AS Split(a)
                WHERE LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) != '''';

                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name, t.name,
                    CASE WHEN pk.CONSTRAINT_NAME IS NOT NULL THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                INNER JOIN @TableList tl ON
                    (tl.FullTableName = s.name + ''.*'' OR
                     tl.FullTableName = s.name + ''.'' + t.name OR
                     (CHARINDEX(''.'', tl.FullTableName) = 0 AND tl.FullTableName = t.name AND s.name = ''dbo''))
                LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ON
                    pk.TABLE_SCHEMA = s.name AND pk.TABLE_NAME = t.name AND pk.CONSTRAINT_TYPE = ''PRIMARY KEY''
                WHERE t.type = ''U'';
            END

            -- Check for tables without primary keys
            SELECT @SkippedTables = COALESCE(@SkippedTables + '','', '''') + QUOTENAME(SchemaName) + ''.'' + QUOTENAME(TableName)
            FROM @TargetTables
            WHERE HasPrimaryKey = 0;

            SELECT @SkippedTablesCount = COUNT(*)
            FROM @TargetTables
            WHERE HasPrimaryKey = 0;

            IF @SkippedTablesCount > 0
            BEGIN
                DECLARE @SkippedTableWord NVARCHAR(10) = CASE WHEN @SkippedTablesCount = 1 THEN ''table'' ELSE ''tables'' END;
                PRINT N''⚠ WARNING: Skipping '' + CAST(@SkippedTablesCount AS NVARCHAR(10)) + '' '' + @SkippedTableWord + '' without primary keys:'';
                PRINT N''   '' + @SkippedTables;
                PRINT N''   Consider using lakeflowSetupChangeDataCapture for these tables.'';

                DELETE FROM @TargetTables WHERE HasPrimaryKey = 0;
            END

            -- Process each table for change tracking enablement
            DECLARE table_cursor CURSOR FOR
                SELECT SchemaName, TableName FROM @TargetTables ORDER BY SchemaName, TableName;

            OPEN table_cursor;
            FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                BEGIN TRY
                    IF NOT EXISTS (
                        SELECT 1 FROM sys.change_tracking_tables ct
                        INNER JOIN sys.tables t ON ct.object_id = t.object_id
                        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                        WHERE s.name = @CurrentSchema AND t.name = @CurrentTable
                    )
                    BEGIN
                        SET @SQL = N''ALTER TABLE '' + QUOTENAME(@CurrentSchema) + ''.'' + QUOTENAME(@CurrentTable) + '' ENABLE CHANGE_TRACKING'';
                        EXEC sp_executesql @SQL;
                        PRINT N''✓ Enabled change tracking on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']'';
                        SET @ProcessedCount = @ProcessedCount + 1;
                    END
                    ELSE
                    BEGIN
                        PRINT N''ℹ Change tracking already enabled on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']'';
                        SET @SkippedCount = @SkippedCount + 1;
                    END
                END TRY
                BEGIN CATCH
                    PRINT N''✗ Error enabling change tracking on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']: '' + ERROR_MESSAGE();
                    SET @ErrorCount = @ErrorCount + 1;
                END CATCH

                FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable;
            END

            CLOSE table_cursor;
            DEALLOCATE table_cursor;

            -- Grant VIEW CHANGE TRACKING permissions to user (if @User is specified)
            IF @DatabaseUser IS NOT NULL
            BEGIN
                PRINT N'''';
                PRINT N''=== Granting VIEW CHANGE TRACKING Permissions ==='';

                DECLARE @PermissionGrantCount INT = 0, @PermissionErrorCount INT = 0;

                -- Strategy based on @Tables parameter
                IF @Tables = ''ALL''
                BEGIN
                    -- Grant on all user tables with change tracking enabled
                    PRINT N''Granting VIEW CHANGE TRACKING on all change tracking enabled tables...'';

                    DECLARE @CTSchema NVARCHAR(128), @CTTable NVARCHAR(128);
                    DECLARE ct_cursor CURSOR FOR
                        SELECT s.name, t.name
                        FROM sys.change_tracking_tables ct
                        INNER JOIN sys.tables t ON ct.object_id = t.object_id
                        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                        WHERE s.name NOT IN (''sys'', ''information_schema'', ''cdc'', ''INFORMATION_SCHEMA'', ''guest'')
                        ORDER BY s.name, t.name;

                    OPEN ct_cursor;
                    FETCH NEXT FROM ct_cursor INTO @CTSchema, @CTTable;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        BEGIN TRY
                            SET @SQL = N''GRANT VIEW CHANGE TRACKING ON ['' + @CTSchema + ''].['' + @CTTable + ''] TO '' + QUOTENAME(@DatabaseUser);
                            EXEC sp_executesql @SQL;
                            PRINT N''  ✓ Granted VIEW CHANGE TRACKING on ['' + @CTSchema + ''].['' + @CTTable + '']'';
                            SET @PermissionGrantCount = @PermissionGrantCount + 1;
                        END TRY
                        BEGIN CATCH
                            PRINT N''  ⚠ Could not grant VIEW CHANGE TRACKING on ['' + @CTSchema + ''].['' + @CTTable + '']: '' + ERROR_MESSAGE();
                            SET @PermissionErrorCount = @PermissionErrorCount + 1;
                        END CATCH

                        FETCH NEXT FROM ct_cursor INTO @CTSchema, @CTTable;
                    END

                    CLOSE ct_cursor;
                    DEALLOCATE ct_cursor;
                END
                ELSE IF @Tables LIKE ''SCHEMAS:%''
                BEGIN
                    -- Grant on schema level for specified schemas
                    DECLARE @SchemaListForPerms NVARCHAR(MAX) = SUBSTRING(@Tables, 9, LEN(@Tables));
                    PRINT N''Granting VIEW CHANGE TRACKING on schemas: '' + @SchemaListForPerms;

                    -- Parse schema list and grant on each schema''''s CT-enabled tables
                    DECLARE @Schema NVARCHAR(128);
                    DECLARE @TempSchemasForPerms NVARCHAR(MAX) = @SchemaListForPerms;

                    WHILE LEN(@TempSchemasForPerms) > 0
                    BEGIN
                        DECLARE @SchemaPosPerm INT = CHARINDEX('','', @TempSchemasForPerms);
                        IF @SchemaPosPerm = 0
                        BEGIN
                            SET @Schema = LTRIM(RTRIM(@TempSchemasForPerms));
                            SET @TempSchemasForPerms = N'''';
                        END
                        ELSE
                        BEGIN
                            SET @Schema = LTRIM(RTRIM(LEFT(@TempSchemasForPerms, @SchemaPosPerm - 1)));
                            SET @TempSchemasForPerms = SUBSTRING(@TempSchemasForPerms, @SchemaPosPerm + 1, LEN(@TempSchemasForPerms));
                        END

                        IF LEN(@Schema) > 0
                        BEGIN
                            -- Grant on all CT-enabled tables in this schema
                            DECLARE schema_ct_cursor CURSOR FOR
                                SELECT t.name
                                FROM sys.change_tracking_tables ct
                                INNER JOIN sys.tables t ON ct.object_id = t.object_id
                                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                                WHERE s.name = @Schema
                                ORDER BY t.name;

                            OPEN schema_ct_cursor;
                            FETCH NEXT FROM schema_ct_cursor INTO @CTTable;

                            WHILE @@FETCH_STATUS = 0
                            BEGIN
                                BEGIN TRY
                                    SET @SQL = N''GRANT VIEW CHANGE TRACKING ON ['' + @Schema + ''].['' + @CTTable + ''] TO '' + QUOTENAME(@DatabaseUser);
                                    EXEC sp_executesql @SQL;
                                    PRINT N''  ✓ Granted VIEW CHANGE TRACKING on ['' + @Schema + ''].['' + @CTTable + '']'';
                                    SET @PermissionGrantCount = @PermissionGrantCount + 1;
                                END TRY
                                BEGIN CATCH
                                    PRINT N''  ⚠ Could not grant VIEW CHANGE TRACKING on ['' + @Schema + ''].['' + @CTTable + '']: '' + ERROR_MESSAGE();
                                    SET @PermissionErrorCount = @PermissionErrorCount + 1;
                                END CATCH

                                FETCH NEXT FROM schema_ct_cursor INTO @CTTable;
                            END

                            CLOSE schema_ct_cursor;
                            DEALLOCATE schema_ct_cursor;
                        END
                    END
                END
                ELSE
                BEGIN
                    -- Grant on specific tables listed in @Tables
                    PRINT N''Granting VIEW CHANGE TRACKING on specified tables...'';

                    -- Use the same @TargetTables that were processed for CT enablement
                    DECLARE specific_ct_cursor CURSOR FOR
                        SELECT SchemaName, TableName FROM @TargetTables
                        WHERE EXISTS (
                            SELECT 1 FROM sys.change_tracking_tables ct
                            INNER JOIN sys.tables t ON ct.object_id = t.object_id
                            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                            WHERE s.name = SchemaName AND t.name = TableName
                        )
                        ORDER BY SchemaName, TableName;

                    OPEN specific_ct_cursor;
                    FETCH NEXT FROM specific_ct_cursor INTO @CTSchema, @CTTable;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        BEGIN TRY
                            SET @SQL = N''GRANT VIEW CHANGE TRACKING ON ['' + @CTSchema + ''].['' + @CTTable + ''] TO '' + QUOTENAME(@DatabaseUser);
                            EXEC sp_executesql @SQL;
                            PRINT N''  ✓ Granted VIEW CHANGE TRACKING on ['' + @CTSchema + ''].['' + @CTTable + '']'';
                            SET @PermissionGrantCount = @PermissionGrantCount + 1;
                        END TRY
                        BEGIN CATCH
                            PRINT N''  ⚠ Could not grant VIEW CHANGE TRACKING on ['' + @CTSchema + ''].['' + @CTTable + '']: '' + ERROR_MESSAGE();
                            SET @PermissionErrorCount = @PermissionErrorCount + 1;
                        END CATCH

                        FETCH NEXT FROM specific_ct_cursor INTO @CTSchema, @CTTable;
                    END

                    CLOSE specific_ct_cursor;
                    DEALLOCATE specific_ct_cursor;
                END

                -- Permission grant summary report
                PRINT N'''';
                PRINT N''VIEW CHANGE TRACKING permission summary:'';
                PRINT N''  - Tables granted: '' + CAST(@PermissionGrantCount AS NVARCHAR(10));
                PRINT N''  - Tables with permission errors: '' + CAST(@PermissionErrorCount AS NVARCHAR(10));

                IF @PermissionGrantCount > 0
                    PRINT N''✓ VIEW CHANGE TRACKING permissions granted to user: '' + @DatabaseUser;
            END

            -- Final summary report
            PRINT N'''';
            PRINT N''CT setup summary:'';
            PRINT N''  - Tables processed: '' + CAST(@ProcessedCount AS NVARCHAR(10));
            PRINT N''  - Tables already enabled: '' + CAST(@SkippedCount AS NVARCHAR(10));
            PRINT N''  - Tables with processing errors: '' + CAST(@ErrorCount AS NVARCHAR(10));
            PRINT N''  - Tables skipped (no PK): '' + CAST(@SkippedTablesCount AS NVARCHAR(10));
        END

        PRINT N''Change tracking setup completed successfully'';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ''Error in lakeflowSetupChangeTracking: '' + ERROR_MESSAGE();
        PRINT @ErrorMessage;
        THROW;
    END CATCH
END';
PRINT N'Created lakeflowSetupChangeTracking procedure';

-- Create lakeflowSetupChangeDataCapture
PRINT N'Creating lakeflowSetupChangeDataCapture procedure...';
EXEC sp_executesql N'
CREATE PROCEDURE dbo.lakeflowSetupChangeDataCapture
    @Tables NVARCHAR(MAX) = NULL,
    @User NVARCHAR(128) = NULL,
    @Mode NVARCHAR(10) = ''INSTALL''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DatabaseUser NVARCHAR(128) = @User;
    DECLARE @Platform NVARCHAR(50) = dbo.lakeflowDetectPlatform();
    DECLARE @CatalogName NVARCHAR(128) = DB_NAME();
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @versionSuffix NVARCHAR(10) = ''_1_3'';
    DECLARE @captureInstanceTableName NVARCHAR(100) = ''lakeflowCaptureInstanceInfo'' + @versionSuffix;
    DECLARE @alterTableTriggerName NVARCHAR(100) = ''lakeflowAlterTableTrigger'' + @versionSuffix;
    DECLARE @disableOldCaptureInstanceProcName NVARCHAR(100) = ''lakeflowDisableOldCaptureInstance'' + @versionSuffix;
    DECLARE @mergeCaptureInstancesProcName NVARCHAR(100) = ''lakeflowMergeCaptureInstances'' + @versionSuffix;
    DECLARE @refreshCaptureInstanceProcName NVARCHAR(100) = ''lakeflowRefreshCaptureInstance'' + @versionSuffix;

    -- Error codes and messages
    DECLARE @invalidModeErrorCode INT = 100000;
    DECLARE @invalidModeErrorMessage NVARCHAR(200);
    DECLARE @insufficientUserPrivilegesCode INT = 100400;
    DECLARE @insufficientUserPrivilegesErrorMessage NVARCHAR(200);

    SET @invalidModeErrorMessage = CONCAT(''Provided execution mode: '', @Mode, '', is not recognized. Allowed values are: INSTALL, CLEANUP'');
    SET @insufficientUserPrivilegesErrorMessage = ''User executing this script is not a ''''db_owner'''' role member. To execute this script, please use a user that is.'';

    PRINT N''Starting Change Data Capture setup for: '' + @CatalogName;
    PRINT N''Platform: '' + @Platform;
    PRINT N''Mode: '' + @Mode;
    IF @Tables IS NOT NULL
        PRINT N''Tables: '' + @Tables;

    BEGIN TRY
        -- Validate execution mode
        IF (@Mode != ''INSTALL'' AND @Mode != ''CLEANUP'')
        BEGIN
            THROW @invalidModeErrorCode, @invalidModeErrorMessage, 1;
        END

        -- Validate that current user is db_owner
        IF (IS_ROLEMEMBER(''db_owner'') = 0)
        BEGIN
            THROW @insufficientUserPrivilegesCode, @insufficientUserPrivilegesErrorMessage, 1;
        END

        -- Cleanup legacy DDL support objects
        IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''replicate_io_audit_ddl_trigger_1'' AND parent_class = 0)
            OR OBJECT_ID(''dbo.replicate_io_audit_ddl_1'', ''U'') IS NOT NULL
            OR OBJECT_ID(''dbo.replicate_io_audit_tbl_cons_1'', ''U'') IS NOT NULL
            OR OBJECT_ID(''dbo.replicate_io_audit_tbl_schema_1'', ''U'') IS NOT NULL
            OR EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''alterTableTrigger_1'' AND parent_class = 0)
            OR OBJECT_ID(''dbo.disableOldCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.refreshCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.mergeCaptureInstance_1'', ''P'') IS NOT NULL
            OR OBJECT_ID(''dbo.captureInstanceTracker_1'', ''U'') IS NOT NULL
        BEGIN
            PRINT N''Cleaning up legacy DDL support objects...'';

            IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = ''replicate_io_audit_ddl_trigger_1'' AND parent_class = 0)
            BEGIN
                EXEC(''DROP TRIGGER replicate_io_audit_ddl_trigger_1 ON DATABASE'');
                PRINT N''✓ Dropped legacy trigger: replicate_io_audit_ddl_trigger_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_ddl_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_ddl_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_ddl_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_tbl_cons_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_tbl_cons_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_tbl_cons_1'';
            END

            IF OBJECT_ID(''dbo.replicate_io_audit_tbl_schema_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.replicate_io_audit_tbl_schema_1'');
                PRINT N''✓ Dropped legacy table: replicate_io_audit_tbl_schema_1'';
            END

            IF EXISTS (SELECT name FROM sys.triggers WHERE name = ''alterTableTrigger_1'' AND type = ''TR'')
            BEGIN
                EXEC(''DROP TRIGGER alterTableTrigger_1 ON DATABASE'');
                PRINT N''✓ Dropped legacy trigger: alterTableTrigger_1'';
            END

            IF OBJECT_ID(''dbo.disableOldCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.disableOldCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: disableOldCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.refreshCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.refreshCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: refreshCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.mergeCaptureInstance_1'', ''P'') IS NOT NULL
            BEGIN
                EXEC(''DROP PROCEDURE dbo.mergeCaptureInstance_1'');
                PRINT N''✓ Dropped legacy procedure: mergeCaptureInstance_1'';
            END

            IF OBJECT_ID(''dbo.captureInstanceTracker_1'', ''U'') IS NOT NULL
            BEGIN
                EXEC(''DROP TABLE dbo.captureInstanceTracker_1'');
                PRINT N''✓ Dropped legacy table: captureInstanceTracker_1'';
            END

            PRINT N''Legacy DDL support objects cleanup completed'';
        END

        -- Cleanup mode: Remove DDL support objects
        IF @Mode = ''CLEANUP''
        BEGIN
            PRINT N''Cleaning up CDC DDL support objects...'';

            -- Drop procedures
            IF OBJECT_ID(''dbo.'' + @refreshCaptureInstanceProcName, ''P'') IS NOT NULL
            BEGIN
                SET @SQL = N''DROP PROCEDURE [dbo].['' + @refreshCaptureInstanceProcName + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped procedure: '' + @refreshCaptureInstanceProcName;
            END

            IF OBJECT_ID(''dbo.'' + @mergeCaptureInstancesProcName, ''P'') IS NOT NULL
            BEGIN
                SET @SQL = N''DROP PROCEDURE [dbo].['' + @mergeCaptureInstancesProcName + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped procedure: '' + @mergeCaptureInstancesProcName;
            END

            IF OBJECT_ID(''dbo.'' + @disableOldCaptureInstanceProcName, ''P'') IS NOT NULL
            BEGIN
                SET @SQL = N''DROP PROCEDURE [dbo].['' + @disableOldCaptureInstanceProcName + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped procedure: '' + @disableOldCaptureInstanceProcName;
            END

            -- Drop ALTER TABLE trigger
            IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = @alterTableTriggerName AND parent_class = 0)
            BEGIN
                SET @SQL = N''DROP TRIGGER ['' + @alterTableTriggerName + ''] ON DATABASE'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped ALTER TABLE trigger: '' + @alterTableTriggerName;
            END

            -- Drop capture instance table
            IF OBJECT_ID(''dbo.'' + @captureInstanceTableName, ''U'') IS NOT NULL
            BEGIN
                SET @SQL = N''DROP TABLE [dbo].['' + @captureInstanceTableName + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Dropped capture instance table: '' + @captureInstanceTableName;
            END

            -- Pattern-based cleanup for any remaining CDC objects across versions
            DECLARE @cdcCleanupSql NVARCHAR(MAX) = '''';

            -- Clean up any remaining capture instance tables across versions
            SELECT @cdcCleanupSql = @cdcCleanupSql + ''DROP TABLE [dbo].['' + name + ''];'' + CHAR(13)
            FROM sys.tables
            WHERE name LIKE ''lakeflowCaptureInstanceInfo_%_%'' AND name != @captureInstanceTableName;

            IF LEN(@cdcCleanupSql) > 0
            BEGIN
                EXEC sp_executesql @cdcCleanupSql;
                PRINT N''✓ Cleaned up remaining capture instance tables across versions'';
            END

            -- Clean up any remaining CDC procedures across versions
            SET @cdcCleanupSql = '''';
            SELECT @cdcCleanupSql = @cdcCleanupSql + ''DROP PROCEDURE [dbo].['' + name + ''];'' + CHAR(13)
            FROM sys.procedures
            WHERE (name LIKE ''lakeflowDisableOldCaptureInstance_%_%'' AND name != @disableOldCaptureInstanceProcName)
               OR (name LIKE ''lakeflowMergeCaptureInstances_%_%'' AND name != @mergeCaptureInstancesProcName)
               OR (name LIKE ''lakeflowRefreshCaptureInstance_%_%'' AND name != @refreshCaptureInstanceProcName);

            IF LEN(@cdcCleanupSql) > 0
            BEGIN
                EXEC sp_executesql @cdcCleanupSql;
                PRINT N''✓ Cleaned up remaining CDC procedures across versions'';
            END

            -- Clean up any remaining ALTER TABLE triggers across versions
            SET @cdcCleanupSql = '''';
            SELECT @cdcCleanupSql = @cdcCleanupSql + ''DROP TRIGGER ['' + name + ''] ON DATABASE;'' + CHAR(13)
            FROM sys.triggers
            WHERE name LIKE ''lakeflowAlterTableTrigger_%_%'' AND name != @alterTableTriggerName AND parent_class = 0;

            IF LEN(@cdcCleanupSql) > 0
            BEGIN
                EXEC sp_executesql @cdcCleanupSql;
                PRINT N''✓ Cleaned up remaining ALTER TABLE triggers across versions'';
            END

            PRINT N''CDC DDL support objects cleanup completed'';
            RETURN;
        END

        -- Install mode: Create/upgrade DDL support objects
        PRINT N''Installing/upgrading CDC DDL support objects...'';

        -- Enable CDC at database level if not already enabled
        IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_cdc_enabled = 1)
        BEGIN
            PRINT N''Enabling Change Data Capture at database level...'';
            EXEC sys.sp_cdc_enable_db;
            PRINT N''✓ Change Data Capture enabled at database level'';
        END
        ELSE
        BEGIN
            PRINT N''ℹ Change Data Capture already enabled at database level'';
        END

        -- Create capture instance table
        IF OBJECT_ID(''dbo.'' + @captureInstanceTableName, ''U'') IS NULL
        BEGIN
            SET @SQL = N''CREATE TABLE [dbo].['' + @captureInstanceTableName + ''](
                [oldCaptureInstance] VARCHAR(MAX) NULL,
                [newCaptureInstance] VARCHAR(MAX) NULL,
                [schemaName] VARCHAR(100) NOT NULL,
                [tableName] VARCHAR(255) NOT NULL,
                [committedCursor] VARCHAR(MAX) NULL,
                [triggerReinit] BIT NULL,
                CONSTRAINT replicantCaptureInstanceInfoPrimaryKey PRIMARY KEY (schemaName, tableName)
            )'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Created capture instance table: '' + @captureInstanceTableName;
        END

        -- Create lakeflowDisableOldCaptureInstance procedure
        IF OBJECT_ID(''dbo.'' + @disableOldCaptureInstanceProcName, ''P'') IS NULL
        BEGIN
            SET @SQL = N''CREATE PROCEDURE [dbo].['' + @disableOldCaptureInstanceProcName + '']
                @schemaName VARCHAR(MAX), @tableName VARCHAR(MAX)
            WITH EXECUTE AS OWNER
            AS
            SET NOCOUNT ON

            DECLARE @oldCaptureInstance NVARCHAR(MAX);

            BEGIN TRAN
                SET @oldCaptureInstance = (SELECT oldCaptureInstance FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName AND tableName=@tableName);

                -- Only disable capture instances that we own (have lakeflow prefix and our naming convention)
                IF @oldCaptureInstance IS NOT NULL AND @oldCaptureInstance LIKE ''''lakeflow[_]%[_][1-2]''''
                BEGIN
                    EXEC sys.sp_cdc_disable_table
                        @source_schema = @schemaName,
                        @source_name = @tableName,
                        @capture_instance = @oldCaptureInstance;
                    UPDATE dbo.['' + @captureInstanceTableName + ''] SET oldCaptureInstance=NULL WHERE schemaName=@schemaName AND tableName=@tableName;
                END
            COMMIT TRAN'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Created procedure: '' + @disableOldCaptureInstanceProcName;
        END

        -- Create lakeflowMergeCaptureInstances procedure
        IF OBJECT_ID(''dbo.'' + @mergeCaptureInstancesProcName, ''P'') IS NULL
        BEGIN
            SET @SQL = N''CREATE PROCEDURE [dbo].['' + @mergeCaptureInstancesProcName + '']
                @schemaName VARCHAR(MAX), @tableName VARCHAR(MAX)
            AS
            SET NOCOUNT ON
            BEGIN TRAN
                DECLARE @newCaptureInstanceFullPath NVARCHAR(MAX),
                    @oldCaptureInstanceFullPath NVARCHAR(MAX),
                    @columnList NVARCHAR(MAX),
                    @columnListValues NVARCHAR(MAX),
                    @oldCaptureInstanceName NVARCHAR(MAX),
                    @newCaptureInstanceName NVARCHAR(MAX),
                    @captureInstanceCount INT,
                    @minLSN VARCHAR(MAX),
                    @quotedFullTableName nvarchar(max),
                    @mergeSQL NVARCHAR(MAX);

                SET @quotedFullTableName = QUOTENAME(@schemaName) + ''''.'''' + QUOTENAME(@tableName);
                SET @captureInstanceCount = (SELECT COUNT(*) FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(@quotedFullTableName));
                IF (@captureInstanceCount = 2)
                BEGIN
                    SET @oldCaptureInstanceName = (SELECT oldCaptureInstance
                                           FROM dbo.['' + @captureInstanceTableName + '']
                                           WHERE schemaName = @schemaName and tableName = @tableName) + ''''_CT'''';
                    SET @newCaptureInstanceName = (SELECT newCaptureInstance
                                           FROM dbo.['' + @captureInstanceTableName + '']
                                           WHERE schemaName = @schemaName and tableName = @tableName) + ''''_CT'''';
                    SET @newCaptureInstanceFullPath = ''''[cdc].'''' + QUOTENAME(@newCaptureInstanceName);
	                SET @oldCaptureInstanceFullPath = ''''[cdc].'''' + QUOTENAME(@oldCaptureInstanceName);
                    SET @minLSN = (SELECT committedCursor FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName and tableName=@tableName);

                    IF @minLSN is NULL OR @minLSN = ''''''''
                    BEGIN
                        SET @minLSN = ''''0x00000000000000000000''''
                    END

						SET @columnList = (SELECT STUFF((SELECT '''','''' + QUOTENAME(A.COLUMN_NAME)
												   FROM INFORMATION_SCHEMA.COLUMNS A
													   JOIN INFORMATION_SCHEMA.COLUMNS B ON
														   A.COLUMN_NAME=B.COLUMN_NAME AND
														   A.DATA_TYPE=B.DATA_TYPE
													   WHERE A.TABLE_NAME=@newCaptureInstanceName AND
														   A.TABLE_SCHEMA=''''cdc'''' AND
														   B.TABLE_NAME=@oldCaptureInstanceName AND
														   B.TABLE_SCHEMA=''''cdc'''' FOR XML PATH(''''''''), TYPE).value(''''.'''', ''''nvarchar(max)''''), 1, 1, ''''''''));

						SET @columnListValues = (SELECT STUFF((SELECT '''',source.'''' + QUOTENAME(A.COLUMN_NAME)
														 FROM INFORMATION_SCHEMA.COLUMNS A
															 JOIN INFORMATION_SCHEMA.COLUMNS B ON
																 A.COLUMN_NAME=B.COLUMN_NAME AND
																 A.DATA_TYPE=B.DATA_TYPE
														 WHERE
															 A.TABLE_NAME=@newCaptureInstanceName AND
															 A.TABLE_SCHEMA=''''cdc'''' AND
															 B.TABLE_NAME=@oldCaptureInstanceName AND
															 B.TABLE_SCHEMA=''''cdc'''' FOR XML PATH(''''''''), TYPE).value(''''.'''', ''''nvarchar(max)''''), 1, 1, ''''''''));

                    SET @mergeSQL = ''''MERGE '''' + @newCaptureInstanceFullPath + '''' AS target USING '''' + @oldCaptureInstanceFullPath + '''' AS source ON source.__$start_lsn = target.__$start_lsn AND source.__$seqval = target.__$seqval AND source.__$operation = target.__$operation WHEN NOT MATCHED AND source.__$start_lsn > '''' + @minLSN + '''' THEN INSERT ('''' + @columnList + '''') VALUES ('''' + @columnListValues + '''');'''';
                    EXEC sp_executesql @mergeSQL;
                END
            COMMIT TRAN'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Created procedure: '' + @mergeCaptureInstancesProcName;
        END

        -- Create lakeflowRefreshCaptureInstance procedure
        IF OBJECT_ID(''dbo.'' + @refreshCaptureInstanceProcName, ''P'') IS NULL
        BEGIN
            SET @SQL = N''CREATE PROCEDURE [dbo].['' + @refreshCaptureInstanceProcName + '']
                @schemaName NVARCHAR(MAX),
                @tableName NVARCHAR(MAX),
                @reinit INT = 0
            WITH EXECUTE AS OWNER
            AS
            SET NOCOUNT ON

            BEGIN TRAN
                DECLARE @OldCaptureInstance NVARCHAR(MAX),
                    @NewCaptureInstance NVARCHAR(MAX),
                    @FileGroupName NVARCHAR(255),
                    @SupportNetChanges BIT,
                    @RoleName VARCHAR(255),
                    @CaptureInstanceCount INT,
                    @TriggerReinit INT,
                    @SkipCaptureInstanceCreation INT,
                    @LakeflowInstanceCount INT,
                    @OldestLakeflowInstanceForReinit NVARCHAR(MAX),
                    @BothLakeflowErrorMsg NVARCHAR(500),
                    @LakeflowInstanceToDrop NVARCHAR(MAX),
                    @CommittedCursor VARCHAR(MAX),
                    @OldInstanceToTrack nvarchar(max),
                    @QuotedFullName nvarchar(max);

                SET @QuotedFullName = QUOTENAME(@schemaName) + ''''.'''' + QUOTENAME(@tableName);
                SET @SkipCaptureInstanceCreation = 0;
                SET @TriggerReinit = 0;

                SET @CaptureInstanceCount = (SELECT COUNT(capture_instance) FROM cdc.change_tables WHERE source_object_id = object_id(@QuotedFullName));
                IF (@CaptureInstanceCount = 2)
                BEGIN
                    -- Always signal reinit when we hit the 2-instance limit (except during reinit recovery)
                    SET @TriggerReinit = 1;

                    -- Check if we have a lakeflow instance to drop
                    SET @LakeflowInstanceCount = (SELECT COUNT(capture_instance) FROM cdc.change_tables WHERE source_object_id = object_id(@QuotedFullName) AND capture_instance LIKE ''''lakeflow[_]%[_][1-2]'''');

                    IF (@LakeflowInstanceCount = 2)
                    BEGIN
                        IF (@reinit = 1)
                        BEGIN
                            SET @TriggerReinit = 0;

                            -- During reinit, if we have 2 lakeflow instances, drop the oldest one
                            SET @OldestLakeflowInstanceForReinit = (
                                SELECT TOP 1 capture_instance
                                FROM cdc.change_tables
                                WHERE source_object_id = object_id(@QuotedFullName)
                                    AND capture_instance LIKE ''''lakeflow[_]%[_][1-2]''''
                                ORDER BY create_date ASC
                            );

                            IF @OldestLakeflowInstanceForReinit IS NOT NULL
                            BEGIN
                                PRINT ''''Reinit recovery: Dropping oldest lakeflow instance '''''''''''' + @OldestLakeflowInstanceForReinit + '''''''''''' to free up a slot for table '''' + @QuotedFullName;
                                EXEC sys.sp_cdc_disable_table
                                    @source_schema = @schemaName,
                                    @source_name = @tableName,
                                    @capture_instance = @OldestLakeflowInstanceForReinit;
                            END
                        END
                        ELSE
                        BEGIN
                            -- During DDL refresh (not reinit), both instances are lakeflow instances
                            -- Drop the oldest lakeflow instance without merging to free up a slot
                            SET @OldestLakeflowInstanceForReinit = (
                                SELECT TOP 1 capture_instance
                                FROM cdc.change_tables
                                WHERE source_object_id = object_id(@QuotedFullName)
                                    AND capture_instance LIKE ''''lakeflow[_]%[_][1-2]''''
                                ORDER BY create_date ASC
                            );

                            IF @OldestLakeflowInstanceForReinit IS NOT NULL
                            BEGIN
                                EXEC sys.sp_cdc_disable_table
                                    @source_schema = @schemaName,
                                    @source_name = @tableName,
                                    @capture_instance = @OldestLakeflowInstanceForReinit;
                            END
                        END
                    END
                    ELSE IF (@LakeflowInstanceCount = 1)
                    BEGIN
                        -- One lakeflow instance and one pre-existing instance
                        -- Drop lakeflow instance without merging to preserve pre-existing instance
                        -- The extractor will handle reinitialization after the new instance is created

                        -- Get the lakeflow instance to drop (oldest one)
                        SET @LakeflowInstanceToDrop = (
                            SELECT TOP 1 capture_instance
                            FROM cdc.change_tables
                            WHERE source_object_id = object_id(@QuotedFullName)
                                AND capture_instance LIKE ''''lakeflow[_]%[_][1-2]''''
                            ORDER BY create_date ASC
                        );

                        -- Drop it immediately to free up a slot
                        IF @LakeflowInstanceToDrop IS NOT NULL
                            EXEC sys.sp_cdc_disable_table
                                @source_schema = @schemaName,
                                @source_name = @tableName,
                                @capture_instance = @LakeflowInstanceToDrop;

                        -- Skip creating a new instance immediately - wait for reinit
                        SET @SkipCaptureInstanceCreation = 1;
                    END
                    ELSE
                    BEGIN
                        -- Both slots are taken by non-lakeflow instances
                        -- Cannot create lakeflow instance, but allow ADD COLUMN to complete
                        SET @SkipCaptureInstanceCreation = 1;
                    END
                END

                -- Get existing capture instance, preferring lakeflow instances that we own
                SET @OldCaptureInstance = (
                    select top 1 capture_instance
                    from cdc.change_tables
                    where source_object_id=OBJECT_ID(@QuotedFullName)
                        AND capture_instance LIKE ''''lakeflow[_]%[_][1-2]''''
                    order by create_date ASC
                );

                -- If no lakeflow instance exists, get the oldest instance to use its settings
                -- (but we will not drop it since it does not have lakeflow prefix)
                IF @OldCaptureInstance IS NULL
                BEGIN
                    SET @OldCaptureInstance = (
                        select top 1 capture_instance
                        from cdc.change_tables
                        where source_object_id=OBJECT_ID(@QuotedFullName)
                        order by create_date ASC
                    );

                    -- Warn about pre-existing non-lakeflow instance
                    IF @OldCaptureInstance IS NOT NULL
                    BEGIN
                        DECLARE @PreExistingWarningMsg NVARCHAR(500);
                        SET @PreExistingWarningMsg = ''''WARNING: Table '''' + @QuotedFullName + '''' has a pre-existing capture instance named '''''''''''' + @OldCaptureInstance + '''''''''''' that was not created by lakeflow. Lakeflow will preserve this instance and create its own instance alongside it. Settings (filegroup, role, supports_net_changes) will be copied from the pre-existing instance.'''';
                        PRINT @PreExistingWarningMsg;
                    END
                END
                SET @SupportNetChanges = (select top 1 supports_net_changes from cdc.change_tables where source_object_id=OBJECT_ID(@QuotedFullName) order by create_date ASC);
                SET @FileGroupName = (select top 1 filegroup_name from cdc.change_tables where source_object_id=OBJECT_ID(@QuotedFullName) order by create_date ASC);
                SET @RoleName = (select top 1 role_name from cdc.change_tables where source_object_id=OBJECT_ID(@QuotedFullName) order by create_date ASC);

                IF @OldCaptureInstance LIKE ''''lakeflow[_]%''''
                BEGIN
                    -- Toggle between _1 and _2 suffixes
                    IF @OldCaptureInstance LIKE ''''%[_]1''''
                    BEGIN
                        SET @NewCaptureInstance = ''''lakeflow_'''' + @schemaName + ''''_'''' + @tableName + ''''_2''''
                    END
                    ELSE
                    BEGIN
                        SET @NewCaptureInstance = ''''lakeflow_'''' + @schemaName + ''''_'''' + @tableName + ''''_1''''
                    END
                END
                ELSE
                BEGIN
                    -- First time or non-lakeflow instance: use lakeflow_schemaName_tableName_1
                    SET @NewCaptureInstance = ''''lakeflow_'''' + @schemaName + ''''_'''' + @tableName + ''''_1''''
                END

                -- Skip capture instance creation ONLY if we cannot create one (e.g., 2 non-lakeflow instances)
                IF @SkipCaptureInstanceCreation = 0
                BEGIN
                    BEGIN TRAN
                        EXEC sys.sp_cdc_enable_table
                            @source_schema = @schemaName,
                            @source_name   = @tableName,
                            @role_name     = @RoleName,
                            @capture_instance = @NewCaptureInstance,
                            @filegroup_name = @FileGroupName,
                            @supports_net_changes = @SupportNetChanges

                        SET @CommittedCursor = (SELECT committedCursor FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName AND tableName=@tableName);
                        DELETE FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName AND tableName=@tableName;

                        -- Only track lakeflow instances as "old" - do not track pre-existing non-lakeflow instances
                        IF @OldCaptureInstance LIKE ''''lakeflow[_]%[_][1-2]''''
                            SET @OldInstanceToTrack = @OldCaptureInstance;
                        ELSE
                            SET @OldInstanceToTrack = NULL;

                        INSERT INTO dbo.['' + @captureInstanceTableName + ''] VALUES (@OldInstanceToTrack, @NewCaptureInstance, @schemaName, @tableName, @CommittedCursor, @TriggerReinit);
                        IF (@reinit = 0 AND @OldInstanceToTrack IS NOT NULL)
                            EXEC dbo.'' + @mergeCaptureInstancesProcName + '' @schemaName, @tableName;
                    COMMIT TRAN
                END
                ELSE
                BEGIN
                    -- Cannot create capture instance (both slots taken by non-lakeflow instances)
                    -- Just insert tracking row with NULL values to signal reinit
                    BEGIN TRAN
                        SET @CommittedCursor = (SELECT committedCursor FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName AND tableName=@tableName);
                        DELETE FROM dbo.['' + @captureInstanceTableName + ''] WHERE schemaName=@schemaName AND tableName=@tableName;
                        INSERT INTO dbo.['' + @captureInstanceTableName + ''] VALUES (NULL, NULL, @schemaName, @tableName, @CommittedCursor, @TriggerReinit);
                    COMMIT TRAN
                END
            COMMIT TRAN'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Created procedure: '' + @refreshCaptureInstanceProcName;
        END

        -- Create ALTER TABLE trigger
        IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = @alterTableTriggerName AND parent_class = 0)
        BEGIN
            SET @SQL = N''CREATE TRIGGER ['' + @alterTableTriggerName + '']
                ON DATABASE FOR ALTER_TABLE
                AS
                BEGIN
                    SET NOCOUNT ON;

                    DECLARE @data XML = EVENTDATA();
                    DECLARE @DbName NVARCHAR(255) = DB_NAME();
                    DECLARE @schemaName NVARCHAR(MAX) = @data.value(''''(/EVENT_INSTANCE/SchemaName)[1]'''', ''''NVARCHAR(MAX)'''');
                    DECLARE @tableName NVARCHAR(255) = @data.value(''''(/EVENT_INSTANCE/ObjectName)[1]'''', ''''NVARCHAR(255)'''');
                    DECLARE @isColumnAdd NVARCHAR(255) = @data.value(''''(/EVENT_INSTANCE/AlterTableActionList/Create)[1]'''', ''''NVARCHAR(255)'''');
                    DECLARE @IsCdcEnabledDBLevel BIT = (SELECT is_cdc_enabled FROM sys.databases WHERE name=@DbName);
                    DECLARE @IsCdcEnabledTableLevel BIT = (SELECT is_tracked_by_cdc FROM sys.tables WHERE schema_id = SCHEMA_ID(@SchemaName) AND name = @TableName);

                    -- Only trigger refresh if CDC is enabled at both levels AND column add detected
                    IF (@IsCdcEnabledDBLevel = 1 AND @IsCdcEnabledTableLevel = 1 AND @isColumnAdd IS NOT NULL)
                    BEGIN
                        -- Refresh the capture instance for this table
                        EXEC [dbo].['' + @refreshCaptureInstanceProcName + ''] @SchemaName, @TableName;
                    END
                END'';
            EXEC sp_executesql @SQL;
            PRINT N''✓ Created ALTER TABLE trigger: '' + @alterTableTriggerName;
        END

        -- User resolution
        IF @User IS NOT NULL AND @User != ''''
        BEGIN
            -- Check if user exists as database user
            IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @User)
            BEGIN
                -- Check if it is a server login and find its mapped database user
                SELECT @DatabaseUser = dp.name
                FROM sys.database_principals dp
                INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
                WHERE sp.name = @User
                    AND dp.type IN (''S'', ''U'', ''G'')
                    AND dp.name NOT IN (''guest'');

                -- If still no database user found, warn and exit
                IF @DatabaseUser IS NULL OR @DatabaseUser = @User
                BEGIN
                    PRINT N''⚠ Warning: User/Login ['' + @User + ''] not found as database user. Skipping permission grants.'';
                    PRINT N''  To fix: CREATE USER ['' + @User + ''] FOR LOGIN ['' + @User + ''];'';
                    SET @DatabaseUser = NULL;
                END
                ELSE
                BEGIN
                    PRINT N''Server login ['' + @User + ''] maps to database user ['' + @DatabaseUser + ''].'';
                END
            END

            -- Special handling for dbo user - cannot grant permissions to dbo
            IF @DatabaseUser = ''dbo''
            BEGIN
                PRINT N''Skipping permission grants (dbo already has all permissions).'';
                SET @DatabaseUser = NULL;
            END
        END

        -- Grant permissions to user if specified
        IF @DatabaseUser IS NOT NULL
        BEGIN
            PRINT N''Granting CDC DDL support object permissions to user: '' + @DatabaseUser;
            BEGIN TRY
                SET @SQL = N''GRANT SELECT, UPDATE ON [dbo].['' + @captureInstanceTableName + ''] TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT VIEW DEFINITION TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT VIEW DATABASE STATE TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT SELECT ON SCHEMA::dbo TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT SELECT, INSERT ON SCHEMA::cdc TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT EXECUTE ON [dbo].['' + @disableOldCaptureInstanceProcName + ''] TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT EXECUTE ON [dbo].['' + @mergeCaptureInstancesProcName + ''] TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                SET @SQL = N''GRANT EXECUTE ON [dbo].['' + @refreshCaptureInstanceProcName + ''] TO ['' + @DatabaseUser + '']'';
                EXEC sp_executesql @SQL;
                PRINT N''✓ Granted CDC permissions to '' + @DatabaseUser;
            END TRY
            BEGIN CATCH
                PRINT N''⚠ Could not grant CDC permissions to '' + @DatabaseUser + '': '' + ERROR_MESSAGE();
            END CATCH
        END

        -- Process tables if specified
        IF @Tables IS NOT NULL
        BEGIN
            PRINT N''Processing tables for Change Data Capture enablement...'';

            DECLARE @TargetTables TABLE (
                SchemaName NVARCHAR(128),
                TableName NVARCHAR(128),
                HasPrimaryKey BIT
            );

            -- Parse table list and populate target tables
            IF @Tables = ''ALL''
            BEGIN
                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name,
                    t.name,
                    CASE WHEN EXISTS (
                        SELECT 1 FROM sys.key_constraints kc
                        WHERE kc.parent_object_id = t.object_id
                        AND kc.type = ''PK''
                    ) THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE t.is_ms_shipped = 0;
            END
            ELSE IF @Tables LIKE ''SCHEMAS:%''
            BEGIN
                DECLARE @SchemaList NVARCHAR(MAX) = SUBSTRING(@Tables, 9, LEN(@Tables));
                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name, t.name,
                    CASE WHEN pk.CONSTRAINT_NAME IS NOT NULL THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ON
                    pk.TABLE_SCHEMA = s.name AND pk.TABLE_NAME = t.name AND pk.CONSTRAINT_TYPE = ''PRIMARY KEY''
                WHERE t.type = ''U''
                    AND s.name IN (SELECT LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) AS value
                FROM (
                    SELECT CAST(''<M>'' + REPLACE(@SchemaList, '','', ''</M><M>'') + ''</M>'' AS XML) AS Data
                ) AS A
                CROSS APPLY Data.nodes(''/M'') AS Split(a)
                WHERE LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) != '''');
            END
            ELSE
            BEGIN
                DECLARE @TableList TABLE (FullTableName NVARCHAR(261));
                INSERT INTO @TableList (FullTableName)
                SELECT LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) AS value
                FROM (
                    SELECT CAST(''<M>'' + REPLACE(@Tables, '','', ''</M><M>'') + ''</M>'' AS XML) AS Data
                ) AS A
                CROSS APPLY Data.nodes(''/M'') AS Split(a)
                WHERE LTRIM(RTRIM(Split.a.value(''.'', ''NVARCHAR(MAX)''))) != '''';

                INSERT INTO @TargetTables (SchemaName, TableName, HasPrimaryKey)
                SELECT
                    s.name, t.name,
                    CASE WHEN pk.CONSTRAINT_NAME IS NOT NULL THEN 1 ELSE 0 END
                FROM sys.tables t
                INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                INNER JOIN @TableList tl ON
                    (tl.FullTableName = s.name + ''.*'' OR
                     tl.FullTableName = s.name + ''.'' + t.name OR
                     (CHARINDEX(''.'', tl.FullTableName) = 0 AND tl.FullTableName = t.name AND s.name = ''dbo''))
                LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ON
                    pk.TABLE_SCHEMA = s.name AND pk.TABLE_NAME = t.name AND pk.CONSTRAINT_TYPE = ''PRIMARY KEY''
                WHERE t.type = ''U'';
            END

            -- Process each table for CDC enablement
            DECLARE @CurrentSchema NVARCHAR(128), @CurrentTable NVARCHAR(128);
            DECLARE @ProcessedCount INT = 0, @SkippedCount INT = 0, @ErrorCount INT = 0;

            DECLARE table_cursor CURSOR FOR
                SELECT SchemaName, TableName FROM @TargetTables ORDER BY SchemaName, TableName;

            OPEN table_cursor;
            FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                BEGIN TRY
                    IF NOT EXISTS (
                        SELECT 1 FROM cdc.change_tables ct
                        INNER JOIN sys.tables t ON ct.source_object_id = t.object_id
                        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
                        WHERE s.name = @CurrentSchema AND t.name = @CurrentTable
                    )
                    BEGIN
                        EXEC sys.sp_cdc_enable_table
                            @source_schema = @CurrentSchema,
                            @source_name = @CurrentTable,
                            @role_name = NULL;
                        PRINT N''✓ Enabled CDC on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']'';
                        SET @ProcessedCount = @ProcessedCount + 1;
                    END
                    ELSE
                    BEGIN
                        PRINT N''ℹ CDC already enabled on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']'';
                        SET @SkippedCount = @SkippedCount + 1;
                    END
                END TRY
                BEGIN CATCH
                    PRINT N''✗ Error enabling CDC on ['' + @CurrentSchema + ''].['' + @CurrentTable + '']: '' + ERROR_MESSAGE();
                    SET @ErrorCount = @ErrorCount + 1;
                END CATCH

                FETCH NEXT FROM table_cursor INTO @CurrentSchema, @CurrentTable;
            END

            CLOSE table_cursor;
            DEALLOCATE table_cursor;

            -- Summary
            PRINT N'''';
            PRINT N''CDC setup summary:'';
            PRINT N''  - Tables processed: '' + CAST(@ProcessedCount AS NVARCHAR(10));
            PRINT N''  - Tables already enabled: '' + CAST(@SkippedCount AS NVARCHAR(10));
            PRINT N''  - Tables with errors: '' + CAST(@ErrorCount AS NVARCHAR(10));
        END

        PRINT N''Change Data Capture setup completed successfully'';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ''Error in lakeflowSetupChangeDataCapture: '' + ERROR_MESSAGE();
        PRINT @ErrorMessage;
        THROW;
    END CATCH
END';
PRINT N'Created lakeflowSetupChangeDataCapture procedure';

-- Final validation and summary
BEGIN
    PRINT N'';
    PRINT N'=== Installation Summary ===';
    DECLARE @Platform NVARCHAR(50) = dbo.lakeflowDetectPlatform();
    PRINT N'Platform: ' + @Platform;
    PRINT N'Version: ' + dbo.lakeflowUtilityVersion_1_1();

    -- Verify created objects
    IF OBJECT_ID('dbo.lakeflowDetectPlatform', 'FN') IS NOT NULL
        PRINT N'✓ lakeflowDetectPlatform function created successfully'
    ELSE
        PRINT N'✗ lakeflowDetectPlatform function creation failed';

    IF OBJECT_ID('dbo.lakeflowUtilityVersion_1_1', 'FN') IS NOT NULL
        PRINT N'✓ lakeflowUtilityVersion_1_1 function created successfully'
    ELSE
        PRINT N'✗ lakeflowUtilityVersion_1_1 function creation failed';

    IF OBJECT_ID('dbo.lakeflowFixPermissions', 'P') IS NOT NULL
        PRINT N'✓ lakeflowFixPermissions procedure created successfully'
    ELSE
        PRINT N'✗ lakeflowFixPermissions procedure creation failed';

    IF OBJECT_ID('dbo.lakeflowSetupChangeTracking', 'P') IS NOT NULL
        PRINT N'✓ lakeflowSetupChangeTracking procedure created successfully'
    ELSE
        PRINT N'✗ lakeflowSetupChangeTracking procedure creation failed';

    IF OBJECT_ID('dbo.lakeflowSetupChangeDataCapture', 'P') IS NOT NULL
        PRINT N'✓ lakeflowSetupChangeDataCapture procedure created successfully'
    ELSE
        PRINT N'✗ lakeflowSetupChangeDataCapture procedure creation failed';

    PRINT N'';
    PRINT N'=== Usage Examples ===';
    PRINT N'-- Table-specific setup:';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = ''dbo.Table1,Sales.Orders'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Enable change tracking on all user tables (auto-discovers, skips tables without PKs):';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = ''ALL'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Enable change tracking on all tables in specific schemas:';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = ''SCHEMAS:Sales,HR,Production'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Enable change tracking with wildcard support:';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = ''Sales.*,HR.Employees,dbo.SpecialTable'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Enable CDC on all user tables (processes tables with and without PKs):';
    PRINT N'EXEC dbo.lakeflowSetupChangeDataCapture @Tables = ''ALL'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Smart two-step approach for complete coverage:';
    PRINT N'-- Step 1: Enable CT on tables with primary keys';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = ''ALL'', @User = ''YourUsername'';';
    PRINT N'-- Step 2: Enable CDC on tables without primary keys';
    PRINT N'EXEC dbo.lakeflowSetupChangeDataCapture @Tables = ''ALL'', @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Fix permissions for a user:';
    PRINT N'EXEC dbo.lakeflowFixPermissions @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- Grant table permissions for specific tables:';
    PRINT N'EXEC dbo.lakeflowFixPermissions @User = ''YourUsername'', @Tables = ''ALL'';';
    PRINT N'EXEC dbo.lakeflowFixPermissions @User = ''YourUsername'', @Tables = ''Sales.*,HR.Employees'';';
    PRINT N'';
    PRINT N'-- Setup change tracking at database level only (no table processing):';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Tables = NULL, @User = ''YourUsername'';';
    PRINT N'';
    PRINT N'-- NOTE: The @User parameter is optional. If provided, the procedures will grant';
    PRINT N'-- the specified user permissions to access DDL support objects (audit tables, etc.)';
    PRINT N'-- This is useful for granting read access to change tracking metadata.';
    PRINT N'';
    PRINT N'-- Cleanup DDL support objects:';
    PRINT N'EXEC dbo.lakeflowSetupChangeTracking @Mode = ''CLEANUP'';';
    PRINT N'EXEC dbo.lakeflowSetupChangeDataCapture @Mode = ''CLEANUP'';';
    PRINT N'';
    PRINT N'=== Installation Complete ===';
    PRINT N'All utility objects have been installed successfully.';
    PRINT N'';
    PRINT N'=== Available Procedures ===';
    PRINT N'1. lakeflowFixPermissions - Fix user permissions for ingestion';
    PRINT N'2. lakeflowSetupChangeTracking - Setup change tracking and DDL audit objects';
    PRINT N'3. lakeflowSetupChangeDataCapture - Setup CDC and capture instance objects';
    PRINT N'';
    PRINT N'For more information, visit: https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/sql-server-source-setup';
END