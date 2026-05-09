#!/bin/bash

echo "🚀 Starting Sports Management Platform..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed or not in PATH"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "✅ Flutter and Node.js are available"

# Start backend
echo "🔧 Starting backend server..."
cd backend
npm install
npm run dev &
BACKEND_PID=$!
cd ..

# Wait a moment for backend to start
sleep 3

# Start frontend
echo "📱 Starting Flutter web app..."
cd frontend
flutter pub get
flutter run -d chrome --web-port=8080 &
FRONTEND_PID=$!
cd ..

echo "🎉 Both services are starting!"
echo "📊 Admin Dashboard will be available at: http://localhost:8080"
echo "🔌 Backend API available at: http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop both services"

# Wait for user to stop
wait $FRONTEND_PID $BACKEND_PID