## Air724ug Web 控制

改自 0wQ 大佬的脚本固件，请自行去找底包做一下修改变更

### 脚本变更指南

1. 将script中新增得两个脚本文件新增到对应得目录
2. main.lua 中引入如下代码
3. config.lua 中新增 `WEBSOCKET_URL` 变量指定服务端地址

```lua
-- 头部引入util_websocket
local util_websocket = require "util_websocket"

-- 任务初始化中启动与服务端得连接
sys.taskInit(function()
    -- ...
    if config.WEBSOCKET_URL and config.WEBSOCKET_URL ~= "" then
        log.info("main", "WebSocket URL 已配置，开始启动WebSocket连接。")
        util_websocket.start()
    end
    -- ...
end)
```


### 服务端部署指南

Nodejs 服务部署即可，端口默认 9527

服务地址：ws://{替换成自己公网IP}:9527/websocket

Web地址：http://{替换成自己公网IP}:9527

```js
// 服务端启动，可自行挂到后台，或者使用pm2启动
cd server
npm install
npm run start
```

