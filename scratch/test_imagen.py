from google import genai
import os
from dotenv import load_dotenv

load_dotenv()
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=GEMINI_API_KEY)
try:
    print("Testing generate_content...")
    response = client.models.generate_content(
        model='imagen-3.0-generate-001',
        contents='A delicious slice of pizza',
    )
    print("Success! Got response.")
    print(len(response.generated_images))
except Exception as e:
    print(f"Error: {e}")
