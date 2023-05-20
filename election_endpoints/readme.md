# Voter Verification System

This is a voter verification system implemented using FastAPI, PostgreSQL, and machine learning libraries. The system aims to prevent double voting by using facial recognition to check if a voter has already cast a vote.

## Overview

The system uses facial recognition to create an embedding for each voter's face. These embeddings are stored in an Annoy index for efficient nearest neighbor search. When a new voter submits their vote, the system generates an embedding for their face and searches the Annoy index for a similar embedding. If a similar embedding is found, the system checks the details of the corresponding voter. If the details match the new voter's details, the system determines that the new voter has already voted.

## Setup

The system requires Python 3.7 or newer. The required Python packages can be installed with:

```bash
pip install -r requirements.txt
```

The system also requires a running PostgreSQL server. The connection details for the PostgreSQL server should be stored in a file named .dbconnection in the same directory as the script. The file should be a JSON file with the following format:

```
{
    "host": "<hostname>",
    "port": <port>,
    "database": "<database name>",
    "user": "<username>",
    "password": "<password>"
}
```
## Running the System

The system can be started with:

```
uvicorn main:app --reload
```

Once the system is running, it can be accessed at http://localhost:8000.

## Endpoints

The system provides the following endpoints:

* **GET /**: Returns a greeting message.
* **POST /voter-submit/**: Checks a new voter's photo and details to determine if they have already voted.
* **GET /voter-info/{election_box_number}/{voter_line_number}**: Returns the details of a voter with the specified election box number and voter line number.

## Limitations

The system's accuracy in preventing double voting depends on the quality of the photos submitted by voters and the distinctiveness of each voter's facial features.

The system does not currently support authentication or authorization. This means that anyone who can access the system's endpoints can submit votes or get voter details.

The system does not currently support horizontal scaling. The Annoy index is stored in memory and is not shared between instances of the system.

This README provides a basic overview of your project. You may need to adjust it based on your specific requirements and constraints. For example, you may need to provide more detailed setup instructions or describe additional endpoints.

