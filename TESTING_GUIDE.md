# IB MCP 测试指南

本指南将帮助你测试 IB MCP 服务器是否正常工作。

## 📋 前置要求

1. **Docker Desktop** 已安装并运行
2. **VS Code** 已安装（可选，用于 Docker 扩展）
3. **Interactive Brokers 账户** 和登录凭证
4. **环境变量配置文件** (`.env`)

## 🔧 方法一：使用 VS Code Docker 扩展启动

### 步骤 1: 安装 Docker 扩展

1. 在 VS Code 中打开扩展市场 (Cmd+Shift+X / Ctrl+Shift+X)
2. 搜索 "Docker" (Microsoft 官方扩展)
3. 点击安装

### 步骤 2: 配置环境变量

在项目根目录创建 `.env` 文件（如果还没有）：

```bash
# Gateway 配置
GATEWAY_PORT=5055
GATEWAY_ENDPOINT=/v1/api
GATEWAY_INTERNAL_BASE_URL=https://api_gateway
GATEWAY_BASE_URL=https://localhost

# MCP Server 配置
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=5002
MCP_SERVER_PATH=/mcp
MCP_TRANSPORT_PROTOCOL=streamable-http
MCP_SERVER_BASE_URL=http://localhost
MCP_SERVER_INTERNAL_BASE_URL=http://mcp_server

# Tickler 配置（会话保活）
TICKLE_BASE_URL=https://localhost:5055
TICKLE_ENDPOINT=/v1/api/tickle
TICKLE_INTERVAL=60

# 可选：模块过滤
# INCLUDED_TAGS=Portfolio,Session,Market Data
# EXCLUDED_TAGS=
```

### 步骤 3: 使用 VS Code Docker 扩展启动

#### 方式 A: 通过 Docker Compose 启动（推荐）

1. **打开 Docker 扩展面板**
   - 点击左侧边栏的 Docker 图标
   - 或使用命令面板 (Cmd+Shift+P / Ctrl+Shift+P) 输入 "Docker: Focus on Docker View"

2. **找到 docker-compose.yml**
   - 在 Docker 扩展面板中，展开 "Containers" 或 "Compose"
   - 找到 `IB_MCP` 项目
   - 或者直接在文件资源管理器中右键点击 `docker-compose.yml`
   - 选择 "Compose Up" 或 "Compose Up (Detached)"

3. **查看日志**
   - 在 Docker 扩展面板中，展开容器列表
   - 点击容器名称查看日志
   - 或右键容器选择 "View Logs"

#### 方式 B: 通过终端启动（在 VS Code 集成终端中）

```bash
# 在 VS Code 集成终端中运行
docker compose up --build -d

# 查看日志
docker compose logs -f
```

### 步骤 4: 验证容器状态

在 VS Code Docker 扩展中：
- ✅ 两个容器应该显示为 "Running" 状态
  - `api_gateway` (绿色)
  - `mcp_server` (绿色)
- ✅ 检查健康状态
  - `api_gateway` 应该显示健康检查通过

## 🧪 方法二：使用命令行测试

### 步骤 1: 启动容器

```bash
cd /Users/Qiang/Projects/IB_MCP

# 构建并启动容器
docker compose up --build -d

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 步骤 2: 验证容器运行

```bash
# 检查容器是否运行
docker ps

# 应该看到两个容器：
# - api_gateway (端口 5055)
# - mcp_server (端口 5002)
```

## 🔐 步骤 3: 登录 IB 账户

**重要**: 必须先登录才能使用 API！

1. **打开浏览器**，访问：
   ```
   https://localhost:5055/
   ```
   ⚠️ 浏览器会显示 SSL 证书警告（这是正常的，因为是自签名证书）
   - Chrome/Edge: 点击 "高级" → "继续前往 localhost（不安全）"
   - Firefox: 点击 "高级" → "接受风险并继续"
   - Safari: 点击 "显示详细信息" → "访问此网站"

2. **查看登录 URL**
   - 在容器日志中查找登录 URL：
   ```bash
   docker compose logs api_gateway | grep -i "login\|url"
   ```
   - 或者访问 `https://localhost:5055/` 会自动重定向到登录页面

3. **使用 IB 凭证登录**
   - 输入你的 IB 用户名和密码
   - 如果成功，会看到 "Client login succeeds" 消息

## ✅ 步骤 4: 测试 API Gateway

### 测试 1: 检查认证状态

```bash
# 使用 curl 测试（忽略 SSL 证书）
curl -k https://localhost:5055/v1/api/iserver/auth/status

# 预期响应（JSON）：
# {
#   "authenticated": true,
#   "connected": true,
#   ...
# }
```

### 测试 2: 测试 Tickle 端点

```bash
curl -k -X GET https://localhost:5055/v1/api/tickle

# 预期响应：
# {"session": "..."}
```

### 测试 3: 检查 Tickler 服务

```bash
# 查看 tickler 日志
docker compose logs api_gateway | grep tickler

# 应该看到每 60 秒的 tickle 请求
```

## ✅ 步骤 5: 测试 MCP Server

### 测试 1: 检查 MCP Server 是否运行

```bash
# 测试 HTTP 端点
curl http://localhost:5002/mcp/

# 或测试 FastAPI 文档
curl http://localhost:5002/docs
```

### 测试 2: 测试 MCP 端点

```bash
# 测试 MCP 初始化
curl -X POST http://localhost:5002/mcp/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }'
```

### 测试 3: 列出可用工具

```bash
curl -X POST http://localhost:5002/mcp/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list"
  }'
```

## ✅ 步骤 6: 在 VS Code 中测试 MCP

### 配置 VS Code MCP 设置

1. **打开 VS Code 设置**
   - 按 `Cmd+,` (Mac) 或 `Ctrl+,` (Windows/Linux)
   - 或使用命令面板搜索 "Preferences: Open Settings (JSON)"

2. **添加 MCP 配置**

   在 `settings.json` 中添加：

   ```json
   {
     "chat.mcp.discovery.enabled": true,
     "mcp": {
       "servers": {
         "ib-mcp-server": {
           "type": "http",
           "url": "http://localhost:5002/mcp/"
         }
       },
       "inputs": []
     }
   }
   ```

   或者使用项目级别的配置（`.vscode/mcp.json` 已存在）：

   ```json
   {
     "servers": {
       "ib-mcp-server": {
         "type": "http",
         "url": "http://localhost:5002/mcp/"
       }
     },
     "inputs": []
   }
   ```

3. **重启 VS Code** 或重新加载窗口
   - 命令面板 → "Developer: Reload Window"

4. **在 Copilot Chat 中测试**
   - 打开 Copilot Chat (Cmd+L / Ctrl+L)
   - 尝试使用 MCP 工具，例如：
     - "获取我的账户列表"
     - "显示我的持仓信息"
     - "获取 AAPL 的市场数据"

## 🧪 完整测试脚本

创建一个测试脚本来验证所有功能：

```bash
#!/bin/bash
# test_ib_mcp.sh

echo "=== IB MCP 测试脚本 ==="
echo ""

# 1. 检查容器状态
echo "1. 检查容器状态..."
docker compose ps

# 2. 测试 API Gateway
echo ""
echo "2. 测试 API Gateway..."
GATEWAY_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:5055/v1/api/iserver/auth/status)
if [ "$GATEWAY_STATUS" = "200" ] || [ "$GATEWAY_STATUS" = "401" ]; then
    echo "✅ API Gateway 响应正常 (HTTP $GATEWAY_STATUS)"
else
    echo "❌ API Gateway 无响应 (HTTP $GATEWAY_STATUS)"
fi

# 3. 测试 MCP Server
echo ""
echo "3. 测试 MCP Server..."
MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/mcp/)
if [ "$MCP_STATUS" = "200" ] || [ "$MCP_STATUS" = "405" ]; then
    echo "✅ MCP Server 响应正常 (HTTP $MCP_STATUS)"
else
    echo "❌ MCP Server 无响应 (HTTP $MCP_STATUS)"
fi

# 4. 测试 Tickle
echo ""
echo "4. 测试 Tickle 端点..."
TICKLE_RESPONSE=$(curl -sk https://localhost:5055/v1/api/tickle)
if [ -n "$TICKLE_RESPONSE" ]; then
    echo "✅ Tickle 端点正常"
    echo "   响应: $TICKLE_RESPONSE"
else
    echo "❌ Tickle 端点无响应"
fi

# 5. 检查 Tickler 服务
echo ""
echo "5. 检查 Tickler 服务..."
TICKLER_LOGS=$(docker compose logs api_gateway 2>&1 | grep -i tickler | tail -1)
if [ -n "$TICKLER_LOGS" ]; then
    echo "✅ Tickler 服务运行中"
    echo "   最新日志: $TICKLER_LOGS"
else
    echo "⚠️  未找到 Tickler 日志（可能刚启动）"
fi

echo ""
echo "=== 测试完成 ==="
```

保存为 `test_ib_mcp.sh`，然后运行：

```bash
chmod +x test_ib_mcp.sh
./test_ib_mcp.sh
```

## 🔍 故障排查

### 问题 1: 容器无法启动

**症状**: `docker compose up` 失败

**解决方案**:
```bash
# 查看详细错误
docker compose up --build

# 检查端口是否被占用
lsof -i :5055
lsof -i :5002

# 清理并重新构建
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 问题 2: API Gateway 健康检查失败

**症状**: `api_gateway` 容器状态为 "unhealthy"

**解决方案**:
```bash
# 查看健康检查日志
docker compose logs api_gateway | grep healthcheck

# 手动测试健康检查端点
docker exec api_gateway /usr/local/bin/healthcheck.sh

# 检查 Gateway 是否在容器内运行
docker exec api_gateway curl -k https://localhost:5055/v1/api/iserver/auth/status
```

### 问题 3: MCP Server 无法连接到 Gateway

**症状**: MCP Server 日志显示连接错误

**解决方案**:
```bash
# 检查网络连接
docker exec mcp_server ping api_gateway

# 检查环境变量
docker exec mcp_server env | grep GATEWAY

# 查看 MCP Server 日志
docker compose logs mcp_server
```

### 问题 4: 认证失败

**症状**: API 调用返回 401 或认证错误

**解决方案**:
1. 确保已通过浏览器登录 (`https://localhost:5055/`)
2. 检查会话是否过期（需要重新登录）
3. 查看认证状态：
   ```bash
   curl -k https://localhost:5055/v1/api/iserver/auth/status
   ```

### 问题 5: VS Code MCP 无法连接

**症状**: VS Code 中看不到 MCP 工具

**解决方案**:
1. 检查 MCP Server 是否运行：
   ```bash
   curl http://localhost:5002/mcp/
   ```

2. 检查 VS Code 设置中的 URL 是否正确

3. 查看 VS Code 输出面板：
   - 打开 "View" → "Output"
   - 选择 "MCP" 或 "Copilot" 通道
   - 查看错误信息

4. 重启 VS Code 或重新加载窗口

## 📊 健康检查清单

使用以下清单确保一切正常：

- [ ] Docker Desktop 正在运行
- [ ] `.env` 文件已配置
- [ ] 两个容器都在运行 (`docker compose ps`)
- [ ] API Gateway 健康检查通过
- [ ] 已通过浏览器登录 IB 账户
- [ ] Tickle 端点响应正常
- [ ] MCP Server 响应正常
- [ ] VS Code MCP 配置正确
- [ ] 可以在 Copilot Chat 中使用 MCP 工具

## 🎯 快速测试命令

```bash
# 一键测试所有组件
docker compose ps && \
curl -sk https://localhost:5055/v1/api/tickle > /dev/null && echo "✅ Gateway OK" || echo "❌ Gateway Failed" && \
curl -s http://localhost:5002/mcp/ > /dev/null && echo "✅ MCP Server OK" || echo "❌ MCP Server Failed"
```

## 📝 下一步

测试成功后，你可以：

1. **在 VS Code Copilot 中使用 MCP 工具**
   - 获取账户信息
   - 查看持仓
   - 获取市场数据
   - 管理订单等

2. **查看 API 文档**
   - 访问 `http://localhost:5002/docs` 查看 FastAPI 文档
   - 查看 `ENDPOINTS.md` 了解所有可用端点

3. **自定义配置**
   - 修改 `.env` 调整端口和设置
   - 使用 `INCLUDED_TAGS` / `EXCLUDED_TAGS` 过滤模块

## 🆘 获取帮助

如果遇到问题：

1. 查看容器日志：`docker compose logs -f`
2. 检查 GitHub Issues
3. 查看 README.md 获取更多信息

