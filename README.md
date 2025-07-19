# Community App
[![Ask DeepWiki](https://devin.ai/assets/askdeepwiki.png)](https://deepwiki.com/RealSujal/community-app)

A full-stack monorepo for a community management application, featuring a Node.js backend and a Flutter frontend. The application enables users to create and join communities, manage family members, engage in a social feed, and customize their profiles and privacy settings.

## Features

- **User Authentication**: Secure registration and login using JWT and bcrypt. Includes OTP verification via email for account registration and password resets.
- **Community Management**: Users can create new communities with unique invite codes or join existing ones. Roles like 'head', 'admin', and 'member' are supported for permission management.
- **Family & Person Directory**: Functionality to register a family unit and add individual members, defining their relationships to the head of the family.
- **Social Feed**: An interactive feed where community members can create posts (with text and media), like posts, and comment on them.
- **User Profiles**: Comprehensive user profiles displaying personal information, social links, and community role. Users can edit their details and upload a profile picture.
- **Privacy Controls**: Granular control over the visibility of personal information such as phone number, email, date of birth, and address.
- **Notifications**: In-app notifications for key events like promotions, removals, and interactions on posts.
- **Help & Support**: An integrated support section with FAQs and a feedback submission form.

## Technology Stack

### Backend (`community-backend`)

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MySQL (`mysql2`)
- **Authentication**: JSON Web Tokens (JWT), Bcrypt
- **File Uploads**: Multer
- **Emailing**: Nodemailer for OTP delivery

### Frontend (`community-frontend`)

- **Framework**: Flutter
- **Language**: Dart
- **Key Packages**:
  - `http`: For making API requests to the backend.
  - `shared_preferences`: For local storage (e.g., auth tokens).
  - `image_picker`: For selecting profile and post images.
  - `pin_code_fields`: For the OTP input UI.
  - `provider`: For state management.

## Project Structure

The repository is a monorepo containing two main projects:

-   `community-backend/`: The Node.js Express server that provides the REST API.
-   `community-frontend/`: The Flutter application for Android, iOS, and other platforms.

## Setup and Installation

### Prerequisites

-   Node.js and npm
-   Flutter SDK
-   A running MySQL database instance

### Backend Setup (`community-backend`)

1.  **Navigate to the backend directory:**
    ```sh
    cd community-backend
    ```

2.  **Install dependencies:**
    ```sh
    npm install
    ```

3.  **Create an environment file:**
    Create a `.env` file in the `community-backend` root and populate it with your configuration. Use the following template:

    ```env
    # Server Configuration
    PORT=3000
    API_URL=http://<YOUR_LOCAL_IP>:3000

    # Database Configuration
    DB_HOST=localhost
    DB_USER=your_db_user
    DB_PASSWORD=your_db_password
    DB_NAME=community_db

    # JWT Authentication
    JWT_SECRET=your_super_secret_jwt_key

    # Nodemailer (Gmail Example)
    EMAIL_HOST=smtp.gmail.com
    EMAIL_PORT=587
    EMAIL_USER=your_email@gmail.com
    EMAIL_PASS=your_gmail_app_password
    EMAIL_FROM_NAME="Community App"
    EMAIL_FROM_ADDRESS=your_email@gmail.com

    # OTP Settings
    OTP_EXPIRY_MINUTES=5
    ```

4.  **Database Setup:**
    Ensure you have a MySQL database created that matches the `DB_NAME` in your `.env` file. You will need to set up the necessary tables (e.g., `users`, `communities`, `posts`, `family`, `person`, etc.) based on the queries in the `routes/` and `models/` directories.

5.  **Run the server:**
    -   For development with live reloading:
        ```sh
        npm run dev
        ```
    -   For production:
        ```sh
        npm start
        ```
    The API will be available at `http://localhost:3000` (or your configured IP and port).

### Frontend Setup (`community-frontend`)

1.  **Navigate to the frontend directory:**
    ```sh
    cd community-frontend
    ```

2.  **Configure the Backend URL:**
    Open the file `lib/constants/constants.dart` and update the `baseUrl` constant to point to your running backend server's IP address.

    ```dart
    // lib/constants/constants.dart
    const baseUrl = "http://<YOUR_LOCAL_IP>:3000";
    ```

3.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

4.  **Run the app:**
    ```sh
    flutter run
    ```

## API Endpoints

The backend exposes a REST API for all application functionalities. Here is a high-level overview of the main routes:

| Method         | Endpoint                            | Description                                        |
| -------------- | ----------------------------------- | -------------------------------------------------- |
| **Auth**       |                                     |                                                    |
| `POST`         | `/auth/send-otp`                    | Sends an OTP to a user's email.                    |
| `POST`         | `/auth/register`                    | Registers a new user with OTP verification.        |
| `POST`         | `/auth/login`                       | Logs in a user and returns a JWT.                  |
| `POST`         | `/auth/reset-password`              | Resets the user's password with an OTP.            |
| **Users**      |                                     |                                                    |
| `GET`          | `/api/users/me`                     | Fetches the profile of the logged-in user.         |
| `GET`          | `/api/users/:userId`                | Fetches the public profile of a specific user.     |
| `PATCH`        | `/api/users/edit-profile`           | Updates the current user's profile information.    |
| `POST`         | `/api/users/upload-profile-picture` | Uploads a new profile picture.                     |
| **Communities**|                                     |                                                    |
| `POST`         | `/api/communities/create-community` | Creates a new community.                           |
| `POST`         | `/api/communities/join-community`   | Joins a community using an invite code.            |
| `GET`          | `/api/communities/my-community`     | Gets details of the current user's community.      |
| `GET`          | `/api/communities/members`          | Lists all members of the user's community.         |
| `GET`          | `/api/communities/dashboard`        | Provides statistics for the community dashboard.   |
| **Posts**      |                                     |                                                    |
| `POST`         | `/api/posts/create`                 | Creates a new post (with optional media).          |
| `GET`          | `/api/posts/feed`                   | Fetches the community feed with posts and stats.   |
| `POST`         | `/api/posts/:postId/like`           | Toggles a like on a post.                          |
| `POST`         | `/api/posts/:postId/comment`        | Adds a comment to a post.                          |
| **Family**     |                                     |                                                    |
| `POST`         | `/api/register-family`              | Registers a new family unit for the user.          |
| `GET`          | `/api/my-family`                    | Fetches the family details of the logged-in user.  |
| `POST`         | `/api/person`                       | Adds a new member to the user's family.            |
| `DELETE`       | `/api/person/:id`                   | Removes a member from the family.                  |
