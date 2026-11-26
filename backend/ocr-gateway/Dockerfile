FROM node:22-slim
WORKDIR /srv
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
ENV NODE_ENV=production
CMD ["npm", "start"]
