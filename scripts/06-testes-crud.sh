#!/usr/bin/env bash
# =====================================================================
# Etapa 6 - CRUD completo nas DUAS tabelas relacionadas, com evidencia
#
# O enunciado pede, para cada operacao, o SELECT feito DIRETAMENTE no
# banco logo depois. E o que este script faz: executa a operacao pela
# API e, na sequencia, consulta a tabela no MySQL.
#
# Par escolhido: TB_TUTOR 1 --- N TB_PET
# (o core da jornada: sem tutor e sem pet nao existe cuidado continuo)
#
# O script pausa entre as etapas - basta ir narrando e apertando ENTER.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

: "${DB_PASSWORD:?Exporte DB_PASSWORD antes de rodar}"

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

APP_FQDN=$(az container show -g "${RG}" -n "${ACI_APP}" --query ipAddress.fqdn -o tsv)
DB_FQDN=$(az container show  -g "${RG}" -n "${ACI_DB}"  --query ipAddress.fqdn -o tsv)
API="http://${APP_FQDN}:8080/solin/api"

titulo() {
    echo ""
    echo "====================================================================="
    echo " $1"
    echo "====================================================================="
}

pausa() {
    echo ""
    read -r -p "--- ENTER para continuar ---" _
}

sql() {
    mysql -h "${DB_FQDN}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
          --table -e "$1"
}


titulo "ESTADO INICIAL - o que veio da carga do DDL"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL, NR_TELEFONE FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, DS_RACA, VL_PESO_KG, ID_TUTOR FROM TB_PET;"
pausa


# =====================================================================
# TABELA 1 - TB_TUTOR
# =====================================================================

titulo "1/8  CREATE - inserindo um tutor pela API (POST /tutores)"
curl -s -X POST "${API}/tutores" \
     -H "Content-Type: application/json" \
     -d @"${RAIZ}/json/tutor-post.json" | tee /tmp/tutor.json
echo ""
TUTOR_ID=$(grep -o '"id":[0-9]*' /tmp/tutor.json | head -1 | cut -d: -f2)
echo ">>> Tutor criado com id ${TUTOR_ID}"
echo ">>> EVIDENCIA - SELECT direto no banco:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR = ${TUTOR_ID};"
pausa


titulo "2/8  UPDATE - alterando o tutor (PUT /tutores/${TUTOR_ID})"
curl -s -X PUT "${API}/tutores/${TUTOR_ID}" \
     -H "Content-Type: application/json" \
     -d @"${RAIZ}/json/tutor-put.json"
echo ""
echo ">>> EVIDENCIA - SELECT direto no banco (nome e telefone mudaram):"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR = ${TUTOR_ID};"
pausa


titulo "3/8  READ - consultando o tutor (GET /tutores/${TUTOR_ID})"
curl -s "${API}/tutores/${TUTOR_ID}"
echo ""
echo ">>> EVIDENCIA - a mesma linha, direto no banco:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR = ${TUTOR_ID};"
pausa


# =====================================================================
# TABELA 2 - TB_PET (relacionada ao tutor recem-criado)
# =====================================================================

titulo "4/8  CREATE - inserindo um pet para esse tutor (POST /pets)"
sed "s/\"tutorId\": *[0-9]*/\"tutorId\": ${TUTOR_ID}/" \
    "${RAIZ}/json/pet-post.json" > /tmp/pet-post.json
cat /tmp/pet-post.json
curl -s -X POST "${API}/pets" \
     -H "Content-Type: application/json" \
     -d @/tmp/pet-post.json | tee /tmp/pet.json
echo ""
PET_ID=$(grep -o '"id":[0-9]*' /tmp/pet.json | head -1 | cut -d: -f2)
echo ">>> Pet criado com id ${PET_ID}"
echo ">>> EVIDENCIA - SELECT com JOIN, mostrando o relacionamento:"
sql "SELECT p.ID_PET, p.NM_PET, p.DS_RACA, p.VL_PESO_KG, t.NM_TUTOR
       FROM TB_PET p
       JOIN TB_TUTOR t ON t.ID_TUTOR = p.ID_TUTOR
      WHERE p.ID_PET = ${PET_ID};"
pausa


titulo "5/8  UPDATE - alterando o pet (PUT /pets/${PET_ID})"
sed "s/\"tutorId\": *[0-9]*/\"tutorId\": ${TUTOR_ID}/" \
    "${RAIZ}/json/pet-put.json" > /tmp/pet-put.json
curl -s -X PUT "${API}/pets/${PET_ID}" \
     -H "Content-Type: application/json" \
     -d @/tmp/pet-put.json
echo ""
echo ">>> EVIDENCIA - SELECT direto no banco (peso e raca mudaram):"
sql "SELECT * FROM TB_PET WHERE ID_PET = ${PET_ID};"
pausa


titulo "6/8  READ - listando todos os pets (GET /pets)"
curl -s "${API}/pets?size=20"
echo ""
echo ">>> EVIDENCIA - a tabela inteira no banco:"
sql "SELECT ID_PET, NM_PET, DS_RACA, VL_PESO_KG, ID_TUTOR FROM TB_PET;"
pausa


titulo "7/8  DELETE - removendo o pet (DELETE /pets/${PET_ID})"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
     -X DELETE "${API}/pets/${PET_ID}"
echo ">>> EVIDENCIA - SELECT mostra que a linha nao existe mais:"
sql "SELECT * FROM TB_PET WHERE ID_PET = ${PET_ID};"
echo ">>> E a tabela sem ela:"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"
pausa


titulo "8/8  DELETE - removendo o tutor (DELETE /tutores/${TUTOR_ID})"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
     -X DELETE "${API}/tutores/${TUTOR_ID}"
echo ">>> EVIDENCIA - SELECT mostra que a linha nao existe mais:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR = ${TUTOR_ID};"
echo ">>> Estado final das duas tabelas:"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"


titulo "FIM - CRUD completo demonstrado nas duas tabelas relacionadas"
