# Election App

The Election App is a secure and efficient voting system designed to prevent double voting. It utilizes cutting-edge facial recognition technology and geolocation data to ensure the integrity of the election process.

## Features

1. **Facial Recognition**: The app takes a picture of a voter and checks it against a database of previous voters to prevent double voting.
2. **Geolocation**: The app records the geolocation of the voter to ensure the voting process is carried out at authorized locations.
3. **Detailed Record**: For every vote cast, the app records the election box number, the list line number, and the geolocation data.
4. **Transparency**: If a double vote is detected, the app provides the details of the previous vote, including the election box number, list line number, and geolocation data, as well as the contact details of the previous submitter.

## How to Use

1. The user who controls the vote box takes a picture of the voter.
2. The app sends the picture, along with the election box number and the list line number, to the server.
3. The server checks the data against previous votes and returns a response.
4. If a double vote is detected, the app will return the details of the previous vote.

## Requirements

* A device with a camera and internet access.
* Access to the election box and list line number.
* Geolocation services must be enabled.

Please consult the respective directories for further details on the implementation and setup of the project.
