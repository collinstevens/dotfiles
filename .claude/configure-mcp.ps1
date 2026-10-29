$ErrorActionPreference = "Stop"

if (-not (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host "Skipped Claude MCP servers: claude is not installed"
    return
}

& claude mcp remove --scope user excalidraw *> $null
& claude mcp add --scope user --transport http excalidraw https://mcp.excalidraw.com/mcp
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: unable to add the excalidraw MCP server"
    exit 1
}
