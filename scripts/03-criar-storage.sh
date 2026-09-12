#!/usr/bin/env bash
# =====================================================================
# Etapa 3 - Conta de Armazenamento + File Share
#
# Local, a persistencia do banco era um volume nomeado do Docker.
# Em nuvem, o equivalente e um File Share da Conta de Armazenamento,
# montado no diretorio de dados do MySQL. Se o container do banco for
# reiniciado ou recriado, os dados continuam la.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

echo ">>> Criando a conta de armazenamento ${STORAGE_NAME}"
az storage account create \
    --resource-group "${RG}" \
    --name "${STORAGE_NAME}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2

echo ">>> Obtendo a chave da conta"
STORAGE_KEY=$(az storage account keys list \
    --resource-group "${RG}" \
    --account-name "${STORAGE_NAME}" \
    --query "[0].value" \
    --output tsv)

echo ">>> Criando o file share ${SHARE_NAME}"
az storage share create \
    --name "${SHARE_NAME}" \
    --account-name "${STORAGE_NAME}" \
    --account-key "${STORAGE_KEY}" \
    --quota 5

echo ""
echo ">>> Compartilhamentos existentes:"
az storage share list \
    --account-name "${STORAGE_NAME}" \
    --account-key "${STORAGE_KEY}" \
    --output table
