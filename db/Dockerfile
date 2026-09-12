# =====================================================================
# SOLIN - imagem do banco de dados
#
# MySQL 8.0 com o DDL embutido. Tudo que esta em
# /docker-entrypoint-initdb.d roda sozinho na PRIMEIRA inicializacao,
# quando o diretorio de dados ainda esta vazio.
#
# Como o volume e persistente (Azure File Share), nas execucoes
# seguintes o script nao roda de novo e os dados sobrevivem.
# =====================================================================
FROM mysql:8.0

COPY init/01-ddl.sql /docker-entrypoint-initdb.d/01-ddl.sql

EXPOSE 3306
