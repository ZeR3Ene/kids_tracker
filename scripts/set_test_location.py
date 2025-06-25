import firebase_admin
from firebase_admin import credentials, db
import sys

# --- CONFIGURATION ---
# 1. Replace with the path to your service account key file
CRED_PATH = 'scripts/serviceAccountKey.json'

# 2. Replace with your Firebase Realtime Database URL
DATABASE_URL = 'https://your-database-name.firebaseio.com/'
# --- END CONFIGURATION ---

def set_location(user_id, child_id, lat, lon):
    """
    Sets the location for a specific child in Firebase.
    """
    try:
        # Initialize Firebase Admin SDK
        cred = credentials.Certificate(CRED_PATH)
        firebase_admin.initialize_app(cred, {
            'databaseURL': DATABASE_URL
        })

        # Reference to the child's location
        ref = db.reference(f'users/{user_id}/children/{child_id}/location')

        # New location data
        new_location = {
            'latitude': lat,
            'longitude': lon,
            'timestamp': db.SERVER_TIMESTAMP  # Use server-side timestamp
        }

        # Update the location in Firebase
        ref.update(new_location)

        print(f"Successfully updated location for child '{child_id}' to ({lat}, {lon}).")

    except Exception as e:
        print(f"An error occurred: {e}")
        print("Please check the following:")
        print("1. The path to your service account key in CRED_PATH is correct.")
        print("2. The DATABASE_URL is correct.")
        print("3. The user_id and child_id are correct.")
        # Re-raise the exception to see the full traceback
        raise

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print("Usage: python scripts/set_test_location.py <user_id> <child_id> <latitude> <longitude>")
        sys.exit(1)

    user_id_arg = sys.argv[1]
    child_id_arg = sys.argv[2]
    try:
        latitude_arg = float(sys.argv[3])
        longitude_arg = float(sys.argv[4])
    except ValueError:
        print("Error: Latitude and longitude must be numbers.")
        sys.exit(1)
    
    # Check if firebase_admin is already initialized
    if not firebase_admin._apps:
        set_location(user_id_arg, child_id_arg, latitude_arg, longitude_arg) 