FROM python:3.9.4-buster
WORKDIR /hello
COPY . ./
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 8000
CMD python -m uvicorn hello.main:app --host 0.0.0.0 --port 8000