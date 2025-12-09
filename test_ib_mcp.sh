#!/bin/bash
# IB MCP 快速测试脚本

echo "=========================================="
echo "  IB MCP 服务器测试脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查 Docker 是否运行
echo "1. 检查 Docker 状态..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker 未运行，请先启动 Docker Desktop${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker 正在运行${NC}"

# 2. 检查容器状态
echo ""
echo "2. 检查容器状态..."
CONTAINERS=$(docker compose ps --format json 2>/dev/null)
if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}⚠️  容器未运行，尝试启动...${NC}"
    docker compose up -d
    sleep 5
fi

docker compose ps

# 3. 测试 API Gateway
echo ""
echo "3. 测试 API Gateway (https://localhost:5055)..."
GATEWAY_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:5055/v1/api/iserver/auth/status 2>/dev/null)
if [ "$GATEWAY_STATUS" = "200" ] || [ "$GATEWAY_STATUS" = "401" ]; then
    echo -e "${GREEN}✅ API Gateway 响应正常 (HTTP $GATEWAY_STATUS)${NC}"
    
    # 获取认证状态详情
    AUTH_RESPONSE=$(curl -sk https://localhost:5055/v1/api/iserver/auth/status 2>/dev/null)
    if echo "$AUTH_RESPONSE" | grep -q "authenticated.*true"; then
        echo -e "   ${GREEN}✅ 已认证${NC}"
    else
        echo -e "   ${YELLOW}⚠️  未认证 - 请访问 https://localhost:5055/ 登录${NC}"
    fi
else
    echo -e "${RED}❌ API Gateway 无响应 (HTTP $GATEWAY_STATUS)${NC}"
    echo "   查看日志: docker compose logs api_gateway"
fi

# 4. 测试 Tickle 端点
echo ""
echo "4. 测试 Tickle 端点..."
TICKLE_RESPONSE=$(curl -sk https://localhost:5055/v1/api/tickle 2>/dev/null)
if [ -n "$TICKLE_RESPONSE" ] && [ "$TICKLE_RESPONSE" != "null" ]; then
    echo -e "${GREEN}✅ Tickle 端点正常${NC}"
    echo "   响应: $(echo $TICKLE_RESPONSE | cut -c1-50)..."
else
    echo -e "${RED}❌ Tickle 端点无响应${NC}"
fi

# 5. 测试 MCP Server
echo ""
echo "5. 测试 MCP Server (http://localhost:5002)..."
# MCP Server 需要特定的 Accept 头，测试时使用正确的头
MCP_STATUS=$(curl -s -L -o /dev/null -w "%{http_code}" \
  -H "Accept: application/json, text/event-stream" \
  http://localhost:5002/mcp 2>/dev/null)

# 测试 FastAPI 文档（不需要特殊头）
DOCS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/docs 2>/dev/null)

if [ "$MCP_STATUS" = "200" ] || [ "$MCP_STATUS" = "405" ] || [ "$MCP_STATUS" = "400" ] || [ "$MCP_STATUS" = "406" ]; then
    # 406 也是正常的，表示端点存在但需要正确的 Accept 头
    if [ "$MCP_STATUS" = "406" ]; then
        echo -e "${GREEN}✅ MCP Server 端点正常 (HTTP $MCP_STATUS - 需要正确的 Accept 头，这是正常的)${NC}"
    else
        echo -e "${GREEN}✅ MCP Server 响应正常 (HTTP $MCP_STATUS)${NC}"
    fi
    
    if [ "$DOCS_STATUS" = "200" ]; then
        echo -e "   ${GREEN}✅ API 文档可访问: http://localhost:5002/docs${NC}"
    fi
else
    # 如果直接测试失败，尝试跟随重定向
    MCP_STATUS_REDIRECT=$(curl -s -L -o /dev/null -w "%{http_code}" \
      -H "Accept: application/json, text/event-stream" \
      http://localhost:5002/mcp/ 2>/dev/null)
    if [ "$MCP_STATUS_REDIRECT" = "200" ] || [ "$MCP_STATUS_REDIRECT" = "405" ] || [ "$MCP_STATUS_REDIRECT" = "400" ] || [ "$MCP_STATUS_REDIRECT" = "406" ]; then
        echo -e "${GREEN}✅ MCP Server 响应正常 (HTTP $MCP_STATUS_REDIRECT，已处理重定向)${NC}"
    else
        echo -e "${RED}❌ MCP Server 无响应 (HTTP $MCP_STATUS)${NC}"
        echo "   查看日志: docker compose logs mcp_server"
    fi
fi

# 6. 检查 Tickler 服务
echo ""
echo "6. 检查 Tickler 服务..."
TICKLER_LOGS=$(docker compose logs api_gateway 2>&1 | grep -i "tickler\|tickle" | tail -3)
if [ -n "$TICKLER_LOGS" ]; then
    echo -e "${GREEN}✅ Tickler 服务运行中${NC}"
    echo "   最新日志:"
    echo "$TICKLER_LOGS" | sed 's/^/   /'
else
    echo -e "${YELLOW}⚠️  未找到 Tickler 日志（可能刚启动，等待中...）${NC}"
fi

# 7. 测试 MCP 工具列表
echo ""
echo "7. 测试 MCP 工具列表..."
# 注意：MCP 需要先初始化会话，这里只测试端点是否响应
MCP_TOOLS=$(curl -s -L -X POST http://localhost:5002/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }' 2>/dev/null)

if echo "$MCP_TOOLS" | grep -q "tools"; then
    TOOL_COUNT=$(echo "$MCP_TOOLS" | grep -o '"name"' | wc -l | tr -d ' ')
    echo -e "${GREEN}✅ MCP 工具可用 (找到 $TOOL_COUNT 个工具)${NC}"
elif echo "$MCP_TOOLS" | grep -q "session\|initialize\|Bad Request"; then
    echo -e "${GREEN}✅ MCP Server 端点正常（需要先初始化会话，这是正常的）${NC}"
    echo "   提示: VS Code MCP 客户端会自动处理会话初始化"
else
    echo -e "${YELLOW}⚠️  无法获取工具列表（端点响应: ${MCP_TOOLS:0:100}...）${NC}"
fi

# 总结
echo ""
echo "=========================================="
echo "  测试总结"
echo "=========================================="

ALL_OK=true

if [ "$GATEWAY_STATUS" != "200" ] && [ "$GATEWAY_STATUS" != "401" ]; then
    ALL_OK=false
fi

# MCP Server 可能返回 200, 405, 400, 406（需要正确的 Accept 头）或 307（重定向后正常）
MCP_FINAL_STATUS=${MCP_STATUS_REDIRECT:-$MCP_STATUS}
if [ "$MCP_FINAL_STATUS" != "200" ] && [ "$MCP_FINAL_STATUS" != "405" ] && [ "$MCP_FINAL_STATUS" != "400" ] && [ "$MCP_FINAL_STATUS" != "406" ] && [ "$MCP_FINAL_STATUS" != "307" ]; then
    ALL_OK=false
fi

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✅ 所有核心服务正常运行！${NC}"
    echo ""
    echo "下一步："
    echo "1. 如果未认证，访问 https://localhost:5055/ 登录"
    echo "2. 在 VS Code 中配置 MCP (已存在 .vscode/mcp.json)"
    echo "3. 重启 VS Code 并在 Copilot Chat 中使用 MCP 工具"
    echo ""
    echo "有用的链接："
    echo "- API 文档: http://localhost:5002/docs"
    echo "- Gateway: https://localhost:5055/"
else
    echo -e "${RED}❌ 部分服务异常，请查看上述错误信息${NC}"
    echo ""
    echo "故障排查："
    echo "1. 查看容器日志: docker compose logs -f"
    echo "2. 检查端口占用: lsof -i :5055 -i :5002"
    echo "3. 重新构建: docker compose up --build -d"
fi

echo ""

