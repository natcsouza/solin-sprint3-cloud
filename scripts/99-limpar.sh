#!/usr/bin/env bash
# =====================================================================
# Etapa final - LIMPEZA
#
# Rode isto assim que terminar a gravacao. O ACI cobra POR SEGUNDO:
# dois containers de 1 vCPU + 1,5 GB custam cerca de 2,70 dolares por
# dia se ficarem ligados. O credito do Azure for Students e de 100.
#
# Deletar o grupo apaga tudo que esta dentro dele de uma vez, porque
# recursos de um mesmo grupo compartilham o ciclo de vida.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

echo ">>> Recursos que serao apagados junto com o grupo ${RG}:"
az resource list --resource-group "${RG}" \
    --query "[].{Nome:name, Tipo:type}" --output table

echo ""
read -r -p "Confirma apagar o grupo ${RG} inteiro? (digite SIM) " RESP
if [ "${RESP}" != "SIM" ]; then
    echo "Cancelado. Nada foi apagado."
    exit 0
fi

az group delete --name "${RG}" --yes

echo ""
echo ">>> Grupos restantes na assinatura:"
az group list --output table

echo ""
echo ">>> Limpeza concluida. Tire o print desta tela para o PDF."
