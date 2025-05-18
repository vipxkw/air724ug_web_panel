local websocket = require "websocket"
local log = require "log"
local sys = require "sys"
local misc = require "misc"
local util_mobile = require "util_mobile"
local util_notify = require "util_notify"
local util_temperature = require "util_temperature"
local config = require "config"
local nvm = require "nvm"

local function handleTask(ws, json_data)

    -- log.info('任务解析', json_data.type, json_data.taskId, json_data.task)

    -- 处理task类型的消息
    if json_data.type == "task" and json_data.taskId then
        -- log.info('开始执行task：', json_data.taskId, json_data.task)
        -- 执行对应的task函数
        sys.taskInit(function()
            local result = nil
            local error = nil
            
            -- 执行task函数
            local success, err = pcall(function()
                -- 根据taskid执行不同的任务
                if json_data.task == "get_temperature" then
                    -- 调用温度查询函数
                    result = util_temperature.get()
                elseif json_data.task == "send_sms" then
                    -- 检查参数
                    if not json_data.rcv_phone or not json_data.content then
                        error = "缺少必要参数: rcv_phone 或 content"
                    else
                        -- 发送短信
                        log.info('发送短信', json_data.rcv_phone, json_data.content)
                        -- 补全发送短信的逻辑
                        local sms_success, sms_err = pcall(function()
                             sms.send(json_data.rcv_phone, json_data.content)
                        end)
                        if sms_success then
                             result = "短信发送成功"
                        else
                             error = "短信发送失败: " .. tostring(sms_err)
                        end
                    end
                elseif json_data.task == "get_config" then
                    -- 获取config模块中的变量
                    local config_vars = {}
                    -- 获取config模块中的所有变量
                    for k, v in pairs(config) do
                        if type(v) ~= "function" and k:match("^[A-Z_]+$") then
                            -- 处理不同类型的值，确保可以序列化
                            if type(v) == "table" then
                                -- 如果是表，检查是否为空表
                                if next(v) == nil then
                                    config_vars[k] = {}
                                else
                                    -- 检查表中的值是否都是基本类型
                                    local can_serialize = true
                                    for _, val in pairs(v) do
                                        if type(val) ~= "string" and type(val) ~= "number" and type(val) ~= "boolean" then
                                            can_serialize = false
                                            break
                                        end
                                    end
                                    if can_serialize then
                                        config_vars[k] = v
                                    else
                                        config_vars[k] = tostring(v)
                                    end
                                end
                            elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                                config_vars[k] = v
                            else
                                config_vars[k] = tostring(v)
                            end
                        end
                    end
                    result = config_vars
                elseif json_data.task == "set_config" then
                    -- 检查必要参数
                    if not json_data.configs or type(json_data.configs) ~= "table" then
                        error = "缺少必要参数: configs (必须是对象)"
                    else
                        local success_count = 0
                        local fail_count = 0
                        local fail_reasons = {}
                        
                        -- 遍历所有配置项
                        for key, value in pairs(json_data.configs) do
                            -- 检查key是否符合命名规范
                            if not key:match("^[A-Z_]+$") then
                                fail_count = fail_count + 1
                                fail_reasons[key] = "配置项名称必须全大写字母和下划线组成"
                            else
                                -- 设置config变量
                                config[key] = value
                                -- 保存到NVM
                                nvm.set(key, value)
                                success_count = success_count + 1
                                
                                -- 如果修改了特定配置，需要立即生效
                                if key == "LED_ENABLE" then
                                    if value then
                                        pmd.ldoset(2, pmd.LDO_VLCD)
                                    end
                                elseif key == "RNDIS_ENABLE" then
                                    ril.request("AT+RNDISCALL=" .. (value and 1 or 0) .. ",0")
                                end
                            end
                        end
                        
                        -- 保存NVM
                        nvm.flush()
                        
                        -- 设置返回结果
                        result = {
                            success_count = success_count,
                            fail_count = fail_count,
                            fail_reasons = fail_reasons
                        }
                    end
                else
                    error = "未知的任务类型: " .. (json_data.task or "nil")
                end
            end)
            
            if not success then
                error = err
            end
            
            -- 发送执行结果给服务端
            local response = {
                type = "task_result",
                taskId = json_data.taskId,
                task = json_data.task,
                result = result,
                error = error
            }

            log.info('发送任务结果：', json.encode(response))

            ws:send(json.encode(response), true)
        end)
    end
end

local function startWebSocket()
    -- 等待网络就绪
    log.info("websocket", "等待网络就绪...")
    if not sys.waitUntil("IP_READY_IND", 1000 * 60 * 2) then
        log.error("websocket", "网络就绪超时")
        return
    end
    log.info("websocket", "网络已就绪")

    -- 开机通知
    if nvm.get("BOOT_NOTIFY") then
        util_notify.add("#BOOT_" .. rtos.poweron_reason())
    end

    log.info("websocket", "开始连接")

    -- websocket 连接
    -- 使用 config.WEBSOCKET_URL 获取地址
    local ws = websocket.new(config.WEBSOCKET_URL)

    ws:on("open", function()
        log.info("websocket", "连接已打开")
        -- 发送JSON数据
        local json_data = {
            type = "online",
            imei = misc.getImei(),
            phone = util_mobile.getNumber()
        }
        ws:send(json.encode(json_data), true)
    end)

    ws:on("message", function(data)
        log.info("websocket", "收到数据:", data)
        -- 解析JSON数据
        local success, json_data = pcall(json.decode, data)
        if success then
            -- 处理JSON数据
            log.info("websocket", "JSON数据:", json.encode(json_data))
            handleTask(ws, json_data)
        end
    end)

    ws:on("close", function()
        log.info("websocket", "连接关闭")
    end)

    ws:on("error", function(ws, err)
        log.error("websocket", "连接错误", err)
    end)

    -- 启动WebSocket任务
    ws:start(120)  -- 30秒心跳

    -- 定时查询流量
    if config.QUERY_TRAFFIC_INTERVAL and config.QUERY_TRAFFIC_INTERVAL >= 1000 * 60 then
        sys.timerLoopStart(util_mobile.queryTraffic, config.QUERY_TRAFFIC_INTERVAL)
    end
end

return {
    start = startWebSocket
} 