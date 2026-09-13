#!/usr/bin/env bash
# =====================================================================
# Etapa 7 - Prova de que os dados PERSISTEM
#
# Reinicia o container do banco e mostra que os dados continuam la.
# Isso so acontece porque /var/lib/mysql esta montado no File Share da
# Conta de Armazenamento: o container e descartavel, o dado nao.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

: "${DB_PASSWORD:?Exporte DB_PASSWORD antes de rodar}"

DB_FQDN=$(az container show -g "${RG}" -n "${ACI_DB}" --query ipAddress.fqdn -o tsv)

sql() {
    mysql -h "${DB_FQDN}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" --table -e "$1"
}

echo ">>> ANTES do restart:"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"

echo ""
echo ">>> Reiniciando o container do banco..."
az container restart --resource-group "${RG}" --name "${ACI_DB}"

echo ">>> Aguardando o banco voltar..."
for i in $(seq 1 30); do
    if mysql -h "${DB_FQDN}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
             -e "SELECT 1;" >/dev/null 2>&1; then
        echo "    banco no ar de novo."
        break
    fi
    echo "    aguardando... (${i}/30)"
    sleep 10
done

echo ""
echo ">>> DEPOIS do restart - os mesmos dados:"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"

echo ""
echo ">>> Persistencia comprovada: o container foi reiniciado e os dados"
echo "    continuam no File Share da Conta de Armazenamento."
