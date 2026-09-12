-- =====================================================================
-- SOLIN - Monitoramento preventivo da saude do pet
-- Challenge 2026 CLYVO VET  |  Sprint 3
-- DevOps Tools & Cloud Computing - FIAP 2TDSR
--
-- Banco...: MySQL 8.0 (container em nuvem - Azure Container Instances)
-- Charset.: utf8mb4 (acentuacao correta em nomes e observacoes)
--
-- Este arquivo e a UNICA fonte do schema. A aplicacao sobe com
-- spring.jpa.hibernate.ddl-auto=validate: o Hibernate nao cria nem
-- altera nada, apenas confere se o schema bate com as entidades.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS solin
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE solin;


-- =====================================================================
-- TB_TUTOR - o responsavel pelo pet
--
-- E a porta de entrada da jornada de cuidado: todo pet pertence a um
-- tutor, e e para ele que os alertas sao enviados. Faz parte do CORE
-- da solucao (nao e tabela de apoio).
-- =====================================================================
CREATE TABLE TB_TUTOR (

    ID_TUTOR     BIGINT        NOT NULL AUTO_INCREMENT  COMMENT 'Identificador do tutor',
    NM_TUTOR     VARCHAR(120)  NOT NULL                 COMMENT 'Nome completo do responsavel',
    DS_EMAIL     VARCHAR(150)  NOT NULL                 COMMENT 'E-mail de contato (canal dos alertas)',
    NR_TELEFONE  VARCHAR(20)   NULL                     COMMENT 'Telefone/WhatsApp no formato (11) 91234-5678',
    DT_CADASTRO  DATE          NOT NULL                 COMMENT 'Data de entrada do tutor na plataforma',

    CONSTRAINT PK_TUTOR       PRIMARY KEY (ID_TUTOR),
    CONSTRAINT UK_TUTOR_EMAIL UNIQUE (DS_EMAIL)

) ENGINE = InnoDB
  COMMENT = 'Responsaveis pelos pets monitorados pelo SOLIN';


-- =====================================================================
-- TB_ESPECIE - parametro clinico por especie
--
-- Guarda o intervalo maximo saudavel sem urinar, que e o limiar usado
-- pelas regras de alerta. Cao adulto ~8h, gato ~24h, coelho ~12h.
-- =====================================================================
CREATE TABLE TB_ESPECIE (

    ID_ESPECIE          BIGINT       NOT NULL AUTO_INCREMENT COMMENT 'Identificador da especie',
    NM_ESPECIE          VARCHAR(50)  NOT NULL                COMMENT 'Nome da especie',
    QT_HORAS_MAX_URINA  INT          NOT NULL                COMMENT 'Horas sem urinar consideradas normais para a especie',

    CONSTRAINT PK_ESPECIE       PRIMARY KEY (ID_ESPECIE),
    CONSTRAINT UK_ESPECIE_NOME  UNIQUE (NM_ESPECIE)

) ENGINE = InnoDB
  COMMENT = 'Parametros clinicos por especie, usados pelas regras de alerta';


-- =====================================================================
-- TB_PET - o animal monitorado
--
-- Nucleo da solucao. Relaciona-se com TB_TUTOR (quem cuida) e com
-- TB_ESPECIE (qual o limiar clinico). E sobre este par TUTOR -> PET
-- que o CRUD completo e demonstrado.
-- =====================================================================
CREATE TABLE TB_PET (

    ID_PET          BIGINT       NOT NULL AUTO_INCREMENT COMMENT 'Identificador do pet',
    NM_PET          VARCHAR(80)  NOT NULL                COMMENT 'Nome do animal',
    DS_RACA         VARCHAR(80)  NULL                    COMMENT 'Raca (usada na personalizacao por predisposicao)',
    DT_NASCIMENTO   DATE         NULL                    COMMENT 'Data de nascimento, define a fase de vida',
    VL_PESO_KG      DOUBLE       NULL                    COMMENT 'Peso atual em quilos',
    TP_SEXO         VARCHAR(10)  NULL                    COMMENT 'MACHO ou FEMEA',
    ID_TUTOR        BIGINT       NOT NULL                COMMENT 'FK: responsavel pelo pet',
    ID_ESPECIE      BIGINT       NOT NULL                COMMENT 'FK: especie do pet',

    CONSTRAINT PK_PET         PRIMARY KEY (ID_PET),
    CONSTRAINT FK_PET_TUTOR   FOREIGN KEY (ID_TUTOR)   REFERENCES TB_TUTOR (ID_TUTOR)   ON DELETE CASCADE,
    CONSTRAINT FK_PET_ESPECIE FOREIGN KEY (ID_ESPECIE) REFERENCES TB_ESPECIE (ID_ESPECIE)

) ENGINE = InnoDB
  COMMENT = 'Pets monitorados - entidade central da jornada de cuidado';


-- =====================================================================
-- TB_EVENTO - o que aconteceu com o pet
--
-- Cada registro e um fato da rotina (urinou, comeu, tomou medicamento).
-- E o historico longitudinal que a CLYVO VET quer construir.
-- =====================================================================
CREATE TABLE TB_EVENTO (

    ID_EVENTO      BIGINT        NOT NULL AUTO_INCREMENT COMMENT 'Identificador do evento',
    TP_EVENTO      VARCHAR(20)   NOT NULL                COMMENT 'URINOU, NAO_URINOU, DEFECOU, COMEU, BEBEU_AGUA, MEDICAMENTO',
    DH_EVENTO      DATETIME(6)   NOT NULL                COMMENT 'Data e hora em que o evento ocorreu',
    TP_ORIGEM      VARCHAR(15)   NOT NULL                COMMENT 'MANUAL (tutor registrou) ou SENSOR_IOT',
    DS_OBSERVACAO  VARCHAR(255)  NULL                    COMMENT 'Observacao livre do tutor',
    ID_PET         BIGINT        NOT NULL                COMMENT 'FK: pet do evento',

    CONSTRAINT PK_EVENTO     PRIMARY KEY (ID_EVENTO),
    CONSTRAINT FK_EVENTO_PET FOREIGN KEY (ID_PET) REFERENCES TB_PET (ID_PET) ON DELETE CASCADE

) ENGINE = InnoDB
  COMMENT = 'Historico longitudinal de eventos da rotina do pet';

-- Acelera a consulta "ultimo evento de um tipo para este pet", que e a
-- pergunta feita pelas regras de alerta a cada verificacao.
CREATE INDEX IX_EVENTO_PET_DH ON TB_EVENTO (ID_PET, DH_EVENTO);


-- =====================================================================
-- TB_ALERTA - o que a solucao devolve ao tutor
--
-- Resultado das regras aplicadas sobre os eventos. E aqui que a
-- continuidade do cuidado deixa de ser reativa e vira proativa.
-- =====================================================================
CREATE TABLE TB_ALERTA (

    ID_ALERTA     BIGINT        NOT NULL AUTO_INCREMENT COMMENT 'Identificador do alerta',
    TP_NIVEL      VARCHAR(10)   NOT NULL                COMMENT 'AMARELO (atencao) ou VERMELHO (procurar clinica)',
    DS_MENSAGEM   VARCHAR(255)  NOT NULL                COMMENT 'Mensagem enviada ao tutor',
    DH_GERADO     DATETIME(6)   NOT NULL                COMMENT 'Momento em que o alerta foi disparado',
    ST_RESOLVIDO  BIT(1)        NOT NULL                COMMENT '0 = em aberto, 1 = resolvido',
    ID_PET        BIGINT        NOT NULL                COMMENT 'FK: pet do alerta',

    CONSTRAINT PK_ALERTA     PRIMARY KEY (ID_ALERTA),
    CONSTRAINT FK_ALERTA_PET FOREIGN KEY (ID_PET) REFERENCES TB_PET (ID_PET) ON DELETE CASCADE

) ENGINE = InnoDB
  COMMENT = 'Alertas preventivos gerados para o tutor';


-- =====================================================================
-- CARGA INICIAL
-- Dados com conteudo significativo, para o SELECT do video ja mostrar
-- a solucao povoada antes mesmo do primeiro POST.
-- =====================================================================

-- Parametros clinicos
INSERT INTO TB_ESPECIE (NM_ESPECIE, QT_HORAS_MAX_URINA) VALUES
    ('Cao',    8),
    ('Gato',  24),
    ('Coelho', 12);

-- Tutores (tabela 1 do CRUD)
INSERT INTO TB_TUTOR (NM_TUTOR, DS_EMAIL, NR_TELEFONE, DT_CADASTRO) VALUES
    ('Mariana Alves Rocha',   'mariana.rocha@email.com.br', '(11) 98812-4471', '2026-02-10'),
    ('Rafael Nogueira Pinto', 'rafael.pinto@email.com.br',  '(11) 99640-3328', '2026-03-05');

-- Pets (tabela 2 do CRUD, relacionada a TB_TUTOR)
INSERT INTO TB_PET (NM_PET, DS_RACA, DT_NASCIMENTO, VL_PESO_KG, TP_SEXO, ID_TUTOR, ID_ESPECIE) VALUES
    ('Amora', 'Golden Retriever', '2021-07-14', 28.4, 'FEMEA', 1, 1),
    ('Nino',  'Siames',           '2023-01-22',  4.6, 'MACHO', 2, 2);

-- Eventos da rotina, alimentando o historico
INSERT INTO TB_EVENTO (TP_EVENTO, DH_EVENTO, TP_ORIGEM, DS_OBSERVACAO, ID_PET) VALUES
    ('URINOU',      '2026-09-11 07:20:00.000000', 'SENSOR_IOT', 'Registro automatico do tapete sensor',     1),
    ('MEDICAMENTO', '2026-09-11 20:00:00.000000', 'MANUAL',     'Antipulgas mensal aplicado pela tutora',   1),
    ('COMEU',       '2026-09-11 18:45:00.000000', 'MANUAL',     'Racao umida, comeu a porcao inteira',      2);

-- Alerta preventivo em aberto
INSERT INTO TB_ALERTA (TP_NIVEL, DS_MENSAGEM, DH_GERADO, ST_RESOLVIDO, ID_PET) VALUES
    ('AMARELO', 'Amora esta ha 9 horas sem urinar. Observe e ofereca agua.', '2026-09-11 16:30:00.000000', 0, 1);
