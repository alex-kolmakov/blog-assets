# data_loaders/load_profiles.py
def find_freshest_file(directory_path: str, table_name: str):
    """Return (filename, exported_at) for the newest matching export."""
    pattern = fr'{table_name}(\d{{8}}_\d{{6}})\.csv\.gz'
    freshest_file, latest_time = None, None
    for filename in os.listdir(directory_path):
        match = re.search(pattern, filename)
        if match:
            file_time = datetime.strptime(match.group(1), '%Y%m%d_%H%M%S')
            if freshest_file is None or file_time > latest_time:
                freshest_file, latest_time = filename, file_time
    if freshest_file is None:
        raise FileNotFoundError(f"No valid file found for table {table_name}")
    return freshest_file, latest_time


@data_loader
def load_data_from_file(*args, **kwargs):
    directory_path = kwargs.get('DIRECTORY_PATH', './data')
    table_name = kwargs.get('SOURCE_TABLE_NAME')
    freshest_file, exported_at = find_freshest_file(directory_path, table_name)
    df = pd.read_csv(os.path.join(directory_path, freshest_file),
                     compression="gzip", dtype={'inn': str, 'phone': str})
    df['exported_at'] = exported_at          # the metadata that powers freshness later
    return df
