FROM python:3.12-alpine

WORKDIR /app
COPY client.py burst.py .

RUN adduser -D -u 1000 app
USER app

CMD ["python", "-u", "client.py"]
