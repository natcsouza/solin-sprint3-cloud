#!/usr/bin/env bash
# =====================================================================
# Etapa 2 - Build das imagens e envio para o ACR
#
# Dois caminhos, o script escolhe sozinho:
#
#   a) Maquina COM Docker  -> docker build + docker tag + docker push
#   b) Azure Cloud Shell   -> az acr build (o build roda dentro do ACR)
#
# O Cloud Shell nao tem daemon do Docker, entao "docker build" nao
# existe la. O "az acr build" envia o contexto e o proprio registro
# constroi a imagem a partir do MESMO Dockerfile - o resultado no ACR
# e identico.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
ACR_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then

    echo ">>> Docker encontrado - build local e push para o ACR"

    az acr login --name "${ACR_NAME}"

    echo ">>> Build da imagem do BANCO"
    docker build -t "${IMG_DB}" "${RAIZ}/db"

    echo ">>> Build da imagem do APP"
    docker build -t "${IMG_APP}" "${RAIZ}/app"

    echo ">>> Marcando as imagens com o endereco do ACR"
    docker tag "${IMG_DB}"  "${ACR_SERVER}/${IMG_DB}"
    docker tag "${IMG_APP}" "${ACR_SERVER}/${IMG_APP}"

    echo ">>> Enviando as imagens"
    docker push "${ACR_SERVER}/${IMG_DB}"
    docker push "${ACR_SERVER}/${IMG_APP}"

else

    echo ">>> Sem daemon do Docker (Cloud Shell) - build dentro do proprio ACR"

    echo ">>> Build da imagem do BANCO"
    az acr build \
        --registry "${ACR_NAME}" \
        --image "${IMG_DB}" \
        --file Dockerfile \
        "${RAIZ}/db"

    echo ">>> Build da imagem do APP (compila o Maven, leva alguns minutos)"
    az acr build \
        --registry "${ACR_NAME}" \
        --image "${IMG_APP}" \
        --file Dockerfile \
        "${RAIZ}/app"

fi

echo ""
echo ">>> Imagens registradas no ACR:"
az acr repository list --name "${ACR_NAME}" --output table

echo ""
echo ">>> Tags de cada repositorio:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${RM}-${PROJETO}-db"  --output table
az acr repository show-tags --name "${ACR_NAME}" --repository "${RM}-${PROJETO}-app" --output table
