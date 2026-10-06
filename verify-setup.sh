#!/bin/bash
# verify-setup.sh

echo " Verificando setup del workshop..."
echo ""

# Azure CLI
if command -v az &> /dev/null; then
 echo " Azure CLI: $(az --version | head -n1)"
else
 echo " Azure CLI: NO INSTALADO"
fi

# Git
if command -v git &> /dev/null; then
 echo " Git: $(git --version)"
else
 echo " Git: NO INSTALADO"
fi

# jq
if command -v jq &> /dev/null; then
 echo " jq: $(jq --version)"
else
 echo " jq: NO INSTALADO"
fi

# VS Code
if command -v code &> /dev/null; then
 echo " VS Code: $(code --version | head -n1)"
else
 echo " VS Code: NO INSTALADO"
fi

# Azure subscription
echo ""
echo "🔐 Azure Subscription activa:"
az account show --query "{Name:name, ID:id, State:state}" -o table 2>/dev/null || echo " No logueado en Azure"

echo ""
echo " Estructura del workshop:"
if [ -d "docs/workshop/kitten-space-missions/solution" ]; then
 echo " Carpeta solution creada"
else
 echo " Carpeta solution NO creada"
fi

echo ""
echo " Configuración del agente:"
if [ -f ".github/agents/azure-architect.agent.md" ]; then
 echo " Agente Azure_Architect_Pro configurado"
else
 echo " Archivo del agente NO encontrado"
fi

if [ -f "mcp.json" ]; then
 echo " MCP servers configurados"
else
 echo " mcp.json NO encontrado"
fi

echo ""
echo " Verificación completada!"