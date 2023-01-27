FROM python:3.9
WORKDIR /hello
COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt
COPY . ./
EXPOSE 8000
# CMD ["uvicorn", "hello.main:app", "--host", "0.0.0.0","--port","80"]
CMD python3 -m uvicorn hello.main:app --host 0.0.0.0 --port 8000