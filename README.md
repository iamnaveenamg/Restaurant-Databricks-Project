# Restaurant Databricks Project

An end-to-end demo / POC that simulates a restaurant data pipeline: it generates synthetic customers, menus and historical orders, streams live order events into Azure Event Hubs, and provides scripts and ETL scaffolding for loading data into Azure SQL and downstream Databricks analytics. Useful for data engineers, analytics teams, and anyone building demos around Azure + Databricks ingestion and analytics.

![Architecture](project_architecture.png)

## Features

- Generate synthetic datasets: restaurants, customers, menu items, historical orders
- Stream simulated live orders to Azure Event Hubs
- Load CSV data into Azure SQL using SQLAlchemy/pyodbc
- ETL scaffolding for Databricks (gold/silver/source patterns)
- Example dashboard asset and email-notification notebook

## Stack

- Languages: Python (scripts & generators), Jupyter Notebooks, T-SQL (for SQL/ETL)
- Runtime / Platform: Databricks-oriented ETL, Azure Event Hubs, Azure SQL
- Notable libraries: pandas, faker, azure-eventhub, sqlalchemy / pyodbc

## Repository layout

```
Dashboard_Agent/         -> dashboard/visualization export (JSON)
ETLPipelines/            -> ETL pipeline scaffolds (metadata, silver/gold setups)
EmailNotification/       -> Jupyter notebook to send email notifications
synthetic-data/          -> scripts to generate synthetic data, stream events, and load to Azure SQL
  ├─ data/               -> generated CSV datasets (restaurants, customers, menu_items, historical_orders, reviews)
  ├─ 00_sql_db.py        -> generators for restaurants, menu items, customers (writes CSVs)
  ├─ 01_historical_orders.py
  ├─ 02_review.py
  ├─ 03_run.py
  ├─ 04_eventhub_orders.py -> Event Hub producer: generates & streams order events
  ├─ ReadandWriteSource.py  -> writes CSV data into Azure SQL using SQLAlchemy/pyodbc
  ├─ sqldatamove.py
  └─ requirements.txt
project_architecture.png -> architecture diagram for the solution
LICENSE
test.md / testfile.py
.gitignore
```

## Quickstart

Prerequisites
- Python 3.8+
- ODBC Driver for SQL Server (e.g., "ODBC Driver 17 for SQL Server") and pyodbc configured on your machine or environment
- Azure resources if you want to run the Event Hubs/SQL parts: Event Hub namespace + event hub, Azure SQL Server
- (Optional) Databricks workspace to run ETL notebooks

1) Install Python dependencies

```bash
python -m pip install -r synthetic-data/requirements.txt
```

2) Generate synthetic CSVs

```bash
python synthetic-data/00_sql_db.py
# outputs CSVs to synthetic-data/data/
```

3) Load CSVs into Azure SQL

- Update credentials in `synthetic-data/ReadandWriteSource.py` (SERVER, DATABASE, USERNAME, PASSWORD) or modify the script to read from environment variables.
- Ensure the correct ODBC driver name is set in the script (DRIVER variable).

```bash
python synthetic-data/ReadandWriteSource.py
```

4) Stream simulated live orders to Event Hub

- Create a `.env` file in `synthetic-data/` with:

```
EVENTHUB_CONNECTION_STRING=<your-connection-string>
EVENTHUB_NAME=<event-hub-name>
```

```bash
python synthetic-data/04_eventhub_orders.py
```

Use Ctrl+C to stop streaming or modify the script to set `max_orders`.

## Environment variables
- EVENTHUB_CONNECTION_STRING: Azure Event Hubs connection string
- EVENTHUB_NAME: Event Hub name
- (Optional) Use environment variables or a secrets store for Azure SQL credentials instead of hardcoding in the script

## ETL / Databricks
- The `ETLPipelines/` folder contains scaffolding for source -> silver -> gold setups and metadata. To complete the end-to-end demo you can import notebooks into Databricks, configure cluster/job, and point to the CSVs (or the Event Hub + streaming source) used in this repo.

## Notes & Security
- Do NOT commit real credentials. The current `ReadandWriteSource.py` contains placeholders for SERVER/USERNAME/PASSWORD — update to read from env vars for production use.
- ODBC driver names vary by platform. Adjust `DRIVER` in `ReadandWriteSource.py` to match your installed driver.

## Contributing
PRs welcome. Suggested improvements:
- Add a top-level README (you’re reading it!) with deployment scripts
- Add IaC (ARM/Bicep/Terraform) to provision Event Hubs, SQL, and Databricks
- Add Databricks notebooks and job definitions for the ETL pipeline

## License
This project is licensed under the terms in LICENSE in this repository.

## Contact
Created by @iamnaveenamg — feel free to open an issue or PR, or reach out on GitHub.
