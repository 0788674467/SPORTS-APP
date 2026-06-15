FROM node:20.0.0-slim

# Install OpenSSL (required by Prisma ORM)
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy package files first to leverage Docker cache
COPY package*.json ./
COPY db ./db/

# Install dependencies
RUN npm install

# Copy the rest of the backend source code
COPY . .

# Generate Prisma Client (explicitly point to the db folder)
RUN npx prisma generate --schema=./db/schema.prisma

# Compile TypeScript to JavaScript in the /dist folder
RUN npm run build

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
