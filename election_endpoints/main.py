
from datetime import datetime
from typing import List
import cv2
from typing import Union
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
from fastapi.staticfiles import StaticFiles
from PIL import Image

import warnings
import json
warnings.filterwarnings("ignore", category=UserWarning)

app = FastAPI()
app.mount("/uploaded_images", StaticFiles(directory="uploaded_images"), name="uploaded_images")

voter_embeddings: List[np.ndarray] = []
index = AnnoyIndex(512, "euclidean")
voter_image_names = []
closest_voter_data = {}
closest_voter_data  = None

def read_db_connection_info():
    with open(".dbconnection", "r") as f:
        db_info = json.load(f)
    return db_info

db_info = read_db_connection_info()

mtcnn = MTCNN(image_size=160, margin=0, keep_all=True, device='cuda' if torch.cuda.is_available() else 'cpu')

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

def parse_timestamp(timestamp: Union[str, datetime]) -> str:
    if isinstance(timestamp, datetime):
        dt = timestamp
    else:
        try:
            dt = datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S.%f')
        except ValueError:
            try:
                dt = datetime.fromtimestamp(float(timestamp))
            except ValueError:
                return None
    
    return dt.strftime('%d-%m-%Y %H:%M:%S')

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
    
class VoterData:
    def __init__(self, image_name: str, vector: List[float]):
        self.image_name = image_name
        self.vector = vector
        
def get_response_data(closest_voter_data, message, face_rectangle=None):
    response_data = {
            'message': message,
            'id': closest_voter_data.get('id', None),
            'election_box_number': closest_voter_data.get('election_box_number', None),
            'phone_number': closest_voter_data.get('phone_number', None),
            'user_name': closest_voter_data.get('user_name', None),
            'email': closest_voter_data.get('email', None),
            'voter_line_number': closest_voter_data.get('voter_line_number', None),
            'latitude': closest_voter_data.get('latitude', None),
            'longitude': closest_voter_data.get('longitude', None),
            'timestamp': parse_timestamp(closest_voter_data['timestamp']) if 'timestamp' in closest_voter_data else None,
            'image_path': closest_voter_data.get('image_path', None),  # Use the received image_path
            'face_rectangele_previous': closest_voter_data.get('face_rectangle', None)
            
        }
    if face_rectangle:
        response_data['face_rectangle_recent'] = face_rectangle
    return response_data

async def insert_data(
    electionBoxNumber: int, 
    phoneNumber: str,
    userName: str,
    email: str,
    voterLineNumber: str, 
    latitude: float, 
    longitude: float, 
    image_path: str, 
    timestamp: str,
    vector: str,
    face_rectangle: str
):  
    conn = await asyncpg.connect(
        host=db_info["host"],
        port=db_info["port"],
        database=db_info["database"],
        user=db_info["user"],
        password=db_info["password"],
    )

    try:
        await conn.execute(
            """
            INSERT INTO oy_kullanan_kaydi (election_box_number, phone_number, user_name, email, voter_line_number, latitude, longitude, image_path, timestamp, vector, face_rectangle)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            """,
            electionBoxNumber, phoneNumber, userName, email, voterLineNumber, latitude, longitude, image_path, datetime.fromtimestamp(float(timestamp)), vector, face_rectangle
        )
    except asyncpg.UniqueViolationError:
        print("A row with the same electionBoxNumber and voterLineNumber already exists.")
        message = "Bu sandık numarası ve seçmen sırano ile başka kayıt var"
        return message        
    finally:
        await conn.close()
    message="Kayıt başarılı..."
    return message

async def get_voter_data(election_box_number: int, voter_line_number: str):
    async with asyncpg.create_pool(
        host=db_info["host"],
        port=db_info["port"],
        database=db_info["database"],
        user=db_info["user"],
        password=db_info["password"],
    ) as pool:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                """
                SELECT * FROM oy_kullanan_kaydi
                WHERE election_box_number = $1 AND voter_line_number = $2
                """,
                election_box_number, voter_line_number
            )
    print('Result', result)
    
    return result

async def get_all_voter_data():
    async with asyncpg.create_pool(
        host=db_info["host"],
        port=db_info["port"],
        database=db_info["database"],
        user=db_info["user"],
        password=db_info["password"],
    ) as pool:
        async with pool.acquire() as conn:
            results = await conn.fetch(
                """
                SELECT * FROM oy_kullanan_kaydi
                """
            )
    voter_data_list = []
    for result in results:
        image_name = result["image_path"].split('/')[-1].split('.')[0]
        vector = np.frombuffer(result["vector"], dtype=np.float32)
        voter_data_list.append(VoterData(image_name, vector))
        voter_embeddings.append(vector)
        index.add_item(len(voter_data_list) - 1, vector)

    index.build(100)  # The number 100 is a parameter for the number of trees, you can adjust it according to your needs

    return voter_data_list

def custom_mtcnn(img_pil):
    mtcnn = MTCNN(keep_all=True)
    boxes, _ = mtcnn.detect(img_pil)

    if boxes is None:
        return None, None

    box = boxes[0]
    face = mtcnn.extract(img_pil, [box], save_path=None)[0]

    return box, face

def generate_embedding(img):
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img_pil = Image.fromarray(img_rgb)

    # Face detecting part
    box, face = custom_mtcnn(img_pil)

    if box is None or face is None:
        print("No faces detected")
        return None, None

    face_rectangle = {
        "x": int(box[0]),
        "y": int(box[1]),
        "width": int(box[2] - box[0]),
        "height": int(box[3] - box[1]),
    }

    face_np = np.array(face)
    with torch.no_grad():
        embedding = resnet(torch.Tensor(face_np).unsqueeze(0)).squeeze().cpu().numpy()

    return embedding, face_rectangle


async def save_image(image):
    image_path = f"uploaded_images/{image.filename}"
    with open(image_path, "wb") as f:
        f.write(await image.read())
    return image_path

async def initialize_voter_data_list():
    global voter_data_list
    voter_data_list = await get_all_voter_data()
    for voter_data in voter_data_list:
        index.add_item(len(voter_embeddings), np.frombuffer(voter_data.vector, dtype=np.float32))
        voter_embeddings.append(np.frombuffer(voter_data.vector, dtype=np.float32))
        
    
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
    print('Here we go')
    global closest_voter_data

    message = ""
    image_path = await save_image(image)

    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)

    new_voter_embedding, face_rectangle= generate_embedding(img)

    if new_voter_embedding is None:
        message = "Yüz tespit edilemedi"
        #raise HTTPException(status_code=404, detail="No face detected")
    else:
        closest_match_indices, distances = index.get_nns_by_vector(new_voter_embedding, 1, include_distances=True)

        # Rebuild the index to include the new embedding if it's not built yet



        # Add these debugging print statements
        print(f"len(voter_data_list): {len(voter_data_list)}")
        print(f"index.get_n_items(): {index.get_n_items()}")
        print(f"closest_match_indices: {closest_match_indices}")
        print(f"Distances: {distances}")  
        #print(f"New voter embedding: {new_voter_embedding}")  
    
        
        similarity_threshold = 0.8
        duplicate = distances[0] < similarity_threshold

        if duplicate and len(voter_data_list)>0:
            print("Duplicate voter detected!", closest_match_indices)
            
            try:
                _electionBoxNumber, _voterLineNumber =  voter_data_list[closest_match_indices[0]].image_name.split('_')
                print('T_electionBoxNumber, _voterLineNumber', _electionBoxNumber, _voterLineNumber)
                closest_voter_data = await get_voter_data(int(_electionBoxNumber), _voterLineNumber )
                response_data = get_response_data(closest_voter_data, 
                    "Bu kişi daha önce oy kullanmış, Detaylar:", face_rectangle=face_rectangle )
                
                return JSONResponse(status_code=200, content=response_data)
            except Exception as e:
                print("Error while getting closest_voter_data:", e)
                raise HTTPException(status_code=500, detail="Internal server error")
        else:
            # Save the new voter's data
            message = await insert_data(electionBoxNumber, phoneNumber, userName, email, voterLineNumber, 
                            latitude, longitude, image_path, timestamp, new_voter_embedding.tobytes(), json.dumps(face_rectangle))
                            

            # Create a new VoterData instance
            new_voter_data = VoterData(image.filename.split('.')[0], new_voter_embedding)

            # Add the new voter's data to the voter_data_list and update the Annoy index
            voter_data_list.append(new_voter_data)
            index.add_item(len(voter_data_list) - 1, new_voter_data.vector)
            

        if message=="":message = "Çift kayıt bulunamadı "
        
    response_data = get_response_data({ 
        'election_box_number':  electionBoxNumber,
        'phone_number': phoneNumber,
        'user_name' : userName,
        'email': email,
        'voter_line_number': voterLineNumber,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp}, message, face_rectangle=face_rectangle)
    return JSONResponse(status_code=200, content=response_data)


@app.get("/voter-info/{election_box_number}/{voter_line_number}")
async def get_voter_info(election_box_number: int, voter_line_number: str):
    try:
        voter_info = await get_voter_data(election_box_number, voter_line_number)
        return voter_info
    except Exception as e:
        print("Error while getting voter info:", e)
        raise HTTPException(status_code=500, detail="Internal server error")

@app.on_event("startup")
async def startup_event():
    await initialize_voter_data_list()
