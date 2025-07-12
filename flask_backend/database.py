import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URI = os.getenv('DATABASE_URI', 'sqlite:///results.db')

Base = declarative_base()

# Remove check_same_thread for non-SQLite databases
connect_args = {"check_same_thread": False} if "sqlite" in DATABASE_URI else {}
engine = create_engine(DATABASE_URI, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)