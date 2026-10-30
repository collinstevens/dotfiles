$ErrorActionPreference = "Stop"

if (-not (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host "Skipped Claude MCP servers: claude is not installed"
    return
}

& claude mcp remove --scope user excalidraw *> $null

$excalidrawApiKey = $env:EXCALIDRAW_API_KEY
if (-not $excalidrawApiKey) {
    $excalidrawApiKey = [Environment]::GetEnvironmentVariable("EXCALIDRAW_API_KEY", "User")
}
if (-not $excalidrawApiKey) {
    Write-Host "Skipped the excalidraw MCP server: EXCALIDRAW_API_KEY is not set"
    return
}

& claude mcp add --scope user --transport http excalidraw https://api.excalidraw.com/api/v1/mcp --header "Authorization: Bearer $excalidrawApiKey"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: unable to add the excalidraw MCP server"
    exit 1
}
