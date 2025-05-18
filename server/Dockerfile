FROM docker.1panel.live/library/node:18-alpine

WORKDIR /app

# 设置淘宝镜像源
RUN npm config set registry https://registry.npmmirror.com

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 9527

CMD ["npm", "start"] 