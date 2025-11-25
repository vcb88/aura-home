# Stage 1: Use a lightweight base image to hold our static files
FROM busybox:latest AS builder

WORKDIR /source
COPY . .

# Stage 2: Use the official Nginx image
FROM nginx:stable-alpine

# Add ARG instructions to receive build-time variables
ARG BUILD_DATE
ARG COMMIT_SHA

# Copy the static files from the builder stage
COPY --from=builder /source/landing /usr/share/nginx/html

# Install sed, perform the replacement, and then clean up.
# This happens at build time.
RUN apk --no-cache add sed && \
    sed -i "s|__BUILD_DATE__|${BUILD_DATE:-n/a}|g" /usr/share/nginx/html/index.html && \
    sed -i "s|__COMMIT_SHA__|${COMMIT_SHA:-n/a}|g" /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
