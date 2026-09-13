#!/usr/bin/env bash
# =====================================================================
# Etapa 4 - ACI do BANCO de dados
#
# O volume do MySQL aponta para o file share da conta de armazenamento:
# e ele que garante a persistencia exigida pelo enunciado.
#
# As senhas viajam como --secure-environment-variables. A diferenca para
# --environment-variables e que as seguras NAO aparecem no portal nem em
# "az container show" - e o que evita a penalidade de dado sensivel
# exposto.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

: "${DB_ROOT_PASSWORD:?Exporte DB_ROOT_PASSWORD antes de rodar}"
: "${DB_PASSWORD:?Exporte DB_PASSWORD antes de rodar}"

ACR_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)
ACR_USER=$(az acr credential show --name "${ACR_NAME}" --query username --output tsv)
ACR_PASS=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" --output tsv)

STORAGE_KEY=$(az storage account keys list \
    --resource-group "${RG}" \
    --account-name "${STORAGE_NAME}" \
    --query "[0].value" \
    --output tsv)

echo ">>> Criando o ACI do banco: ${ACI_DB}"
az container create \
    --resource-group "${RG}" \
    --name "${ACI_DB}" \
    --image "${ACR_SERVER}/${IMG_DB}" \
    --registry-login-server "${ACR_SERVER}" \
    --registry-username "${ACR_USER}" \
    --registry-password "${ACR_PASS}" \
    --cpu 1 \
    --memory 1.5 \
    --os-type Linux \
    --ip-address Public \
    --ports 3306 \
    --dns-name-label "${DNS_DB}" \
    --environment-variables \
        MYSQL_DATABASE="${DB_NAME}" \
        MYSQL_USER="${DB_USER}" \
    --secure-environment-variables \
        MYSQL_ROOT_PASSWORD="${DB_ROOT_PASSWORD}" \
        MYSQL_PASSWORD="${DB_PASSWORD}" \
    --azure-file-volume-account-name "${STORAGE_NAME}" \
    --azure-file-volume-account-key "${STORAGE_KEY}" \
    --azure-file-volume-share-name "${SHARE_NAME}" \
    --azure-file-volume-mount-path /var/lib/mysql \
    --restart-policy OnFailure

echo ""
echo ">>> Estado do container do banco:"
az container show \
    --resource-group "${RG}" \
    --name "${ACI_DB}" \
    --query "{nome:name, estado:instanceView.state, fqdn:ipAddress.fqdn, ip:ipAddress.ip}" \
    --output table

echo ""
echo ">>> Aguardando o MySQL terminar a inicializacao e rodar o DDL..."
for i in $(seq 1 30); do
    if az container logs --resource-group "${RG}" --name "${ACI_DB}" 2>/dev/null \
        | grep -q "ready for connections"; then
        echo "    banco pronto."
        break
    fi
    echo "    ainda subindo... (${i}/30)"
    sleep 10
done

echo ""
echo ">>> Ultimas linhas do log do banco:"
az container logs --resource-group "${RG}" --name "${ACI_DB}" | tail -n 15
