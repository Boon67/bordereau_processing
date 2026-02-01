# Configuration Guide

## Application Configuration

### Customizing the Application Name

The application name displayed in the header can be customized via the `default.config` file.

#### Configuration File

Edit `deployment/default.config`:

```bash
# Application Configuration
APP_NAME="Snowflake Pipeline"  # Change this to your desired name
ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1"  # Allowed LLM models for field mapping
```

#### Examples

```bash
# Default
APP_NAME="Snowflake Pipeline"

# Custom examples
APP_NAME="Healthcare Claims Pipeline"
APP_NAME="Data Processing Platform"
APP_NAME="Acme Corp Data Pipeline"
```

#### How It Works

1. **Configuration**: Set `APP_NAME` in `deployment/default.config`
2. **Build Process**: The deployment script passes this value to Docker build
3. **Frontend**: The React app reads this from environment variables
4. **Display**: The name appears in the application header

#### Deployment

After changing the `APP_NAME`, redeploy the containers:

```bash
cd deployment
./deploy_container.sh
```

The new application name will be displayed in the header of the web interface.

#### Local Development

For local development, edit `frontend/.env`:

```bash
VITE_APP_NAME="Your App Name"
VITE_API_URL="/api"
```

Then restart the development server:

```bash
cd frontend
npm run dev
```

### Configuring Allowed LLM Models

The application can restrict which Snowflake Cortex LLM models are available for field mapping.

#### Configuration File

Edit `deployment/default.config`:

```bash
# Application Configuration
ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1"
```

#### Examples

```bash
# Default (recommended models)
ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1"

# Allow only Claude models
ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,CLAUDE-3-5-SONNET"

# Allow multiple models
ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,CLAUDE-3-7-SONNET,OPENAI-GPT-4.1,DEEPSEEK-R1"
```

#### How It Works

1. **Configuration**: Set `ALLOWED_LLM_MODELS` as a comma-separated list in `deployment/default.config`
2. **Build Process**: The deployment script passes this to the backend Docker build
3. **Backend**: The API filters available Cortex models to only show allowed ones
4. **Frontend**: The LLM mapping UI displays only the allowed models

#### Deployment

After changing `ALLOWED_LLM_MODELS`, redeploy the containers:

```bash
cd deployment
./deploy_container.sh
```

#### Local Development

For local development, set the environment variable:

```bash
export ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1"
cd backend
uvicorn app.main:app --reload
```

## Other Configuration Options

See `deployment/default.config` for all available configuration options:

- **Database Configuration**: Database and schema names
- **Service Configuration**: SPCS service names
- **Task Configuration**: Scheduling and automation
- **Processing Configuration**: Batch sizes and retry settings
- **Deployment Options**: What components to deploy

## Environment-Specific Configuration

Create environment-specific configuration files:

```bash
# Development
cp deployment/default.config deployment/dev.config
# Edit dev.config with dev-specific settings

# Production
cp deployment/default.config deployment/prod.config
# Edit prod.config with prod-specific settings
```

Deploy with specific configuration:

```bash
# Use custom config
export CONFIG_FILE=deployment/prod.config
./deploy_container.sh
```
