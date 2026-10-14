# data_exporters/store_profiles.py
@data_exporter
def export_data_to_clickhouse(df: DataFrame, **kwargs) -> None:
    database = kwargs.get('SCHEMA_NAME', 'analytics')
    table_name = kwargs.get('DESTINATION_TABLE_NAME')
    config_path = path.join(get_repo_path(), 'io_config.yaml')

    ClickHouse.with_config(ConfigFileLoader(config_path, 'default')).export(
        df,
        table_name=table_name,
        database=database,
        index=False,
        if_exists='replace',   # for now we can get away with it
    )
