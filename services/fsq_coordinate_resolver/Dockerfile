FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Keep DuckDB's Iceberg and HTTP extensions inside the image. At runtime the
# service only loads them; it does not install software or persist any venue
# data to the container.
RUN python -c "import duckdb; connection = duckdb.connect(); connection.execute('INSTALL httpfs'); connection.execute('INSTALL iceberg')"

COPY main.py ./

CMD exec gunicorn --bind :${PORT} --workers 1 --threads 4 --timeout 120 main:app
