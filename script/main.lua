-- ....code 省略
local util_websocket = require "util_websocket"
-- ...code 省略
sys.taskInit(function()
    -- 启动WebSocket连接
    if config.WEBSOCKET_URL and config.WEBSOCKET_URL ~= "" then
        log.info("main", "WebSocket URL 已配置，开始启动WebSocket连接。")
        util_websocket.start()
    end
    
end)
