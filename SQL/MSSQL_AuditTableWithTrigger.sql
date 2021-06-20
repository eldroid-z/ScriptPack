USE <DBName>--Set DBName Here
GO
-------------------------------------------------------
-------------- Set Defaults Here ----------------------
-------------------------------------------------------
DECLARE @ActionTime NVARCHAR(100) = N'SYSUTCDATETIME()'
DECLARE @AuditPrefix NVARCHAR(100) = N'AT_'
DECLARE @TriggerPrefix NVARCHAR(100) = N'TrgAudit_'
-------------------------------------------------------
-------------------------------------------------------

DECLARE @DBCOLLATION NVARCHAR(100)
SELECT @DBCOLLATION  = d.collation_name 
FROM sys.databases d
WHERE d.name = DB_NAME()

DECLARE @ColsQuery NVARCHAR(MAX)
DECLARE @AuditTable NVARCHAR(128)

DECLARE @TableId int, @TableName NVARCHAR(128), @SchemaName NVARCHAR(128)

DECLARE cur_Tables CURSOR LOCAL FORWARD_ONLY
FOR
	SELECT t.object_id [TableId], t.name AS TableName, s.name AS SchemaName
	FROM sys.tables t 
	INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
	WHERE t.[type] = 'U'
    	AND t.name NOT LIKE @AuditPrefix + '%' -- Ignore Audit Tables
	ORDER BY s.name, t.name

OPEN cur_Tables  
  
FETCH NEXT FROM cur_Tables   
INTO @TableId, @TableName, @SchemaName
  
WHILE @@FETCH_STATUS = 0  
BEGIN
    PRINT 'Creating Audit For ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)

  ---------------- Create Table -----------------
    SET @ColsQuery = ''

    SELECT @ColsQuery += ', ' + QUOTENAME(tc.ColumnName) + ' ' + UPPER(tc.ColumnType) 
                        + CASE WHEN tc.ColumnCollation IS NOT NULL AND tc.ColumnCollation <> @DBCOLLATION THEN ' COLLATE ' + tc.ColumnCollation ELSE '' END 
                        + ' NULL '
    FROM
    (	SELECT s.name [ColumnName],
            CASE 
                WHEN t2.name IN ('char', 'nchar', 'binary')
                    THEN t2.name + '(' + CAST(s3.prec AS VARCHAR(100)) + ')'
                WHEN t2.name IN ('varchar', 'nvarchar', 'varbinary')
                    THEN t2.name + '(max)'
		WHEN t2.name IN ('decimal', 'numeric')
                    THEN t2.name + '(' + CAST(s3.prec AS VARCHAR(100)) + ',' + CAST(s3.scale AS VARCHAR(100)) + ')'
                ELSE t2.name
            END AS [ColumnType], s.collation_name [ColumnCollation], s3.colorder [ColumnOrder]
        FROM sys.tables t 
        INNER JOIN sys.columns s ON t.object_id  = s.object_id 
        INNER JOIN sys.types t2 ON s.system_type_id  = t2.user_type_id 
        INNER JOIN sys.schemas s2 ON s2.schema_id = t.schema_id
        INNER JOIN sys.syscolumns s3 ON s3.id = t.object_id AND s.name = s3.name 
        WHERE t.[type] = 'U'
        AND t.object_id = @TableId
    ) AS tc	
    ORDER BY tc.ColumnOrder ASC

    SET @AuditTable = @AuditPrefix + @TableName

    DECLARE @TableQuery NVARCHAR(MAX) = N'CREATE TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@AuditTable) + 
    ' (' + @AuditPrefix + 'Action CHAR(1) NOT NULL, ' + @AuditPrefix + 'ActionTime DATETIME2 NOT NULL DEFAULT(' + @ActionTime + ')' + @ColsQuery + ' ) ';

    ----------------- Create Update Trigger ---------------------------
    DECLARE @UpdateTriggerQuery NVARCHAR(MAX) = N'CREATE TRIGGER ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TriggerPrefix + 'Upd_' + @TableName) +
    ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + 
    ' FOR UPDATE AS ' +
    ' INSERT INTO ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@AuditTable) +
    ' SELECT ''U'', ' + @ActionTime + ', * FROM DELETED';

    ----------------- Create Delete Trigger ---------------------------
    DECLARE @DeleteTriggerQuery NVARCHAR(MAX) = N'CREATE TRIGGER ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TriggerPrefix + 'Del_' + @TableName) +
    ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + 
    ' FOR DELETE AS ' +
    ' INSERT INTO ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@AuditTable) +
    ' SELECT ''D'', ' + @ActionTime + ', * FROM DELETED';

    PRINT 'Creating Table'
    Exec (@TableQuery);
    PRINT 'Creating Insert Trigger'
    Exec (@UpdateTriggerQuery)
    PRINT 'Creating Delete Trigger'
    Exec (@DeleteTriggerQuery)

    FETCH NEXT FROM cur_Tables
    INTO @TableId, @TableName, @SchemaName
END
CLOSE cur_Tables;  
DEALLOCATE cur_Tables;  
