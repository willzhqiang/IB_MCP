# MCP 配置指南：Cursor vs VS Code

## 📋 当前状态

根据检查，你的项目中：
- ✅ **存在**: `.vscode/mcp.json` 
- ❌ **不存在**: `.cursor` 文件夹

## 🔍 Cursor 和 VS Code 的 MCP 配置关系

### 1. 配置文件位置

**Cursor** 和 **VS Code** 都支持 MCP 配置，但处理方式略有不同：

- **VS Code**: 使用 `.vscode/mcp.json` 或全局 `settings.json` 中的 `mcp` 配置
- **Cursor**: 
  - 优先使用 `.cursor/mcp.json`（如果存在）
  - 如果没有 `.cursor/mcp.json`，会回退到 `.vscode/mcp.json`
  - 也支持全局设置中的 MCP 配置

### 2. 当前配置分析

你的 `.vscode/settings.json` 中已经启用了 Cursor 支持：

```json
{
    "chat.mcp.discovery.enabled": {
        "claude-desktop": true,
        "windsurf": true,
        "cursor-global": true,
        "cursor-workspace": true  // ← 这个启用了工作区级别的 MCP 发现
    }
}
```

这意味着 Cursor 会读取 `.vscode/mcp.json` 中的配置。

## ⚠️ 潜在冲突情况

### 如果同时存在两个文件：

```
项目根目录/
├── .vscode/
│   └── mcp.json  ← VS Code 使用这个
└── .cursor/
    └── mcp.json  ← Cursor 优先使用这个
```

**可能的问题**：
1. **配置不一致**: 两个文件内容不同时，Cursor 和 VS Code 会使用不同的配置
2. **维护困难**: 需要同时更新两个文件
3. **混淆**: 不清楚哪个配置实际生效

## ✅ 推荐方案

### 方案 1: 只使用 `.vscode/mcp.json`（推荐）

**优点**：
- ✅ Cursor 和 VS Code 都能使用
- ✅ 只需维护一个文件
- ✅ 配置统一，不会冲突

**当前状态**：你的项目已经是这样配置的！

```json
// .vscode/mcp.json
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

### 方案 2: 只使用 `.cursor/mcp.json`

如果你**只使用 Cursor**，可以：
1. 创建 `.cursor/mcp.json`
2. 删除或忽略 `.vscode/mcp.json`

**步骤**：
```bash
# 创建 .cursor 文件夹
mkdir -p .cursor

# 复制配置
cp .vscode/mcp.json .cursor/mcp.json

# 可选：在 .gitignore 中忽略 .vscode/mcp.json（如果只给 Cursor 用）
```

### 方案 3: 使用全局配置

在 Cursor 的全局设置中配置 MCP，而不是项目级别的配置。

**位置**：
- macOS: `~/Library/Application Support/Cursor/User/settings.json`
- Windows: `%APPDATA%\Cursor\User\settings.json`
- Linux: `~/.config/Cursor/User/settings.json`

## 🔧 验证配置是否生效

### 在 Cursor 中检查：

1. **打开 Cursor 设置**
   - `Cmd+,` (Mac) 或 `Ctrl+,` (Windows/Linux)
   - 搜索 "MCP" 或 "Model Context Protocol"

2. **检查 MCP 服务器状态**
   - 打开 Copilot Chat (Cmd+L / Ctrl+L)
   - 查看是否有 MCP 工具可用
   - 尝试使用命令，如 "获取我的账户列表"

3. **查看输出日志**
   - `View` → `Output`
   - 选择 "MCP" 或 "Copilot" 通道
   - 查看是否有连接错误

### 测试命令：

```bash
# 检查 MCP Server 是否运行
curl http://localhost:5002/mcp/

# 查看当前配置
cat .vscode/mcp.json
```

## 📝 最佳实践

1. **统一配置位置**
   - 如果同时使用 Cursor 和 VS Code：使用 `.vscode/mcp.json`
   - 如果只用 Cursor：可以使用 `.cursor/mcp.json` 或 `.vscode/mcp.json`

2. **避免重复配置**
   - 不要同时在两个位置创建 `mcp.json`
   - 如果创建了 `.cursor/mcp.json`，考虑删除 `.vscode/mcp.json`（或反之）

3. **版本控制**
   - 将 `mcp.json` 提交到 Git（如果配置是项目级别的）
   - 或者添加到 `.gitignore`（如果是个人配置）

4. **文档化**
   - 在 README 中说明使用的配置方式
   - 团队成员应该知道使用哪个配置文件

## 🎯 针对你的情况

**当前状态**：✅ 配置正确，无冲突

你目前只有 `.vscode/mcp.json`，这是**最佳实践**：
- ✅ Cursor 会自动读取 `.vscode/mcp.json`（因为 `cursor-workspace: true`）
- ✅ VS Code 也会读取 `.vscode/mcp.json`
- ✅ 只需维护一个配置文件
- ✅ 不会产生冲突

**建议**：
- **保持现状**，不需要创建 `.cursor/mcp.json`
- 如果将来需要为 Cursor 和 VS Code 使用不同配置，再考虑分离

## 🐛 故障排查

如果 MCP 在 Cursor 中不工作：

1. **检查配置文件路径**
   ```bash
   # 确认文件存在
   ls -la .vscode/mcp.json
   ```

2. **检查 URL 是否正确**
   ```bash
   # 测试 MCP Server
   curl http://localhost:5002/mcp/
   ```

3. **检查 Cursor 设置**
   - 确保 `chat.mcp.discovery.enabled.cursor-workspace` 为 `true`
   - 重启 Cursor

4. **查看日志**
   - Cursor → View → Output → 选择 "MCP" 通道

## 📚 参考

- [Cursor MCP 文档](https://cursor.sh/docs)
- [VS Code MCP 文档](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
- [MCP 协议规范](https://modelcontextprotocol.io)

