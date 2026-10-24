#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_PATH="$SCRIPT_DIR/projects.json"

command="${1:-help}"
name="$2"

case "$command" in
    list-projects)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" list-projects
    ;;
    status)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" status
    ;;
    sync)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" sync
    ;;
    start-project)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" start-project "$name"
    ;;
    stop-project)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" stop-project "$name"
    ;;
    stop-all)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" stop-all
    ;;
    provision-project)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" provision-project "$name"
    ;;
    add-service)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" add-service "$name"
    ;;
    start-service)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" start-service "$name" "${@:3}"
    ;;
    stop-service)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" stop-service "$name" "${@:3}"
    ;;
    restart-service)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" restart-service "$name"
    ;;
    logs)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" logs "$name"
    ;;
    *)
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/manage.ps1" help
    ;;
esac
