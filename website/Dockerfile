FROM python:3.12-slim
WORKDIR /app
COPY server.py wiki.py ./
COPY static ./static
COPY import-example ./import
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOLIDAY_DATA_DIR=/app/data HOLIDAY_PHOTOS_DIR=/app/photos
EXPOSE 8000
CMD ["python", "server.py"]
