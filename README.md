# ShareBite

![Flutter](https://img.shields.io/badge/Flutter-Mobile%20App-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-Frontend-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?style=for-the-badge&logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express.js-API-000000?style=for-the-badge&logo=express&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-ML%20Service-3776AB?style=for-the-badge&logo=python&logoColor=white)

**ShareBite is a community based food sharing mobile application that helps users share surplus food, discover nearby listings, request available items, and reduce food waste through location based interaction and smart recipe recommendations.**

---

## App Preview

![ShareBite Demo](ShareBiteDemo.png)

---

## Overview

Food waste is a real community issue, while many people around us may still need access to affordable or free food. ShareBite was built to connect those two sides through a simple digital platform where users can list surplus food, search for nearby available items, and communicate with other users.

The project combines mobile app development, backend API integration, PostgreSQL database management, OpenStreetMap based interaction, image upload, authentication, user profiles, request handling, messaging, and a Python based machine learning service for recipe ideas. The result is a functional full stack mobile application that supports food sharing, discovery, and community driven action.

---

## Main Goals

- Reduce food waste by allowing users to share surplus food.
- Help users find available food or items near their location.
- Support safer and clearer interaction through listings, requests, and messages.
- Provide a mobile first experience with clean UI, maps, and profile management.
- Add smart food related support through recipe recommendation logic.

---

## Key Features

### User Authentication

Users can register, log in, and stay authenticated using a token based system. The backend uses password hashing and JWT authentication to protect user accounts.

### Food and Item Listings

Users can create listings with title, description, category, quantity, price, location, tags, dietary information, allergens, and images. Listings can be free food, free non food items, for sale items, borrowable items, or wanted items.

### Location Based Discovery

ShareBite supports nearby discovery using latitude and longitude. Users can explore listings around them based on distance and radius.

### OpenStreetMap Integration

The mobile app uses OpenStreetMap through `flutter_map`, so the map feature can work without requiring a Google Maps API key.

### Search and Category Filtering

Users can search listings by keyword and browse by category. This helps users find relevant food or community items faster.

### Listing Detail Page

Each listing has a detail screen showing item information, images, tags, quantity, location, owner profile, recipe ideas, and available actions.

### Request System

Users can send requests for available listings. Listing owners can manage incoming requests by accepting, rejecting, completing, or cancelling them.

### Messaging System

ShareBite includes conversation and message endpoints so users can communicate about listed items.

### Profile Management

Users can view and update their profile, bio, photo, location, and personal impact statistics. The profile page also displays shared items and impact data.

### Impact Tracking

The application tracks community contribution through statistics such as total shared, total received, and meals saved.

### Smart Recipe Recommendation

The Python ML service uses TF-IDF and cosine similarity to recommend recipe ideas based on food keywords, ingredients, or listing information.

---

## Application Flow

```text
User opens ShareBite
        ↓
User registers or logs in
        ↓
User explores nearby food listings
        ↓
User opens listing details
        ↓
User sends a request or message to the owner
        ↓
Owner manages incoming requests
        ↓
Food is shared and community impact increases
```

---

## System Architecture

```text
Flutter Mobile App
        ↓ HTTP Requests
Express.js Backend API
        ↓ SQL Queries
PostgreSQL Database
        ↓ Optional Recommendation Request
Python ML Service
```

### Main Components

| Component | Description |
|---|---|
| Flutter App | Handles mobile UI, navigation, authentication state, map view, listing pages, profile, and user interaction. |
| Express Backend | Provides REST API endpoints for auth, users, listings, requests, messages, maps, and ML integration. |
| PostgreSQL Database | Stores users, listings, requests, conversations, messages, and impact data. |
| ML Service | Provides recipe ideas using content-based recommendation logic. |
| Docker Support | Helps run the backend, database, and ML service in a containerized environment if `docker-compose.yml` is available. |

---

## Module Documentation

### 1. Flutter App Module

The Flutter module is responsible for the mobile interface and user interaction.

Main responsibilities:

- Display splash, login, register, home, search, map, listing detail, add listing, and profile screens.
- Manage authentication state using `AuthProvider`.
- Manage light and dark mode using `ThemeProvider`.
- Connect to the backend using `ApiService`.
- Display listings, map markers, user profiles, recipe ideas, and request actions.

Important folders:

```text
flutter_app/lib/screens/
flutter_app/lib/services/
flutter_app/lib/models/
flutter_app/lib/widgets/
flutter_app/lib/theme/
```

### 2. Backend API Module

The backend module is built with Express.js and provides API routes for the mobile app.

Main responsibilities:

- Register and authenticate users.
- Handle JWT based protected routes.
- Manage listings and uploaded images.
- Provide nearby listing search based on coordinates.
- Manage requests and request status updates.
- Support conversations and messages.
- Connect to PostgreSQL.
- Communicate with the ML recommendation logic.

Important files:

```text
backend/server.js
backend/package.json
backend/db/schema.sql
backend/routes/auth.js
backend/routes/listings.js
backend/routes/maps.js
backend/routes/messages.js
backend/routes/ml.js
backend/routes/requests.js
backend/routes/users.js
```

### 3. Database Module

The PostgreSQL database stores the core application data.

Main tables:

| Table | Purpose |
|---|---|
| `users` | Stores user accounts, profiles, location, badges, and impact statistics. |
| `listings` | Stores shared food or item listings, images, categories, tags, location, and availability. |
| `requests` | Stores user requests for listings and request status. |
| `conversations` | Stores chat conversation metadata. |
| `conversation_participants` | Connects users to conversations. |
| `messages` | Stores messages inside conversations. |

### 4. ML Recommendation Module

The ML module is a Python Flask service that supports recipe recommendations.

Main responsibilities:

- Store a small Indonesian food knowledge base.
- Convert food keywords into TF IDF vectors.
- Compare keyword similarity using cosine similarity.
- Return recipe ideas based on listing or ingredient information.

Important files:

```text
ml_model/ml_service.py
ml_model/requirements.txt
ml_model/Dockerfile
```

### 5. Map and Location Module

The map module allows users to discover nearby listings.

Main responsibilities:

- Read user coordinates.
- Fetch nearby listings from the backend.
- Display listing markers on OpenStreetMap.
- Calculate and show distance information.

Flutter package used:

```text
flutter_map
latlong2
geolocator
```

### 6. Request and Messaging Logic

The request system helps users ask for available listings, while the messaging system supports communication between users.

Request status flow:

```text
pending → accepted → completed
pending → rejected
pending → cancelled
```

When a request is completed, the system can update user impact statistics such as total received and meals saved.

---

## Built With

### Frontend

- Flutter
- Dart
- Provider
- HTTP
- Flutter Secure Storage
- Shared Preferences
- Flutter Map
- Geolocator
- Image Picker
- Cached Network Image

### Backend

- Node.js
- Express.js
- PostgreSQL
- JWT
- Bcrypt.js
- Multer
- Helmet
- CORS
- Morgan
- Express Validator

### Machine Learning Service

- Python
- Flask
- Scikit learn
- Pandas
- NumPy

### Optional Infrastructure

- Docker
- Docker Compose

---

## Installation and Setup

### Prerequisites

Make sure these tools are installed:

```text
Flutter SDK
Dart SDK
Node.js
npm
PostgreSQL
Python 3.10+
Docker Desktop, optional
```

---

## Running the Backend

Go to the backend folder:

```bash
cd backend
```

Install dependencies:

```bash
npm install
```

Create an environment file:

```bash
cp .env.example .env
```

Update the database configuration inside `.env`, then run the migration:

```bash
npm run migrate
```

Optional: seed demo data.

```bash
npm run seed
```

Start the backend:

```bash
npm run dev
```

or:

```bash
npm start
```

By default, the backend runs on:

```text
http://localhost:3000
```

Health check endpoint:

```text
http://localhost:3000/health
```

---

## Running the ML Service

Go to the ML folder:

```bash
cd ml_model
```

Create and activate a virtual environment:

```bash
python -m venv venv
```

For Windows:

```bash
venv\Scripts\activate
```

For macOS or Linux:

```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the ML service:

```bash
python ml_service.py
```

---

## Running the Flutter App

Go to the Flutter folder:

```bash
cd flutter_app
```

Install Flutter packages:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

If you run the backend locally and test on an Android emulator, update the API base URL in:

```text
flutter_app/lib/services/api_service.dart
```

Use this for Android emulator:

```text
http://10.0.2.2:3000/api
```

Use your computer LAN IP for a physical Android device:

```text
http://YOUR_LOCAL_IP:3000/api
```

Use your production API URL for deployment:

```text
https://your-production-api.com/api
```

---

## Running with Docker Compose
 
 You can run the backend, database, and ML service with:

```bash
docker compose up --build
```

To stop the services:

```bash
docker compose down
```

Use Docker when you want a more consistent backend and database setup.

---

## API Overview

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/auth/register` | Create a new user account. |
| `POST` | `/api/auth/login` | Log in and receive an authentication token. |
| `GET` | `/api/auth/me` | Get the current authenticated user. |
| `GET` | `/api/listings` | Get available listings with optional filters. |
| `POST` | `/api/listings` | Create a new listing with optional images. |
| `GET` | `/api/listings/:id` | Get listing details. |
| `DELETE` | `/api/listings/:id` | Delete a listing. |
| `GET` | `/api/maps/nearby` | Get nearby listings based on coordinates. |
| `POST` | `/api/requests` | Send a request for a listing. |
| `GET` | `/api/requests/my` | Get requests made by the current user. |
| `GET` | `/api/requests/incoming` | Get incoming requests for the current user. |
| `PATCH` | `/api/requests/:id/status` | Update request status. |
| `GET` | `/api/messages/conversations` | Get user conversations. |
| `POST` | `/api/messages` | Send a message. |
| `POST` | `/api/ml/recommend` | Get recipe or food recommendation ideas. |

---

## Environment Variables

Example backend environment values:

```env
PORT=3000
DATABASE_URL=postgresql://postgres:password@localhost:5432/sharebite
JWT_SECRET=replace_with_a_secure_secret
JWT_EXPIRES_IN=7d
DB_AUTO_MIGRATE=true
SEED_DEMO=true
ML_SERVICE_URL=http://localhost:5000
```
## Project Impact

ShareBite demonstrates how mobile technology can support community-based food sharing and reduce food waste. By combining location-based discovery, user listings, request management, messaging, and recommendation logic, the application turns a social problem into a practical and accessible digital solution.

Developed by **Erlangga Putra Mahardika**.
