#!/usr/bin/env bash
# =====================================================================
# Etapa 2 - Build das imagens e envio para o ACR
#
# O build precisa de um daemon do Docker, e o Azure Cloud Shell nao tem.
# O "az acr build" tambem nao resolve: ACR Tasks e bloqueado em
# assinaturas Azure for Students.
#
# A saida e a mesma ensinada em aula: uma VM Linux com Docker. O script
# a cria (se ainda nao existir), instala o Docker, e roda ali dentro o
# docker build / docker tag / docker push - tudo comandado por Azure CLI,
# sem precisar de SSH.
#
# A VM e uma FERRAMENTA DE BUILD. Ela nao hospeda nada da solucao e e
# excluida no final, junto com o grupo de recursos.
# =====================================================================
set -e

source "$(dirname "$0")/00-variaveis.sh"

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

VM_BUILD="vm-${RM}-build"
VM_LOCATION="canadacentral"   # a serie B nao esta disponivel em eastus2
VM_SIZE="Standard_B2als_v2"

ACR_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)
ACR_USER=$(az acr credential show --name "${ACR_NAME}" --query username --output tsv)
ACR_PASS=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" --output tsv)

# ---------------------------------------------------------------------
# Caminho curto: se a maquina local ja tiver Docker, usa ele
# ---------------------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then

    echo ">>> Docker local encontrado - build aqui mesmo"
    az acr login --name "${ACR_NAME}"

    docker build -t "${IMG_DB}"  "${RAIZ}/db"
    docker build -t "${IMG_APP}" "${RAIZ}/app"

    docker tag "${IMG_DB}"  "${ACR_SERVER}/${IMG_DB}"
    docker tag "${IMG_APP}" "${ACR_SERVER}/${IMG_APP}"

    docker push "${ACR_SERVER}/${IMG_DB}"
    docker push "${ACR_SERVER}/${IMG_APP}"

else

    echo ">>> Sem Docker local (Cloud Shell) - usando a VM de build"

    # 1) VM ------------------------------------------------------------
    if az vm show -g "${RG}" -n "${VM_BUILD}" >/dev/null 2>&1; then
        echo ">>> VM ${VM_BUILD} ja existe"
    else
        echo ">>> Criando a VM de build ${VM_BUILD} (leva ~2 min)"
        az vm create \
            --resource-group "${RG}" \
            --name "${VM_BUILD}" \
            --image Ubuntu2404 \
            --size "${VM_SIZE}" \
            --location "${VM_LOCATION}" \
            --admin-username admlnx \
            --generate-ssh-keys \
            --nsg-rule NONE \
            --output table
    fi

    # 2) Docker na VM --------------------------------------------------
    echo ">>> Garantindo o Docker na VM"
    az vm run-command invoke \
        --resource-group "${RG}" \
        --name "${VM_BUILD}" \
        --command-id RunShellScript \
        --scripts "command -v docker >/dev/null 2>&1 || { export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq docker.io >/dev/null 2>&1; systemctl enable --now docker; }; docker --version" \
        --query "value[0].message" -o tsv

    # 3) Build e push na VM -------------------------------------------
    echo ">>> Build e push das imagens (leva ~5 min)"
    az vm run-command invoke \
        --resource-group "${RG}" \
        --name "${VM_BUILD}" \
        --command-id RunShellScript \
        --scripts "
            set -e
            W=\$(mktemp -d) && cd \$W
            git clone -q https://github.com/natcsouza/solin-sprint3-cloud.git
            cd solin-sprint3-cloud
            echo '${ACR_PASS}' | docker login ${ACR_SERVER} -u '${ACR_USER}' --password-stdin
            docker build -q -t ${IMG_DB}  ./db
            docker build -q -t ${IMG_APP} ./app
            docker tag ${IMG_DB}  ${ACR_SERVER}/${IMG_DB}
            docker tag ${IMG_APP} ${ACR_SERVER}/${IMG_APP}
            docker push ${ACR_SERVER}/${IMG_DB}  | tail -n 1
            docker push ${ACR_SERVER}/${IMG_APP} | tail -n 1
        " \
        --query "value[0].message" -o tsv

fi

echo ""
echo ">>> Imagens registradas no ACR:"
az acr repository list --name "${ACR_NAME}" --output table

echo ""
echo ">>> Tags de cada repositorio:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${RM}-${PROJETO}-db"  --output table
az acr repository show-tags --name "${ACR_NAME}" --repository "${RM}-${PROJETO}-app" --output table
