# Query
Generates query to update the OnDelete and OnUpdate cascading effect on Constraints.


``` sql
SELECT CONCAT("ALTER TABLE `", t.TABLE_NAME, "` DROP FOREIGN KEY `", t.CONSTRAINT_NAME, "`;"
, " ALTER TABLE `", t.TABLE_NAME
, "` ADD CONSTRAINT `", t.CONSTRAINT_NAME
, "` FOREIGN KEY (`", t.COLUMN_NAME  , "`) REFERENCES `", t.REFERENCED_TABLE_NAME, "`(`", t.REFERENCED_COLUMN_NAME, "`)"
, " ON DELETE RESTRICT ON UPDATE RESTRICT;") as drop_create_constraint
FROM information_schema.KEY_COLUMN_USAGE t
INNER JOIN information_schema.REFERENTIAL_CONSTRAINTS r on t.CONSTRAINT_NAME = r.CONSTRAINT_NAME
WHERE r.DELETE_RULE = 'CASCADE' OR r.UPDATE_RULE = 'CASCADE'
```
Note : Works for Single Column Constraints.
