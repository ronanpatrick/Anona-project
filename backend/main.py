from fastapi import FastAPI


app = FastAPI(
    title="Anona Backend",
    description="FastAPI backend for the doomscroll-free news app.",
    version="0.1.0",
)


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}

