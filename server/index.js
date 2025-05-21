// 创建一个websocket服务器
const WebSocket = require("ws");
const express = require("express");
const path = require("path");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const fs = require("fs");

const app = express();
const server = require("http").createServer(app);
const wss = new WebSocket.Server({
  server,
  path: "/websocket",
});

// 读取配置文件
const config = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json"), "utf8"));

app.use(express.json());

app.use(express.static(path.join(__dirname, "public")));

// 存储已失效的token
const invalidTokens = new Set();

// JWT 认证中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ message: "未提供认证令牌" });
  }

  // 检查token是否已失效
  if (invalidTokens.has(token)) {
    return res.status(403).json({ message: "token已失效" });
  }

  jwt.verify(token, config.jwtSecret, (err, decoded) => {
    if (err) {
      return res.status(403).json({ message: "无效的认证令牌" });
    }
    
    // 检查token版本是否匹配
    if (decoded.version !== config.tokenVersion) {
      return res.status(403).json({ message: "token已过期，请重新登录" });
    }
    
    req.user = decoded;
    next();
  });
};

// 登录接口
app.post("/login", async (req, res) => {
  const { username, password } = req.body;

  if (username !== config.user.username) {
    return res.status(401).json({ message: "用户名或密码错误" });
  }

  const validPassword = await bcrypt.compare(password, config.user.password);
  if (!validPassword) {
    return res.status(401).json({ message: "用户名或密码错误" });
  }

  const token = jwt.sign(
    { 
      username,
      version: config.tokenVersion 
    }, 
    config.jwtSecret, 
    { expiresIn: "24h" }
  );
  res.json({ token });
});

// 修改用户信息接口
app.post("/change-user-info", authenticateToken, async (req, res) => {
  const { oldPassword, newUsername, newPassword } = req.body;

  // 验证旧密码
  const validPassword = await bcrypt.compare(oldPassword, config.user.password);
  if (!validPassword) {
    return res.json({ message: "原密码错误" });
  }

  let hasChanges = false;

  // 更新用户名（如果提供）
  if (newUsername && newUsername !== config.user.username) {
    config.user.username = newUsername;
    hasChanges = true;
  }

  // 更新密码（如果提供）
  if (newPassword) {
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    config.user.password = hashedPassword;
    hasChanges = true;
  }

  // 如果有任何更改，增加token版本号
  if (hasChanges) {
    config.tokenVersion += 1;
  }

  // 保存更新后的配置
  fs.writeFileSync(
    path.join(__dirname, "config.json"),
    JSON.stringify(config, null, 2)
  );

  res.json({
    message: "用户信息修改成功",
    username: config.user.username,
    needRelogin: hasChanges // 告诉前端是否需要重新登录
  });
});

// 退出登录接口
app.post("/logout", authenticateToken, (req, res) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  
  // 将当前token加入黑名单
  invalidTokens.add(token);
  
  // 设置一个定时器，24小时后从黑名单中移除（与token过期时间一致）
  setTimeout(() => {
    invalidTokens.delete(token);
  }, 24 * 60 * 60 * 1000);

  res.json({ message: "退出登录成功" });
});

// 自定义前端路由处理中间件
app.use((req, res, next) => {
  if (
    req.path.startsWith("/userPool") ||
    req.path.startsWith("/executeTask") ||
    req.path.startsWith("/websocket")
  ) {
    return next();
  }

  res.sendFile(path.join(__dirname, "public", "index.html"));
});

const userPool = new Map();
// 存储任务执行结果
const taskResults = new Map();

// 需要认证的路由
app.get("/userPool", authenticateToken, (req, res) => {
  const users = Array.from(userPool.entries()).map(([imei, user]) => ({
    imei,
    phone: user.phone,
    connected: user.connected,
    lastSeen: user.lastSeen,
  }));
  res.json(users);
});

// 执行任务接口
app.post("/executeTask", authenticateToken, async (req, res) => {
  const { imei, task, ...rest } = req.body;

  if (!imei || !task) {
    return res.status(400).json({
      success: false,
      message: "缺少必要参数",
    });
  }

  const user = userPool.get(imei);
  if (!user || !user.connected) {
    return res.status(404).json({
      success: false,
      message: "用户未连接",
    });
  }

  const taskId = Date.now().toString();

  const taskPromise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      taskResults.delete(taskId);
      reject(new Error("任务执行超时"));
    }, 30000);

    taskResults.set(taskId, {
      resolve,
      reject,
      timeout,
    });
  });

  try {
    user.ws.send(
      JSON.stringify({
        type: "task",
        taskId,
        task,
        ...rest,
      })
    );

    const result = await taskPromise;

    res.json({
      success: true,
      taskId,
      result,
    });
  } catch (error) {
    console.log(error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

wss.on("connection", (ws) => {
  ws.on("ping", (data) => {
    const user = Array.from(userPool.entries()).find(([_, u]) => u.ws === ws);
    if (user) {
      user[1].lastSeen = Date.now();
    }
  });

  ws.on("message", (message) => {
    try {
      const data = JSON.parse(message.toString());

      switch (data.type) {
        case "online":
          // 处理上线通知
          if (data.phone && data.imei) {
            userPool.set(data.imei, {
              phone: data.phone,
              ws: ws,
              connected: true,
              lastSeen: Date.now(),
            });

            console.log(
              `用户已连接 - IMEI: ${data.imei}, 手机号: ${data.phone}`
            );
            ws.send(
              JSON.stringify({
                type: "connection_success",
                message: "连接成功",
              })
            );
          } else {
            console.log("收到无效的用户数据");
            ws.send(
              JSON.stringify({
                type: "error",
                message: "缺少必要的用户信息",
              })
            );
          }
          break;

        case "task_result":
          // 处理任务执行结果
          if (data.taskId && data.result) {
            const task = taskResults.get(data.taskId);
            if (task) {
              clearTimeout(task.timeout);
              task.resolve(data.result);
              taskResults.delete(data.taskId);
            }
          }
          break;

        default:
          console.log("未知的消息类型:", data.type);
          ws.send(
            JSON.stringify({
              type: "error",
              message: "未知的消息类型",
            })
          );
      }
    } catch (error) {
      console.log("消息解析错误:", message);
      ws.send(
        JSON.stringify({
          type: "error",
          message: "消息格式错误",
        })
      );
    }
  });

  // 处理连接关闭
  ws.on("close", () => {
    // 查找并移除断开连接的用户
    for (const [imei, user] of userPool.entries()) {
      if (user.ws === ws) {
        userPool.delete(imei);
        console.log(`用户已断开连接 - IMEI: ${imei}`);
        break;
      }
    }
  });

  // 发送欢迎消息
  ws.send(
    JSON.stringify({
      type: "welcome",
      message: "欢迎连接到服务器",
    })
  );
});

// 添加WebSocket服务器错误处理
wss.on("error", (error) => {
  console.error("WebSocket服务器错误:", error);
});

// 设置定时检查死连接
const checkInterval = 30000; // 每10秒检查一次
const timeoutDuration = 180000; // 180秒无活动视为离线

setInterval(() => {
  const now = Date.now();
  for (const [imei, user] of userPool.entries()) {
    if (now - user.lastSeen > timeoutDuration) {
      console.log(`用户因超时被移除 - IMEI: ${imei}`);
      // 如果ws连接仍然存在，尝试关闭它 ( aunque ws.on('close') deberia encargarse)
      if (user.ws.readyState !== WebSocket.CLOSED) {
        user.ws.terminate(); // 强制关闭连接
      }
      userPool.delete(imei);
    }
  }
}, checkInterval);

// 启动服务器
const PORT = 9527;
server.listen(PORT, () => {
  console.log(`服务器启动成功，监听端口 ${PORT}`);
  console.log(`WebSocket 服务器运行在 ws://localhost:${PORT}/websocket`);
  console.log(`HTTP 服务器运行在 http://localhost:${PORT}`);
});
