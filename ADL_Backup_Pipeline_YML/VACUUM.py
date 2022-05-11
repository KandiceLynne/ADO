database_names_filter = "20_silver*"
try:
    dbs = spark.sql(f"SHOW DATABASES LIKE '{database_names_filter}'").select("databaseName").collect()
    dbs = [(row.databaseName) for row in dbs]
    for database_name in dbs:
        print(f"Found database: {database_name}, performing actions on all its tables..")
        tables = spark.sql(f"SHOW TABLES FROM `{database_name}`").select("tableName").collect()
        tables = [(row.tableName) for row in tables]
        for table_name in tables:
            #spark.sql(f"ALTER TABLE `{database_name}`.`{table_name}` SET TBLPROPERTIES ('delta.logRetentionDuration'='interval 30 days', 'delta.deletedFileRetentionDuration'='interval 7 days')")
            spark.sql(f"VACUUM `{database_name}`.`{table_name}`")
            spark.sql(f"ANALYZE TABLE `{database_name}`.`{table_name}` COMPUTE STATISTICS")
except Exception as e:
    raise Exception(
