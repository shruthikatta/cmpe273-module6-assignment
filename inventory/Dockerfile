FROM python:3.12-alpine

WORKDIR /app
COPY server.py .

RUN adduser -D -u 1000 app
USER app

EXPOSE 8080
CMD ["python", "-u", "server.py"]
