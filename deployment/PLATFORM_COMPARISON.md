# Platform Comparison - Linux/Mac vs Windows

Quick reference showing equivalent commands and scripts across platforms.

## Deployment Scripts

| Purpose | Linux/Mac | Windows | Notes |
|---------|-----------|---------|-------|
| **Full Deployment** | `./deploy.sh` | `deploy.bat` | Deploys Bronze + Silver + Gold layers |
| **Bronze Layer** | `./deploy_bronze.sh` | `deploy_bronze.bat` | Bronze layer only |
| **Silver Layer** | `./deploy_silver.sh` | `deploy_silver.bat` | Silver layer only |
| **Gold Layer** | `./deploy_gold.sh` | `deploy_gold.bat` | Gold layer only |
| **Container Deployment** | `./deploy_container.sh` | `deploy_container.bat` | SPCS deployment |
| **Undeploy** | `./undeploy.sh` | `undeploy.bat` | Remove all resources |
| **Check Connection** | `./check_snow_connection.sh` | `check_snow_connection.bat` | Verify Snow CLI |
| **Load Samples** | `./load_sample_schemas.sh` | `load_sample_schemas.bat` | Load sample data |

## Command Options

| Option | Linux/Mac | Windows | Description |
|--------|-----------|---------|-------------|
| **Verbose Mode** | `-v` or `--verbose` | `-v` or `--verbose` | Show all SQL output |
| **Help** | `-h` or `--help` | `-h` or `--help` | Show help message |
| **Undeploy** | `-u` or `--undeploy` | `-u` or `--undeploy` | Remove resources |
| **Connection** | `./deploy.sh PROD` | `deploy.bat PROD` | Use specific connection |
| **Custom Config** | `./deploy.sh PROD prod.config` | `deploy.bat PROD prod.config` | Use custom config |

## Common Commands

### Configuration

| Task | Linux/Mac | Windows |
|------|-----------|---------|
| **Add Connection** | `snow connection add` | `snow connection add` |
| **List Connections** | `snow connection list` | `snow connection list` |
| **Test Connection** | `snow connection test` | `snow connection test` |
| **Edit Config** | `nano default.config` | `notepad default.config` |
| **Copy Config** | `cp custom.config.example custom.config` | `copy custom.config.example custom.config` |

### Deployment

| Task | Linux/Mac | Windows |
|------|-----------|---------|
| **Deploy All** | `cd deployment && ./deploy.sh` | `cd deployment & deploy.bat` |
| **Deploy Verbose** | `./deploy.sh -v` | `deploy.bat -v` |
| **Deploy to Prod** | `./deploy.sh PRODUCTION` | `deploy.bat PRODUCTION` |
| **Deploy Containers** | `./deploy_container.sh` | `deploy_container.bat` |
| **Undeploy** | `./undeploy.sh` | `undeploy.bat` |

### Local Development

| Task | Linux/Mac | Windows |
|------|-----------|---------|
| **Start All** | `./start.sh` | See note below* |
| **Start Backend** | `cd backend && source venv/bin/activate && uvicorn app.main:app --reload` | `cd backend & venv\Scripts\activate & uvicorn app.main:app --reload` |
| **Start Frontend** | `cd frontend && npm run dev` | `cd frontend & npm run dev` |
| **Docker Compose Up** | `docker-compose up -d` | `docker-compose up -d` |
| **Docker Compose Down** | `docker-compose down` | `docker-compose down` |

*Windows: Start backend and frontend in separate terminals

### Data Management

| Task | Linux/Mac | Windows |
|------|-----------|---------|
| **Upload Data** | `snow stage put sample_data/*.csv @BRONZE.SRC/` | `snow stage put sample_data\*.csv @BRONZE.SRC/` |
| **List Stage** | `snow stage list @BRONZE.SRC/` | `snow stage list @BRONZE.SRC/` |
| **Execute SQL** | `snow sql -q "SELECT * FROM BRONZE.file_processing_queue;"` | `snow sql -q "SELECT * FROM BRONZE.file_processing_queue;"` |
| **Execute SQL File** | `snow sql -f query.sql` | `snow sql -f query.sql` |

### Service Management

| Task | Linux/Mac | Windows |
|------|-----------|---------|
| **List Services** | `snow spcs service list` | `snow spcs service list` |
| **Service Status** | `snow spcs service status BORDEREAU_APP` | `snow spcs service status BORDEREAU_APP` |
| **Service Logs** | `snow spcs service logs BORDEREAU_APP` | `snow spcs service logs BORDEREAU_APP` |
| **List Endpoints** | `snow spcs service list-endpoints BORDEREAU_APP` | `snow spcs service list-endpoints BORDEREAU_APP` |

## Environment Variables

| Concept | Linux/Mac | Windows (Batch) | Windows (PowerShell) |
|---------|-----------|-----------------|---------------------|
| **Set Variable** | `export VAR=value` | `set "VAR=value"` | `$env:VAR = "value"` |
| **Use Variable** | `$VAR` or `${VAR}` | `%VAR%` or `!VAR!` | `$env:VAR` |
| **Default Value** | `${VAR:-default}` | `if "%VAR%"=="" set "VAR=default"` | `if (!$env:VAR) { $env:VAR = "default" }` |
| **Check If Set** | `if [ -z "$VAR" ]` | `if "%VAR%"==""` | `if (!$env:VAR)` |

## Path Handling

| Concept | Linux/Mac | Windows |
|---------|-----------|---------|
| **Path Separator** | `/` | `\` |
| **Current Directory** | `./script.sh` | `script.bat` or `.\script.bat` |
| **Parent Directory** | `../file.txt` | `..\file.txt` |
| **Home Directory** | `~/.config` | `%USERPROFILE%\.config` |
| **Temp Directory** | `/tmp` | `%TEMP%` |
| **Script Directory** | `$(dirname "$0")` | `%~dp0` |

## File Operations

| Task | Linux/Mac | Windows (Batch) | Windows (PowerShell) |
|------|-----------|-----------------|---------------------|
| **Copy File** | `cp source dest` | `copy source dest` | `Copy-Item source dest` |
| **Move File** | `mv source dest` | `move source dest` | `Move-Item source dest` |
| **Delete File** | `rm file` | `del file` | `Remove-Item file` |
| **Create Directory** | `mkdir -p dir` | `mkdir dir` (creates parents) | `New-Item -Type Directory dir` |
| **List Files** | `ls` or `ls -la` | `dir` | `Get-ChildItem` or `ls` |
| **Read File** | `cat file` | `type file` | `Get-Content file` |
| **Check If Exists** | `[ -f file ]` | `if exist file` | `Test-Path file` |

## Text Processing

| Task | Linux/Mac | Windows (Batch) | Windows (PowerShell) |
|------|-----------|-----------------|---------------------|
| **Replace Text** | `sed 's/old/new/' file` | PowerShell: `(Get-Content file) -replace 'old','new'` | `(Get-Content file) -replace 'old','new'` |
| **Find Text** | `grep pattern file` | `findstr pattern file` | `Select-String pattern file` |
| **JSON Parse** | `jq '.field' file.json` | `jq '.field' file.json` (requires jq.exe) | `(Get-Content file.json | ConvertFrom-Json).field` |

## Control Flow

| Concept | Linux/Mac | Windows (Batch) | Windows (PowerShell) |
|---------|-----------|-----------------|---------------------|
| **If Statement** | `if [ condition ]; then` | `if condition (` | `if (condition) {` |
| **Else** | `else` | `) else (` | `} else {` |
| **End If** | `fi` | `)` | `}` |
| **For Loop** | `for i in list; do` | `for %%i in (list) do (` | `foreach ($i in $list) {` |
| **While Loop** | `while [ condition ]; do` | `:loop` + `if` + `goto loop` | `while (condition) {` |
| **Function** | `function_name() {` | `:function_name` | `function Function-Name {` |
| **Exit** | `exit 1` | `exit /b 1` | `exit 1` |

## Special Variables

| Purpose | Linux/Mac | Windows (Batch) | Windows (PowerShell) |
|---------|-----------|-----------------|---------------------|
| **Script Name** | `$0` | `%0` | `$MyInvocation.MyCommand.Name` |
| **All Arguments** | `$@` | `%*` | `$args` |
| **Argument 1** | `$1` | `%1` | `$args[0]` |
| **Argument Count** | `$#` | N/A (manual count) | `$args.Count` |
| **Exit Code** | `$?` | `%ERRORLEVEL%` | `$LASTEXITCODE` |
| **Process ID** | `$$` | `%RANDOM%` (not PID) | `$PID` |

## Configuration Files

Configuration files (`.config`) are **identical** across platforms:

```properties
# Works on both Linux/Mac and Windows
DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_ROLE=SYSADMIN
USE_DEFAULT_CONNECTION=true
AUTO_APPROVE=false
```

## Snowflake CLI Commands

All `snow` CLI commands are **identical** across platforms:

```bash
# These work the same on Linux/Mac and Windows
snow connection add
snow connection list
snow connection test
snow sql -q "SELECT CURRENT_USER();"
snow sql -f script.sql
snow stage put file.csv @BRONZE.SRC/
snow spcs service list
snow spcs service status SERVICE_NAME
```

## Docker Commands

All `docker` and `docker-compose` commands are **identical** across platforms:

```bash
# These work the same on Linux/Mac and Windows
docker build -t image:tag .
docker push image:tag
docker-compose up -d
docker-compose down
docker ps
docker logs container_name
```

## Documentation Files

| Document | Platform | Description |
|----------|----------|-------------|
| **README.md** | All | Main project documentation |
| **QUICK_START.md** | All | Quick start guide |
| **deployment/README.md** | All | Deployment guide |
| **deployment/DEPLOYMENT_SNOW_CLI.md** | All | Snow CLI deployment details |
| **deployment/WINDOWS_DEPLOYMENT.md** | Windows | Windows-specific guide |
| **deployment/WINDOWS_QUICK_REFERENCE.md** | Windows | Windows quick commands |
| **deployment/PLATFORM_COMPARISON.md** | All | This file |

## Tips for Cross-Platform Development

### For Linux/Mac Users Working on Windows

1. **Use `deploy.bat` instead of `./deploy.sh`**
2. **Paths use backslashes:** `deployment\deploy.bat`
3. **No `./` prefix needed:** Just `deploy.bat`
4. **Environment variables:** Use `%VAR%` instead of `$VAR`
5. **Consider WSL:** If you prefer bash, use Windows Subsystem for Linux

### For Windows Users Working on Linux/Mac

1. **Use `./deploy.sh` instead of `deploy.bat`**
2. **Paths use forward slashes:** `deployment/deploy.sh`
3. **Scripts need execute permission:** `chmod +x deploy.sh`
4. **Environment variables:** Use `$VAR` instead of `%VAR%`
5. **Line endings:** Ensure scripts have LF (not CRLF) line endings

### Universal Best Practices

1. **Use Snow CLI:** Commands are identical across platforms
2. **Use Docker:** Commands are identical across platforms
3. **Configuration files:** Use same `.config` files on all platforms
4. **SQL scripts:** Work identically on all platforms
5. **Documentation:** Refer to platform-specific guides when needed

## Getting Help

### Linux/Mac
```bash
./deploy.sh --help
man snow
```

### Windows
```cmd
deploy.bat --help
snow --help
```

### Both Platforms
- Check documentation in `deployment/` folder
- Review logs in `logs/` directory
- Use verbose mode: `-v` flag
- Test connection: `snow connection test`

## Quick Reference Links

- **Windows Users:** [WINDOWS_DEPLOYMENT.md](WINDOWS_DEPLOYMENT.md) | [WINDOWS_QUICK_REFERENCE.md](WINDOWS_QUICK_REFERENCE.md)
- **All Users:** [README.md](README.md) | [DEPLOYMENT_SNOW_CLI.md](DEPLOYMENT_SNOW_CLI.md)
- **Container Deployment:** [SNOWPARK_CONTAINER_DEPLOYMENT.md](SNOWPARK_CONTAINER_DEPLOYMENT.md)
