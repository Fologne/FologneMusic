FROM python:3.14.7-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN groupadd --gid 10001 fologne \
    && useradd --uid 10001 --gid 10001 --no-create-home fologne \
    && install -d -o fologne -g fologne /data
COPY requirements.txt requirements-production.txt ./
RUN pip install --no-cache-dir -r requirements-production.txt
COPY manage.py ./
COPY config ./config
COPY core ./core
USER 10001:10001
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--timeout", "30", "config.wsgi:application"]
