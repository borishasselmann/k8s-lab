#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <app-name> [options]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace   Kubernetes namespace (default: same as app-name)"
    echo "  -i, --image       Container image (default: nginx)"
    echo "  -t, --tag         Image tag (default: latest)"
    echo "  -p, --port        Container port (default: 80)"
    echo "  --no-ingress      Skip ingress.yaml"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 myapp -i nginx -t 1.25 -p 80"
    echo "  $0 redis -i redis -t 7-alpine -p 6379 --no-ingress"
    exit 1
}

# Default values
APP_NAME=""
NAMESPACE=""
IMAGE="nginx"
TAG="latest"
PORT="80"
NO_INGRESS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --no-ingress)
            NO_INGRESS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
        *)
            if [[ -z "$APP_NAME" ]]; then
                APP_NAME="$1"
            else
                echo -e "${RED}Unexpected argument: $1${NC}"
                usage
            fi
            shift
            ;;
    esac
done

# Validate app name
if [[ -z "$APP_NAME" ]]; then
    echo -e "${RED}Error: App name is required${NC}"
    usage
fi

# Validate app name format
if [[ ! "$APP_NAME" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
    echo -e "${RED}Error: App name must be lowercase alphanumeric with optional hyphens${NC}"
    exit 1
fi

# Default namespace to app name if not specified
if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE="$APP_NAME"
fi

# Check if app already exists
if [[ -d "$ROOT_DIR/apps/$APP_NAME" ]]; then
    echo -e "${RED}Error: App '$APP_NAME' already exists in apps/${NC}"
    exit 1
fi

if [[ -f "$ROOT_DIR/apps/$APP_NAME/application.yaml" ]]; then
    echo -e "${RED}Error: ArgoCD application '$APP_NAME/application.yaml' already exists${NC}"
    exit 1
fi

echo -e "${GREEN}Creating application: $APP_NAME${NC}"
echo "  Namespace: $NAMESPACE"
echo "  Image:     $IMAGE:$TAG"
echo "  Port:      $PORT"
echo "  Ingress:   $([ "$NO_INGRESS" = true ] && echo "No" || echo "Yes ($APP_NAME.localhost)")"
echo ""

# Create app directory
echo -e "${YELLOW}Creating files...${NC}"
mkdir -p "$ROOT_DIR/apps/$APP_NAME"

# Copy template files
cp "$SCRIPT_DIR/apps/APP_NAME/app.yaml" "$ROOT_DIR/apps/$APP_NAME/app.yaml"
cp "$SCRIPT_DIR/apps/APP_NAME/application.yaml" "$ROOT_DIR/apps/$APP_NAME/application.yaml"

if [[ "$NO_INGRESS" = false ]]; then
    cp "$SCRIPT_DIR/apps/APP_NAME/ingress.yaml" "$ROOT_DIR/apps/$APP_NAME/ingress.yaml"
fi

# Replace placeholders
echo -e "${YELLOW}Replacing placeholders...${NC}"

replace_placeholders() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' \
            -e "s/APP_NAME/$APP_NAME/g" \
            -e "s/NAMESPACE/$NAMESPACE/g" \
            -e "s/IMAGE/$IMAGE/g" \
            -e "s/TAG/$TAG/g" \
            -e "s/PORT/$PORT/g" \
            "$file"
    else
        sed -i \
            -e "s/APP_NAME/$APP_NAME/g" \
            -e "s/NAMESPACE/$NAMESPACE/g" \
            -e "s/IMAGE/$IMAGE/g" \
            -e "s/TAG/$TAG/g" \
            -e "s/PORT/$PORT/g" \
            "$file"
    fi
}

for file in "$ROOT_DIR/apps/$APP_NAME"/*.yaml; do
    if [[ -f "$file" ]]; then
        replace_placeholders "$file"
    fi
done

echo ""
echo -e "${GREEN}Application '$APP_NAME' created successfully!${NC}"
echo ""
echo "Files created:"
ls -1 "$ROOT_DIR/apps/$APP_NAME" | sed "s/^/  - apps\/$APP_NAME\//"
echo ""
echo "Optional files (copy from templates/apps/APP_NAME/ if needed):"
echo "  - policies.yaml   (NetworkPolicy + PodDisruptionBudget)"
echo "  - config.yaml     (ConfigMap + Secret + PVC)"
echo ""
echo "Next steps:"
echo "  1. Review apps/$APP_NAME/app.yaml"
echo "  2. Adjust health probes if needed (/health endpoint)"
echo "  3. Add to apps/kustomization.yaml:"
echo "     - $APP_NAME/application.yaml"
echo "  4. Commit and push:"
echo "     git add . && git commit -m \"Add $APP_NAME application\" && git push"
echo ""
if [[ "$NO_INGRESS" = false ]]; then
    echo "Access URL: http://$APP_NAME.localhost"
fi
