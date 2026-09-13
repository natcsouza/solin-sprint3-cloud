#!/usr/bin/env bash
# =====================================================================
# Etapa 5 - ACI da APLICACAO
#
# Local, os dois containers se achavam pelo nome do servico dentro de
# uma rede do Docker. Em nuvem, cada ACI e um grupo isolado, entao o app
# encontra o banco pelo FQDN publico do ACI do banco - descoberto aqui
# em tempo de execucao, nunca chumbado no codigo.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

: "${DB_PASSWORD:?Exporte DB_PASSWORD antes de rodar}"

ACR_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)
ACR_USER=$(az acr credential show --name "${ACR_NAME}" --query username --output tsv)
ACR_PASS=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" --output tsv)

DB_FQDN=$(az container show \
    --resource-group "${RG}" \
    --name "${ACI_DB}" \
    --query ipAddress.fqdn \
    --output tsv)

echo ">>> Banco localizado em ${DB_FQDN}"

echo ">>> Criando o ACI da aplicacao: ${ACI_APP}"
az container create \
    --resource-group "${RG}" \
    --name "${ACI_APP}" \
    --image "${ACR_SERVER}/${IMG_APP}" \
    --registry-login-server "${ACR_SERVER}" \
    --registry-username "${ACR_USER}" \
    --registry-password "${ACR_PASS}" \
    --cpu 1 \
    --memory 1.5 \
    --os-type Linux \
    --ip-address Public \
    --ports 8080 \
    --dns-name-label "${DNS_APP}" \
    --environment-variables \
        DB_HOST="${DB_FQDN}" \
        DB_PORT="${DB_PORT}" \
        DB_NAME="${DB_NAME}" \
        DB_USER="${DB_USER}" \
    --secure-environment-variables \
        DB_PASSWORD="${DB_PASSWORD}" \
    --restart-policy OnFailure

APP_FQDN=$(az container show \
    --resource-group "${RG}" \
    --name "${ACI_APP}" \
    --query ipAddress.fqdn \
    --output tsv)

echo ""
echo ">>> Aguardando a aplicacao subir..."
for i in $(seq 1 30); do
    if az container logs --resource-group "${RG}" --name "${ACI_APP}" 2>/dev/null \
        | grep -q "Started SolinApiApplication"; then
        echo "    aplicacao no ar."
        break
    fi
    echo "    ainda subindo... (${i}/30)"
    sleep 10
done

echo ""
echo "====================================================================="
echo " SOLIN publicado:"
echo ""
echo "   API .........: http://${APP_FQDN}:8080/solin/api/tutores"
echo "   Swagger .....: http://${APP_FQDN}:8080/solin/swagger-ui.html"
echo "   Banco .......: ${DB_FQDN}:3306"
echo "====================================================================="

echo ""
echo ">>> Confirmando que o app NAO roda como root:"
az container exec --resource-group "${RG}" --name "${ACI_APP}" --exec-command "whoami" || true
