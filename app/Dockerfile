# =====================================================================
# SOLIN API - imagem da aplicacao
#
# Build em dois estagios: o Maven so existe no primeiro. A imagem final
# carrega apenas o JRE e o .jar, ficando bem menor e com menos
# superficie de ataque.
# =====================================================================

# ---------- Estagio 1: build ----------
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /build

# pom.xml primeiro: enquanto as dependencias nao mudam, esta camada e
# reaproveitada do cache e o build seguinte nao baixa nada de novo.
COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests


# ---------- Estagio 2: runtime ----------
FROM eclipse-temurin:17-jre-alpine

# O container do App NAO pode rodar como root (regra do enunciado).
RUN addgroup -S solin && adduser -S solinuser -G solin

WORKDIR /app

COPY --from=build /build/target/solin-api.jar app.jar
RUN chown -R solinuser:solin /app

USER solinuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
