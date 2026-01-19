# Build Stage
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime Stage
FROM python:3.11-slim
WORKDIR /app

# Create non-root user [cite: 32]
RUN adduser --disabled-password --gecos '' appuser
USER appuser

# Copy installed packages from builder
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

COPY . .

# API exposes 8080, Worker exposes 8000
EXPOSE 8080 
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]