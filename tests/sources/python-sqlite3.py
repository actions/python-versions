import sqlite3
from sqlite3 import Error

def create_connection(db_file):
    """ create a database connection to a SQLite database """
    conn = None
    try:
        print('Sqlite3 version: ', sqlite3.version)
        conn = sqlite3.connect(db_file)
        conn.enable_load_extension(True)
    except Error as e:
        print(e)
        exit(1)
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    create_connection(r"pythonsqlite.db")