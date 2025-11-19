# Stage 1: Use a lightweight base image to hold our static files
FROM busybox:latest AS builder

WORKDIR /source
COPY . .

# Stage 2: Use the official Nginx image
FROM nginx:stable-alpine

# Copy the static files from the builder stage
COPY --from=builder /source /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
