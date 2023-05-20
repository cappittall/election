## 
from datetime import datetime
from typing import List
import cv2
import time
from fastapi import FastAPI, File, UploadFile, Form, Request
from pydantic import BaseModel
from pydantic import ValidationError
from fastapi.responses import JSONResponse
import asyncpg
from annoy import AnnoyIndex
import numpy as np
import torch
from facenet_pytorch import MTCNN, InceptionResnetV1
from fastapi import HTTPException
import warnings
import json
warnings.filterwarnings("ignore", category=UserWarning)

app = FastAPI()

# Initialize the list to store embeddings and the Annoy index for searching
voter_embeddings: List[np.ndarray] = []
index = AnnoyIndex(512, "euclidean")  # Assuming a 512-dimensional embedding, using Euclidean distance
voter_image_names = []
closest_voter_data = {}
index_built = False

# Create an MTCNN instance for face detection
mtcnn = MTCNN(image_size=160, margin=0, keep_all=True, device='cuda' if torch.cuda.is_available() else 'cpu')

# Create an InceptionResnetV1 instance for face embedding
resnet = InceptionResnetV1(pretrained='vggface2', device='cuda' if torch.cuda.is_available() else 'cpu').eval()

@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )

def get_shema_domain(request):
    shema= request.url.scheme
    domain=request.url.scheme + '://' + request.url.hostname + (':'+ str(request.url.port) if request.url.port else '')
    return shema, domain

@app.get("/")
def read_root():
    return {"Hello": "World"}



class VoterInfo(BaseModel):
    electionBoxNumber: int
    phoneNumber: str
    userName: str
    email: str
    voterLineNumber: str
    latitude: float
    longitude: float
    timestamp: str
    


async def insert_data(
    electionBoxNumber: int, 
    phoneNumber: str,
    userName: str,
    email: str,
    voterLineNumber: str, 
    latitude: float, 
    longitude: float, 
    image_path: str, 
    timestamp: str
):  
    conn = await asyncpg.connect(
        host="localhost",
        port="5432",
        database="secim",
        user="cappittall",
        password="Aura533422",
    )

    await conn.execute(
        """
        INSERT INTO oy_kullanan_kaydi (election_box_number, phone_number, user_name, email, voter_line_number, latitude, longitude, image_path, timestamp)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        """,
        electionBoxNumber, phoneNumber, userName, email, voterLineNumber, latitude, longitude, image_path, datetime.fromtimestamp(float(timestamp))
    )

    await conn.close()

async def get_voter_data(election_box_number: int, voter_line_number: str):
    async with asyncpg.create_pool(
        host="localhost",
        port="5432",
        database="secim",
        user="cappittall",
        password="Aura533422",
    ) as pool:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                """
                SELECT * FROM oy_kullanan_kaydi
                WHERE election_box_number = $1 AND voter_line_number = $2
                """,
                election_box_number, voter_line_number
            )
    return result

def generate_embedding(img):
    # Convert the image from BGR (OpenCV format) to RGB
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Detect face(s) using MTCNN and get the cropped face(s)
    cropped_faces = mtcnn(img_rgb)

    # If no faces are detected, return None
    if cropped_faces is None:
        print("No faces detected")
        return None

    # If multiple faces are detected, you might want to handle it differently.
    # For simplicity, we'll just use the first detected face in this example.
    face = cropped_faces[0]

    # Generate the face embedding using InceptionResnetV1
    with torch.no_grad():
        embedding = resnet(face.unsqueeze(0)).squeeze().cpu().numpy()

    return embedding
# Load the FaceNet model and create an Annoy index outside the endpoint
# (Assuming you have already set up the required libraries and downloaded the pre-trained FaceNet model)
# Load voter embeddings, create the Annoy index, and build it as shown in the previous example

@app.post("/voter-submit/")
async def check_photo(
    electionBoxNumber: int = Form(...),
    phoneNumber: str = Form(...),
    userName:str = Form(...),
    email:str = Form(...),
    voterLineNumber: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...),
    timestamp: str = Form(...)
):
    # Process the received data
    print('Here we go')
    global index_built
    
    # Save the uploaded image
    image_path = f"uploaded_images/{image.filename}"
    with open(image_path, "wb") as f:
        f.write(await image.read())
        
    voter_image_names.append(image.filename)

    # Read the image using OpenCV
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)

    # Generate the new voter's face embedding
    new_voter_embedding = generate_embedding(img)  # You'll need to implement this function
    
    # If no face is detected in the image, return an error or handle it as needed
    if new_voter_embedding is None:
        # Handle the case when no face is detected in the image
        # You can return an error message or take other appropriate actions
        raise HTTPException(status_code=404, detail="No face detected")
    # Check if the embedding is valid (i.e., a face was detected)
    else:
        # Add the new embedding to the list and index
        voter_embeddings.append(new_voter_embedding)
        index.add_item(len(voter_embeddings) - 1, new_voter_embedding)

        # Rebuild the index to include the new embedding if it's not built yet
        if not index_built:
            index.build(100)  # The number 100 is a parameter for the number of trees, you can adjust it according to your needs
            index_built = True
   


    # Search the index for the closest match
    closest_match_index, distance = index.get_nns_by_vector(new_voter_embedding, 1, include_distances=True)

    # Set a threshold for the similarity measure to determine whether the new voter is a duplicate
    similarity_threshold = 0.8
    duplicate = distance[0] < similarity_threshold
    
    if duplicate:
        # Handle duplicate voter
        print("Duplicate voter detected!")
        closest_image_name = voter_image_names[closest_match_index[0]]
        closest_voter_box_number, closest_voter_line_number = closest_image_name.split('_')
        # Get the closest voter's data from the database
        closest_voter_data = await get_voter_data(int(closest_voter_box_number), closest_voter_line_number)
        
        print('closest_voter_data', closest_voter_data)

    # You can now return the closest voter's data in your JSON response or process it as needed
    else:
        # Save the new voter's data and update the Annoy index
        await insert_data(electionBoxNumber, phoneNumber, userName, email, voterLineNumber, 
                          latitude, longitude, image_path, timestamp)
        
        index.add_item(len(voter_embeddings), new_voter_embedding)
        voter_embeddings.append(new_voter_embedding)

    print(electionBoxNumber, phoneNumber, voterLineNumber, latitude, longitude)
    print(f'Süre: {time.time()-float(timestamp)}')

    # Return a response
    response_content = {"duplicate": duplicate}
    if closest_voter_data:
        response_content.update(closest_voter_data)

    return JSONResponse(status_code=200, content=response_content)




""" response_content.update({
            "otherBoxNumber": closest_voter_data.get('election_box_number', None),
            "otherVoterLineNumber": closest_voter_data.get('voter_line_number', None),
            "otherLocation":  closest_voter_data.get('latitude', None) +','+ closest_voter_data.get('longitude', None),
            "otherUserName":  closest_voter_data.get('user_name', None),
            "otherPhoneNumber":  closest_voter_data.get('phone_number', None), 
            "email":  closest_voter_data.get('email', None),
            "timestamp":  closest_voter_data.get('timestamp', None)}) """
            
