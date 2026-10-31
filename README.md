# Dovan - Full Stack E-Commerce

Dovan is a production-ready, full-stack grocery and e-commerce application. It features a Flutter mobile frontend, a Next.js (TypeScript) serverless API backend hosted on Vercel, and a secure Supabase PostgreSQL database.

## Architecture
- **Frontend (Mobile/Web):** Flutter (`/lib`)
- **Backend API:** Next.js 15 Serverless Functions (`/backend`)
- **Database:** Supabase PostgreSQL (`/backend/schema.sql`)
- **Authentication:** Custom OTP flow using Resend Email and bcrypt hashing, mediated by the Next.js API.
- **Security:** "Client-Thin / Server-Fat". All business logic, checkout flows, and inventory management is handled securely on the Next.js API or inside PostgreSQL Security Definer functions.

## Setup Instructions

### 1. Database Setup
1. Create a Supabase project.
2. Run the SQL script located in `backend/schema.sql` in your Supabase SQL Editor to initialize all tables, functions, and RLS policies.

### 2. Backend Setup
1. Navigate to the `backend` folder: `cd backend`
2. Copy the `.env.example` file: `cp .env.example .env.local`
3. Fill in your Supabase URLs, Service Role Keys, and Resend API key in `.env.local`.
4. Run `npm install` and `npm run dev` to start the API locally on port 3001 (or deploy to Vercel).

### 3. Frontend Setup
1. Open `lib/core/config/app_config.dart`.
2. Update `apiUrl` to point to your deployed Next.js backend URL (or `http://localhost:3001/api` for local).
3. Run the Flutter app: `flutter run`

## Features Implemented
- Complete User Authentication (Email OTP, Session Tokens)
- Browsing & Categories
- Cart Management (Server-side validation)
- Secure Checkout with Inventory deduction
- User Profiles & Global Leaderboard
- Admin Dashboard

## Deployment
- **API:** Deploy the `/backend` folder to Vercel.
- **Database:** Hosted on Supabase.
- **Flutter:** Compile to APK/AAB or host via Firebase Hosting/Vercel (for Flutter Web).
# grpceryapp
