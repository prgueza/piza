FROM python:3.8.3-slim

WORKDIR /usr/src/piza-backend

COPY requirements.txt requirements.txt

RUN apt-get update && apt-get -y install libpq-dev gcc
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

CMD ["python", "-u", "main.py"]
