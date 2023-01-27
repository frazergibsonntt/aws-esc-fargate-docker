from fastapi import FastAPI

from .greeting import greet

app = FastAPI()


@app.get("/")
async def hello(name: str = "World"):
    message = greet(name)
    return {"message": message}
