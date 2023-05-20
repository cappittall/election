# Election App

The Election App is a secure and efficient voting system designed to prevent double voting. It utilizes cutting-edge facial recognition technology and geolocation data to ensure the integrity of the election process.

## Features

1. **Facial Recognition**: The app takes a picture of a voter and checks it against a database of previous voters to prevent double voting.
2. **Geolocation**: The app records the geolocation of the voter to ensure the voting process is carried out at authorized locations.
3. **Detailed Record**: For every vote cast, the app records the election box number, the list line number, and the geolocation data.
4. **Transparency**: If a double vote is detected, the app provides the details of the previous vote, including the election box number, list line number, and geolocation data, as well as the contact details of the previous submitter.

## Components

### [election_endpoints](https://github.com/cappittall/election/tree/master/election_endpoints)

This is a FastAPI server designed to process and validate voter information. It receives the voter's image and other details, checks for any past voting records, and sends the results back to the app.

### [election_control](https://github.com/cappittall/election/tree/master/election_control)

This is a Flutter app used for interfacing with the user. It is responsible for capturing voter's image, gathering required data (such as the election box number and list line number), and sending this information to the `election_endpoints` server for validation. The app also receives and displays the results from the server.

## How to Use

1. Launch the `election_control` app on a device with a camera and internet access.
2. The user who controls the vote box takes a picture of the voter using the app.
3. The app sends the picture, along with the election box number and the list line number, to the `election_endpoints` server.
4. The server checks the data against previous votes and returns a response to the `election_control` app.
5. If a double vote is detected, the app will display the details of the previous vote.

## Requirements

* A device with a camera and internet access.
* Access to the election box and list line number.
* Geolocation services must be enabled.

Please consult the respective directories for further details on the implementation and setup of the project.


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

