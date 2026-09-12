#!/usr/bin/env bash
# =====================================================================
# SOLIN - Sprint 3 - variaveis usadas por todos os scripts
#
# Uso:  source scripts/00-variaveis.sh
#
# ATENCAO: as senhas NAO ficam aqui. Exporte antes de rodar os scripts:
#   export DB_ROOT_PASSWORD='...'
#   export DB_PASSWORD='...'
# =====================================================================

# --- Identificacao do grupo -------------------------------------------
export RM="564099"                      # RM da representante do grupo
export PROJETO="solin"

# --- Recursos Azure ---------------------------------------------------
export RG="rg-${RM}-${PROJETO}"

# A policy "Allowed resource deployment regions" desta assinatura libera
# apenas: canadacentral, southcentralus, chilecentral, eastus2,
# northcentralus. Se a regiao recusar por capacidade, troque por outra
# desta lista - e so tentativa, conforme orientacao da disciplina.
export LOCATION="eastus2"

export ACR_NAME="acr${RM}${PROJETO}"        # so letras minusculas e numeros
export STORAGE_NAME="st${RM}${PROJETO}"     # so letras minusculas e numeros
export SHARE_NAME="${PROJETO}-mysql"

export ACI_DB="aci-${RM}-${PROJETO}-db"
export ACI_APP="aci-${RM}-${PROJETO}-app"

export DNS_DB="${RM}-${PROJETO}-db"
export DNS_APP="${RM}-${PROJETO}-app"

# --- Imagens (o RM da representante e prefixo, como pede o enunciado) --
export IMG_DB="${RM}-${PROJETO}-db:1.0"
export IMG_APP="${RM}-${PROJETO}-app:1.0"

# --- Banco ------------------------------------------------------------
export DB_NAME="solin"
export DB_USER="solin"
export DB_PORT="3306"

echo "Variaveis carregadas | RM ${RM} | grupo ${RG} | regiao ${LOCATION}"
