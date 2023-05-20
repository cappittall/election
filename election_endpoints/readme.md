# Voter Verification System

This is a voter verification system implemented using FastAPI, PostgreSQL, and machine learning libraries. The system aims to prevent double voting by using facial recognition to check if a voter has already cast a vote.

## Overview

The system uses facial recognition to create an embedding for each voter's face. These embeddings are stored in an Annoy index for efficient nearest neighbor search. When a new voter submits their vote, the system generates an embedding for their face and searches the Annoy index for a similar embedding. If a similar embedding is found, the system checks the details of the corresponding voter. If the details match the new voter's details, the system determines that the new voter has already voted.

## Setup

The system requires Python 3.7 or newer. The required Python packages can be installed with:

```bash
pip install fastapi uvicorn[standard] pydantic opencv-python-headless asyncpg annoy numpy torch facenet-pytorch pillow
