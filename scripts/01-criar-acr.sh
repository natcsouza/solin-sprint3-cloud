#!/usr/bin/env bash
# =====================================================================
# Etapa 1 - Grupo de recursos + Azure Container Registry (ACR)
#
# O ACR e o registro PRIVADO das nossas imagens. E o equivalente ao
# Docker Hub, porem dentro da assinatura, com autenticacao integrada.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

echo ">>> Registrando o provedor de Container Registry (so precisa uma vez)"
az provider register --namespace Microsoft.ContainerRegistry

echo ">>> Criando o grupo de recursos ${RG}"
az group create \
    --name "${RG}" \
    --location "${LOCATION}" \
    --tags projeto=SOLIN turma=2TDSR sprint=3

echo ">>> Criando o Azure Container Registry ${ACR_NAME}"
az acr create \
    --resource-group "${RG}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --location "${LOCATION}" \
    --admin-enabled true

echo ""
echo ">>> ACR criado. Servidor de login:"
az acr show --name "${ACR_NAME}" --query loginServer --output tsv
