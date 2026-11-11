FROM node:24-alpine AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG VITE_GRAFANA_URL=""
RUN npm run build


FROM nginx:1.29-alpine
COPY --from=build /app/dist /usr/share/nginx/html
