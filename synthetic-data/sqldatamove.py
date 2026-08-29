import urllib
import pandas as pd
from sqlalchemy import create_engine

# 1. Create your sample DataFrame
data = {
    'employee_id':4,
    'name': 'Naveen', #['Alice', 'Bob', 'Charlie'],
    'department':'ITE' # ['HR', 'Engineering', 'Marketing']
}
df = pd.DataFrame(data,index=[0])

# 2. Define Azure SQL Configuration Variables
SERVER = 'sqlserverops-01.database.windows.net'  # Do not forget '.database.windows.net'
DATABASE = 'restaurentops'
USERNAME = 'admin_dbproject'
PASSWORD = 'YourPassword' #Replace with your password
# Use the exact name of the ODBC driver installed on your system (e.g., 'ODBC Driver 18 for SQL Server')
DRIVER = 'ODBC Driver 17 for SQL Server' 

# 3. Format the Connection Parameters
# Encrypt=yes and TrustServerCertificate=no are required for Azure SQL security
params = urllib.parse.quote_plus(
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
)

# 4. Create the SQLAlchemy Engine with speed optimizations
connection_string = f"mssql+pyodbc:///?odbc_connect={params}"
engine = create_engine(connection_string, fast_executemany=True)

# 5. Insert the DataFrame
try:
    df.to_sql(
        name='employees',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )
    print("Data successfully inserted into Azure SQL Database!")
except Exception as e:
    print(f"An error occurred: {e}")
