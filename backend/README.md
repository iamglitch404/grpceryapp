# Dovan Vercel API Backend

This is the Next.js API backend for the Dovan application. It proxies requests from the Flutter client to Supabase to securely enforce business logic, authentication, and database integrity.

## Tech Stack
- Next.js 15 (App Router / API Routes)
- TypeScript
- Zod (Request validation)
- Supabase (PostgreSQL Database, Admin SDK)
- Resend (Transactional emails for OTP)

## Setup & Local Development

1. Create a `.env.local` file by copying `.env.example`:
   ```bash
   cp .env.example .env.local
   ```
2. Fill in your environment variables inside `.env.local`.
3. Install dependencies:
   ```bash
   npm install
   ```
4. Start the local server:
   ```bash
   npm run dev
   ```
   The backend will run on `http://localhost:3001` (or 3000 if not specified otherwise).

## API Documentation

All routes prefix: `/api`

### Authentication (`/api/auth/*`)

#### `POST /api/auth/send-otp`
Sends an OTP to the user's email.
- **Request Body:** `{ email: string }`
- **Response:** `{ message: "OTP sent" }`

#### `POST /api/auth/verify-otp`
Verifies OTP and creates a session token.
- **Request Body:** `{ email: string, otp: string }`
- **Response:** `{ token: string, user: UserData }`

### Cart (`/api/cart`)

**Requires Auth Header:** `Authorization: Bearer <session_token>`

#### `GET /api/cart`
Gets the current user's cart and subtotal.
- **Response:** `{ items: Array, subtotal_paise: number }`

#### `POST /api/cart`
Adds an item to the cart or increments quantity.
- **Request Body:** `{ product_id: string (UUID), quantity: number }`
- **Response:** `{ message: "Cart updated", new_quantity: number }`

#### `PATCH /api/cart/:id`
Updates the quantity of a specific cart item.
- **Request Body:** `{ quantity: number }`

#### `DELETE /api/cart/:id`
Removes a specific item from the cart.

#### `DELETE /api/cart`
Clears the user's entire cart.

### Orders (`/api/orders`)

**Requires Auth Header:** `Authorization: Bearer <session_token>`

#### `POST /api/orders`
Creates a new order from the user's cart. Automatically deducts inventory securely inside the database.
- **Request Body:** `{ address_id: string, delivery_slot: string, payment_method: string, slot_fee_paise: number }`
- **Response:** `{ order_id: string, total_paise: number }`

### Addresses (`/api/addresses`)

**Requires Auth Header:** `Authorization: Bearer <session_token>`

#### `GET /api/addresses`
Fetches the user's saved addresses.
- **Response:** `{ addresses: Array }`

### Leaderboard (`/api/leaderboard`)

#### `GET /api/leaderboard`
Gets the global points leaderboard.
- **Response:** `{ leaderboard: Array }`

## Deployment

Deploy directly to Vercel:

1. Connect your GitHub repository to Vercel.
2. Set the **Root Directory** to `backend/`.
3. Configure the environment variables in Vercel from your `.env.local`.
4. Deploy!
