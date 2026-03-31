FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn[standard] httpx python-dotenv pydantic
COPY main.py /app/
RUN mkdir -p /app/logs
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
