# IB MCP 代码结构分析

## 📋 项目概述

这是一个基于 **Model Context Protocol (MCP)** 的 Interactive Brokers Web API 包装器项目。项目将 IB 的 Web API 封装为 MCP 服务器，使 AI 助手（如 Claude）可以通过 MCP 协议直接访问 IB 交易功能。

## 🏗️ 整体架构

项目采用 **双容器 Docker Compose 架构**：

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                    │
│                      (mcp_net bridge)                        │
├──────────────────────────┬───────────────────────────────────┤
│   api_gateway Container  │    mcp_server Container           │
│   (Java 21)              │    (Python 3.11)                 │
│                          │                                   │
│  ┌────────────────────┐  │  ┌────────────────────────────┐ │
│  │ IB Client Portal   │  │  │  FastAPI Server            │ │
│  │ Gateway            │◄─┼──┤  (FastMCP)                 │ │
│  │                    │  │  │                            │ │
│  │ - Port: 5055       │  │  │  - Port: 5002              │ │
│  │ - SSL Enabled      │  │  │  - HTTP Transport          │ │
│  │ - Session Mgmt     │  │  │  - 13 Router Modules       │ │
│  └────────────────────┘  │  └────────────────────────────┘ │
│           │               │              │                  │
│           │               │              │                  │
│           ▼               │              ▼                  │
│  ┌────────────────────┐  │  ┌────────────────────────────┐ │
│  │ Tickler Service    │  │  │  Router Modules            │ │
│  │ (Keep-alive)       │  │  │  - alerts.py               │ │
│  │                    │  │  │  - contract.py              │ │
│  │ - Every 60s        │  │  │  - events_contracts.py     │ │
│  │ - /tickle endpoint │  │  │  - fa_allocation_...       │ │
│  └────────────────────┘  │  │  - fyis_and_notifications   │ │
│                          │  │  - market_data.py           │ │
│                          │  │  - options_chains.py        │ │
│                          │  │  - order_monitoring.py      │ │
│                          │  │  - orders.py                │ │
│                          │  │  - portfolio.py              │ │
│                          │  │  - scanner.py               │ │
│                          │  │  - session.py               │ │
│                          │  │  - watchlists.py            │ │
│                          │  └────────────────────────────┘ │
└──────────────────────────┴───────────────────────────────────┘
           │                              │
           │                              │
           ▼                              ▼
    IBKR Web API                    MCP Clients
    (api.ibkr.com)                  (VS Code, Claude, etc.)
```

## 📁 目录结构

```
IB_MCP/
├── api_gateway/                    # IB Client Portal Gateway 容器
│   ├── Dockerfile                  # Java 21 基础镜像，下载并配置 Gateway
│   ├── conf.yaml                   # Gateway 配置文件（SSL、端口、CORS等）
│   ├── run_gateway.sh              # 启动脚本（Gateway + Tickler）
│   ├── tickler.sh                  # 会话保活脚本（每60秒调用/tickle）
│   └── healthcheck.sh              # 健康检查脚本
│
├── mcp_server/                     # FastMCP 服务器容器
│   ├── Dockerfile                  # Python 3.11 + uv 基础镜像
│   ├── pyproject.toml              # Python 依赖管理（FastMCP, FastAPI等）
│   ├── fastapi_server.py           # FastAPI 应用入口，集成所有路由
│   ├── config.py                   # 配置管理（环境变量、模块过滤等）
│   └── routers/                     # 路由模块（13个模块）
│       ├── alerts.py               # 警报管理（5个端点）
│       ├── contract.py             # 合约搜索和信息（13个端点）
│       ├── events_contracts.py     # 事件合约（2个端点）
│       ├── fa_allocation_management.py  # FA分配管理（2个端点）
│       ├── fyis_and_notifications.py   # 通知管理（8个端点）
│       ├── market_data.py          # 市场数据（10个端点）
│       ├── options_chains.py       # 期权链（1个端点）
│       ├── order_monitoring.py     # 订单监控（3个端点）
│       ├── orders.py               # 订单操作（5个端点）
│       ├── portfolio.py            # 投资组合（13个端点）
│       ├── scanner.py              # 市场扫描器（3个端点）
│       ├── session.py              # 会话管理（5个端点）
│       └── watchlists.py           # 观察列表（6个端点）
│
├── docker-compose.yml              # Docker Compose 配置
├── README.md                       # 项目文档
├── ENDPOINTS.md                    # API 端点状态文档
└── .env                            # 环境变量配置（需用户创建）
```

## 🔧 核心组件详解

### 1. API Gateway Container (`api_gateway/`)

**职责**：运行 IB Client Portal Gateway，作为与 IB Web API 的代理层。

**关键文件**：

- **`Dockerfile`**：
  - 基于 `eclipse-temurin:21` (Java 21)
  - 下载并解压 IB Client Portal Gateway
  - 配置 SSL 证书和端口
  - 集成健康检查和 Tickler 服务

- **`conf.yaml`**：
```yaml
listenPort: 5055           # Gateway 监听端口
listenSsl: true            # 启用 SSL
proxyRemoteHost: "https://api.ibkr.com"  # IB API 地址
cors:
  origin.allowed: "*"      # CORS 配置
```

- **`run_gateway.sh`**：
  - 后台启动 Gateway
  - 等待健康检查通过
  - 启动 Tickler 服务保持会话活跃

- **`tickler.sh`**：
  - 每 60 秒调用 `/tickle` 端点
  - 防止会话超时（IB 会话约 6 分钟无活动会超时）

### 2. MCP Server Container (`mcp_server/`)

**职责**：提供 MCP 协议接口，将 FastAPI 路由转换为 MCP 工具。

**关键文件**：

#### `fastapi_server.py` - 应用入口

```python
# 核心逻辑：
1. 导入所有路由模块（13个）
2. 创建 FastAPI 应用
3. 注册所有路由到 FastAPI
4. 使用 FastMCP.from_fastapi() 将 FastAPI 转换为 MCP 服务器
5. 根据配置排除/包含特定标签的路由
```

**关键特性**：
- 使用 `FastMCP` 库自动将 FastAPI 路由转换为 MCP 工具
- 支持标签过滤（`INCLUDED_TAGS` / `EXCLUDED_TAGS`）
- 支持多种传输协议（`streamable-http`）

#### `config.py` - 配置管理

**功能**：
1. **环境变量加载**：
   - `GATEWAY_PORT`, `GATEWAY_ENDPOINT`
   - `MCP_SERVER_HOST`, `MCP_SERVER_PORT`
   - `MCP_TRANSPORT_PROTOCOL`
   - `INCLUDED_TAGS`, `EXCLUDED_TAGS`

2. **BASE_URL 构建**：
   ```python
   BASE_URL = f"{GATEWAY_INTERNAL_BASE_URL}:{GATEWAY_PORT}{GATEWAY_ENDPOINT}"
   # 例如: "https://api_gateway:5055/v1/api"
   ```

3. **模块描述管理**：
   - 定义所有 13 个模块及其描述
   - 根据 `INCLUDED_TAGS` / `EXCLUDED_TAGS` 动态过滤
   - 生成 FastAPI 文档描述

#### 路由模块结构 (`routers/*.py`)

**统一模式**：

```python
# 1. 导入
from fastapi import APIRouter, Query, Body, Path
import httpx
from mcp_server.config import BASE_URL

# 2. 创建路由器
router = APIRouter()

# 3. Pydantic 模型（如需要）
class RequestModel(BaseModel):
    field: str = Field(..., description="...")

# 4. 路由端点
@router.get("/endpoint/path", tags=["Module"], summary="...")
async def endpoint_function(
    param: str = Path(..., description="...")
):
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.get(f"{BASE_URL}/endpoint/path", timeout=10)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as exc:
            return {"error": "IBKR API Error", ...}
        except httpx.RequestError as exc:
            return {"error": "Request Error", ...}
```

**路由模块列表**（共 13 个，79 个端点）：

| 模块 | 文件 | 端点数量 | 主要功能 |
|------|------|---------|---------|
| Alerts | `alerts.py` | 5 | 创建、修改、删除价格/时间/保证金警报 |
| Contract | `contract.py` | 13 | 搜索合约、获取合约详情、期权链等 |
| Events Contracts | `events_contracts.py` | 2 | 事件合约信息 |
| FA Allocation | `fa_allocation_management.py` | 2 | 财务顾问分配组管理 |
| FYIs & Notifications | `fyis_and_notifications.py` | 8 | 通知和免责声明管理 |
| Market Data | `market_data.py` | 10 | 实时和历史市场数据 |
| Options Chains | `options_chains.py` | 1 | 期权链数据 |
| Order Monitoring | `order_monitoring.py` | 3 | 订单状态和交易历史 |
| Orders | `orders.py` | 5 | 下单、修改、取消订单 |
| Portfolio | `portfolio.py` | 13 | 持仓、账户摘要、账本等 |
| Scanner | `scanner.py` | 3 | 市场扫描器 |
| Session | `session.py` | 5 | 认证、会话管理 |
| Watchlists | `watchlists.py` | 6 | 观察列表管理 |

### 3. Docker Compose 配置

**网络架构**：
- 使用 `mcp_net` bridge 网络连接两个容器
- `api_gateway` 通过内部 URL 暴露给 `mcp_server`
- `mcp_server` 通过端口映射暴露给主机

**依赖关系**：
- `mcp_server` 依赖 `api_gateway` 的健康检查
- 使用 `depends_on` + `condition: service_healthy` 确保启动顺序

**卷挂载**：
- `api_gateway/conf.yaml` → 容器内配置文件
- `mcp_server/` → 开发时挂载整个目录（热重载）

## 🔄 数据流

### 请求流程

```
MCP Client (VS Code/Claude)
    │
    │ HTTP Request
    ▼
MCP Server (FastAPI + FastMCP)
    │
    │ 转换 MCP 工具调用为 HTTP 请求
    │ 使用 httpx.AsyncClient
    ▼
API Gateway (IB Client Portal Gateway)
    │
    │ 添加认证、SSL、代理
    ▼
IBKR Web API (api.ibkr.com)
    │
    │ JSON Response
    ▼
API Gateway
    │
    ▼
MCP Server
    │
    │ 转换为 MCP 工具响应
    ▼
MCP Client
```

### 会话管理流程

```
启动时：
1. API Gateway 启动
2. 用户通过浏览器登录 (https://localhost:5055)
3. 会话建立，Cookie 保存
4. Tickler 服务启动，每 60 秒调用 /tickle
5. MCP Server 启动，连接到 Gateway

运行时：
- Tickler 持续保持会话活跃
- 如果会话过期，调用 /iserver/reauthenticate
- 所有请求自动携带会话 Cookie
```

## 🛠️ 技术栈

### API Gateway
- **语言**: Java 21
- **基础镜像**: `eclipse-temurin:21`
- **组件**: IB Client Portal Gateway (官方 Java 应用)
- **功能**: SSL 代理、会话管理、CORS

### MCP Server
- **语言**: Python 3.11
- **基础镜像**: `ghcr.io/astral-sh/uv:python3.11-bookworm-slim`
- **核心框架**:
  - `FastAPI` (0.116.0) - Web 框架
  - `FastMCP` (>=2.13.3) - MCP 协议适配器
  - `httpx` (0.28.1) - 异步 HTTP 客户端
  - `pydantic` (>=2.11.7) - 数据验证
- **包管理**: `uv` (现代 Python 包管理器)

### 容器编排
- **Docker Compose** - 多容器编排
- **网络**: Bridge 网络 (`mcp_net`)
- **健康检查**: 自定义脚本

## 📊 代码组织特点

### 1. 模块化设计
- 每个功能模块独立文件
- 统一的路由模式
- 清晰的职责分离

### 2. 配置驱动
- 环境变量集中管理
- 支持模块过滤（`INCLUDED_TAGS` / `EXCLUDED_TAGS`）
- 灵活的端点配置

### 3. 错误处理
- 统一的异常处理模式
- 详细的错误信息返回
- HTTP 状态码传播

### 4. 类型安全
- 使用 Pydantic 模型验证
- FastAPI 自动生成 OpenAPI 文档
- 类型提示支持

### 5. 开发友好
- 热重载支持（卷挂载）
- 详细的日志输出
- 健康检查机制

## 🔐 安全特性

1. **SSL/TLS**: Gateway 使用 SSL 加密
2. **会话管理**: 基于 Cookie 的认证
3. **CORS 配置**: 可配置的跨域策略
4. **网络隔离**: Docker 网络隔离容器

## 📈 扩展性

### 添加新端点
1. 在对应的 `routers/*.py` 中添加路由
2. 遵循统一的模式（httpx + 错误处理）
3. 更新 `ENDPOINTS.md` 文档

### 添加新模块
1. 创建新的 `routers/new_module.py`
2. 在 `fastapi_server.py` 中导入并注册
3. 在 `config.py` 的 `ALL_MODULES` 中添加描述

### 自定义配置
- 通过环境变量配置
- 修改 `conf.yaml` 调整 Gateway 行为
- 使用标签过滤控制暴露的端点

## 🐛 已知限制

1. **OpenAPI 规范问题**: IB 官方 OpenAPI 规范有 351 个验证错误，无法自动生成路由
2. **手动开发**: 所有路由需要手动编写和维护
3. **会话超时**: 需要 Tickler 服务保持会话活跃
4. **本地认证**: 必须在运行 Gateway 的机器上通过浏览器登录

## 📝 总结

这是一个**架构清晰、模块化、易于扩展**的项目：

- ✅ **清晰的职责分离**: Gateway 负责代理，MCP Server 负责协议转换
- ✅ **统一的代码模式**: 所有路由遵循相同的模式
- ✅ **完善的配置系统**: 环境变量 + 配置文件
- ✅ **良好的开发体验**: Docker Compose + 热重载
- ✅ **类型安全**: Pydantic + FastAPI 类型系统
- ✅ **文档完善**: README + ENDPOINTS 文档

项目成功将复杂的 IB Web API 封装为标准的 MCP 服务器，使 AI 助手可以轻松访问交易功能。

