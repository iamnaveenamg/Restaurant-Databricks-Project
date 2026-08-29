import urllib
import pandas as pd
from sqlalchemy import create_engine
import os

# 1. Define Azure SQL Configuration Variables
SERVER = 'sqlserverops-01.database.windows.net'  # Do not forget '.database.windows.net'
DATABASE = 'restaurentops'
USERNAME = 'admin_dbproject'
PASSWORD = 'YourPassword' # We can replace the env varaibles also
# Use the exact name of the ODBC driver installed on your system (e.g., 'ODBC Driver 18 for SQL Server')
DRIVER = 'ODBC Driver 17 for SQL Server' 

# 2. Create df for your data
script_dir = os.path.dirname(os.path.abspath(__file__))
df_restaurants = pd.read_csv(os.path.join(script_dir, "data", "restaurants.csv"))
df_customers = pd.read_csv(os.path.join(script_dir, "data", "customers.csv"))
df_menu_items = pd.read_csv(os.path.join(script_dir, "data", "menu_items.csv"))
df_customer_reviews = pd.read_csv(os.path.join(script_dir, "data", "customer_reviews.csv"))
df_historical_orders = pd.read_csv(os.path.join(script_dir, "data", "historical_orders.csv"))

# Test Df's
# print(df_customers.head(5)) print(df_restaurants.head(5)) print(df_menu_items.head(5)) 
# print(df_customer_reviews.head(5)) 
#print(df_historical_orders[['order_id','items', 'total_amount']])

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


print("Data Insert into Azure SQL Database!")

# 5. Insert the DataFrame

try:
    print('1.Insert into Customers')
    df_customers.to_sql(
        name='customers',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )
    print('\n 2. Insert into Restaurents')
    df_restaurants.to_sql(
        name='restaurants',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )
    print('\n 3. Insert into menu items')
    df_menu_items.to_sql(
        name='menu_items',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )
    print('\n 5. Insert into historical Orders')
    df_historical_orders.to_sql(
        name='historical_orders',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )
    print('\n 4. Insert into customer reviews')
    df_customer_reviews.to_sql(
        name='reviews',         # Your Azure SQL table name
        con=engine,
        if_exists='append',       # Options: 'fail', 'replace', 'append'
        index=False,              # Exclude the pandas index
        chunksize=1000            # Break down data into batches
    )    
 
    print("Data successfully inserted into Azure SQL Database!")
except Exception as e:
    print(f"An error occurred: {e}")

