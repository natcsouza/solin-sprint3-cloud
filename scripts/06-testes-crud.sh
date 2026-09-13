#!/usr/bin/env bash
# =====================================================================
# Etapa 6 - CRUD completo nas DUAS tabelas relacionadas, com evidencia
#
# O enunciado pede, para cada operacao, o SELECT feito DIRETAMENTE no
# banco logo depois. E pede que pelo menos DUAS linhas com conteudo
# significativo sejam inseridas e manipuladas em cada tabela.
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
    mysql -h "${DB_FQDN}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" --table -e "$1"
}

api_post() {   # $1 = rota, $2 = json
    curl -s -X POST "${API}/$1" -H "Content-Type: application/json" -d "$2"
}

id_de() {      # extrai o "id" do JSON de resposta
    grep -o '"id":[0-9]*' | head -1 | cut -d: -f2
}


titulo "ESTADO INICIAL - as duas linhas que vieram da carga do DDL"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL, NR_TELEFONE FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, DS_RACA, VL_PESO_KG, ID_TUTOR FROM TB_PET;"
pausa


# =====================================================================
# TABELA 1 - TB_TUTOR  (duas linhas inseridas e manipuladas)
# =====================================================================

titulo "1/9  CREATE - inserindo DOIS tutores pela API (POST /tutores)"

R1=$(api_post tutores '{"nome":"Camila Ferreira Duarte","email":"camila.duarte@email.com.br","telefone":"(11) 97455-2093"}')
echo "$R1"
T1=$(echo "$R1" | id_de)

R2=$(api_post tutores '{"nome":"Bruno Tavares Lemos","email":"bruno.lemos@email.com.br","telefone":"(11) 98204-7731"}')
echo "$R2"
T2=$(echo "$R2" | id_de)

echo ""
echo ">>> Tutores criados: ${T1} e ${T2}"
echo ">>> EVIDENCIA - SELECT direto no banco:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR IN (${T1}, ${T2});"
pausa


titulo "2/9  UPDATE - alterando os DOIS tutores (PUT /tutores/{id})"
curl -s -X PUT "${API}/tutores/${T1}" -H "Content-Type: application/json" \
     -d '{"nome":"Camila Ferreira Duarte Antunes","email":"camila.duarte@email.com.br","telefone":"(11) 96320-8874"}'
echo ""
curl -s -X PUT "${API}/tutores/${T2}" -H "Content-Type: application/json" \
     -d '{"nome":"Bruno Tavares Lemos Filho","email":"bruno.lemos@email.com.br","telefone":"(11) 97719-5540"}'
echo ""
echo ">>> EVIDENCIA - nome e telefone mudaram nas DUAS linhas:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR IN (${T1}, ${T2});"
pausa


titulo "3/9  READ - consultando a tabela inteira (GET /tutores)"
curl -s "${API}/tutores?size=20"
echo ""
echo ">>> EVIDENCIA - a mesma lista, direto no banco:"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL, NR_TELEFONE FROM TB_TUTOR;"
pausa


# =====================================================================
# TABELA 2 - TB_PET  (duas linhas, ligadas aos tutores criados acima)
# =====================================================================

titulo "4/9  CREATE - inserindo DOIS pets, um para cada tutor (POST /pets)"

P1=$(api_post pets "{\"nome\":\"Fiona\",\"raca\":\"Border Collie\",\"dataNascimento\":\"2022-05-30\",\"pesoKg\":17.2,\"sexo\":\"FEMEA\",\"tutorId\":${T1},\"especieId\":1}")
echo "$P1"
PET1=$(echo "$P1" | id_de)

P2=$(api_post pets "{\"nome\":\"Tobias\",\"raca\":\"Maine Coon\",\"dataNascimento\":\"2023-09-08\",\"pesoKg\":6.9,\"sexo\":\"MACHO\",\"tutorId\":${T2},\"especieId\":2}")
echo "$P2"
PET2=$(echo "$P2" | id_de)

echo ""
echo ">>> Pets criados: ${PET1} e ${PET2}"
echo ">>> EVIDENCIA - SELECT com JOIN, provando o relacionamento entre as tabelas:"
sql "SELECT p.ID_PET, p.NM_PET, p.DS_RACA, p.VL_PESO_KG, t.NM_TUTOR
       FROM TB_PET p
       JOIN TB_TUTOR t ON t.ID_TUTOR = p.ID_TUTOR
      WHERE p.ID_PET IN (${PET1}, ${PET2});"
pausa


titulo "5/9  UPDATE - alterando os DOIS pets (PUT /pets/{id})"
curl -s -X PUT "${API}/pets/${PET1}" -H "Content-Type: application/json" \
     -d "{\"nome\":\"Fiona\",\"raca\":\"Border Collie (pelagem longa)\",\"dataNascimento\":\"2022-05-30\",\"pesoKg\":18.6,\"sexo\":\"FEMEA\",\"tutorId\":${T1},\"especieId\":1}"
echo ""
curl -s -X PUT "${API}/pets/${PET2}" -H "Content-Type: application/json" \
     -d "{\"nome\":\"Tobias\",\"raca\":\"Maine Coon (pelagem tricolor)\",\"dataNascimento\":\"2023-09-08\",\"pesoKg\":7.4,\"sexo\":\"MACHO\",\"tutorId\":${T2},\"especieId\":2}"
echo ""
echo ">>> EVIDENCIA - peso e raca mudaram nas DUAS linhas:"
sql "SELECT ID_PET, NM_PET, DS_RACA, VL_PESO_KG, ID_TUTOR FROM TB_PET WHERE ID_PET IN (${PET1}, ${PET2});"
pausa


titulo "6/9  READ - listando todos os pets (GET /pets)"
curl -s "${API}/pets?size=20"
echo ""
echo ">>> EVIDENCIA - a tabela inteira no banco:"
sql "SELECT ID_PET, NM_PET, DS_RACA, VL_PESO_KG, ID_TUTOR FROM TB_PET;"
pausa


titulo "7/9  DELETE - removendo os DOIS pets (DELETE /pets/{id})"
curl -s -o /dev/null -w "pet ${PET1} -> HTTP %{http_code}\n" -X DELETE "${API}/pets/${PET1}"
curl -s -o /dev/null -w "pet ${PET2} -> HTTP %{http_code}\n" -X DELETE "${API}/pets/${PET2}"
echo ">>> EVIDENCIA - as duas linhas nao existem mais:"
sql "SELECT * FROM TB_PET WHERE ID_PET IN (${PET1}, ${PET2});"
echo ">>> E a tabela sem elas:"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"
pausa


titulo "8/9  DELETE - removendo os DOIS tutores (DELETE /tutores/{id})"
curl -s -o /dev/null -w "tutor ${T1} -> HTTP %{http_code}\n" -X DELETE "${API}/tutores/${T1}"
curl -s -o /dev/null -w "tutor ${T2} -> HTTP %{http_code}\n" -X DELETE "${API}/tutores/${T2}"
echo ">>> EVIDENCIA - as duas linhas nao existem mais:"
sql "SELECT * FROM TB_TUTOR WHERE ID_TUTOR IN (${T1}, ${T2});"
pausa


titulo "9/9  ESTADO FINAL das duas tabelas"
sql "SELECT ID_TUTOR, NM_TUTOR, DS_EMAIL FROM TB_TUTOR;"
sql "SELECT ID_PET, NM_PET, ID_TUTOR FROM TB_PET;"

titulo "CRUD COMPLETO demonstrado - 2 linhas inseridas, alteradas,
 consultadas e excluidas em CADA uma das tabelas relacionadas"
