from fastapi import FastAPI, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.routers import tasks

# NOTE: create_all is fine for local/dev. In staging/prod this project
# will move to Alembic migrations run as a separate CI/CD step.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Task API",
    description="Simple CRUD API used as the workload for the AWS EKS GitOps platform project.",
    version="0.1.0",
)

app.include_router(tasks.router)


@app.get("/health", tags=["ops"])
def health():
    """Liveness probe: is the process up? No dependency checks."""
    return {"status": "ok"}


@app.get("/ready", tags=["ops"])
def ready(db: Session = Depends(get_db)):
    """Readiness probe: can the app actually serve traffic (DB reachable)?"""
    db.execute(text("SELECT 1"))
    return {"status": "ready"}
