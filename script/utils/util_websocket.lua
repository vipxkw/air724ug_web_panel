local websocket = require "websocket"
local log = require "log"
local sys = require "sys"
local misc = require "misc"
local util_mobile = require "util_mobile"
local util_notify = require "util_notify"
local util_temperature = require "util_temperature"
local config = require "config"
local nvm = require "nvm"

local function serializeValue(val)
    if type(val) == "table" then
        local result = {}
        for k, v in pairs(val) do
            if type(v) == "table" then
                result[k] = serializeValue(v)
            elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" or type(v) == "nil" then
                result[k] = v
            else
                result[k] = tostring(v)
            end
        end
        return result
    elseif type(val) == "string" or type(val) == "number" or type(val) == "boolean" or type(val) == "nil" then
        return val
    else
        return tostring(val)
    end
end

local function handleTask(ws, json_data)

    -- 处理task类型的消息
    if json_data.type == "task" and json_data.taskId then
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
                    local config_vars = {}
                    local nvm_config = nvm.para
                    for k, v in pairs(nvm_config) do
                        if type(v) ~= "function" then
                            config_vars[k] = serializeValue(v)
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
                            log.info("设置配置项", key, value)
                            if value == nil or tostring(value) == "userdata: 0x0" then
                                config[key] = nil
                                nvm.set(key, nil)
                            else
                                -- 设置config变量
                                config[key] = value
                                -- 保存到NVM
                                nvm.set(key, value)
                            end
                            success_count = success_count + 1
                            
                            -- 如果修改了特定配置，需要立即生效
                            if key == "LED_ENABLE" then
                                if value then
                                    pmd.ldoset(2, pmd.LDO_VLCD)
                                end
                            elseif key == "RNDIS_ENABLE" then
                                ril.request("AT+RNDISCALL=" .. (value and 1 or 0) .. ",0")
                            end
                            log.info("获取配置项", key, nvm.get(key))
                        end
                        
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
    ws:start(120)
end

return {
    start = startWebSocket
} 