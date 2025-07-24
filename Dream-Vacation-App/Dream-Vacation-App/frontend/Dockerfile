# To build Build React app
FROM node:18-alpine AS build

# To set environmant variable
ENV NODE_OPTIONS=--openssl-legacy-provider

WORKDIR /app

COPY package*.json ./

RUN npm install

# Ensure required packages are installed
RUN npm install react react-dom react-scripts axios

COPY . .
RUN npm run build

# Copy index page to nginx
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
