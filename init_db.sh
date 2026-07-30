#!/bin/bash
set -e

echo "🚀 Starting local databases via Homebrew..."
brew services start postgresql@15 || true
brew services start redis || true

echo "⏳ Waiting 5 seconds for PostgreSQL to boot up..."
sleep 5

echo "📦 Running Prisma migrations..."
cd apps/api

# Generate client
npx prisma generate

# Push schema to local DB
npx prisma db push --accept-data-loss

echo "🌱 Seeding initial data..."
npx prisma db seed

echo "✅ Database initialized successfully and seeded!"
