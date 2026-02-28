# Build stage
FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

ARG VITE_API_URL=/api
ARG VITE_GRAFANA_URL=http://localhost:9200
ARG VITE_SUPERSET_URL=http://localhost:9300

ENV VITE_API_URL=${VITE_API_URL}
ENV VITE_GRAFANA_URL=${VITE_GRAFANA_URL}
ENV VITE_SUPERSET_URL=${VITE_SUPERSET_URL}

RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
