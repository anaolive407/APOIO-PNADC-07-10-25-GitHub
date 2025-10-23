# ANÁLISES TESE ANA - 2025 ------------------------------------------------

#+ setup, echo=TRUE, eval=FALSE, include=TRUE

## PREPARANDO O AMBIENTE R -------------------------------------------------
 
#Limpando Objetos
rm(list = ls(all=TRUE))

#Definindo opção de codificação
aviso <- getOption("warn")
options(warn=-1)
options(encoding= "latin1")
options(warn=aviso)
rm(aviso)

#Opção exibição números sem exponencial
aviso <- getOption("warn")
options(warn=-1)
options(scipen = 999)
options(warn=aviso)
rm(aviso)

#Definindo opção de repositóriorio para instalação pacotes necessários
aviso <- getOption("warn")
options(warn=-1)
options(repos=structure(c(cran="https://cran.r-project.org/")))
rm(aviso)

#Abrindo Pacotes
library(tidyverse)
library(survey)
library(srvyr)
library(PNADcIBGE)
library(dplyr)

## CARREGANDO AS BASES DE DADOS --------------------------------------------

# Definindo o diretório onde estão os arquivos e onde serão salvos os filtrados
setwd("C:/Users/Ana Oliveira/Desktop/pnadc 2023") #Altere para o nome do seu diretório
dir_filtrados <- "filtrados2"
if (!dir.exists(dir_filtrados)) {
  dir.create(dir_filtrados)
}

# Vetor com as variáveis de interesse
variaveis_selecionadas <- c(
  "Ano", "Trimestre", "UF", "UPA", "Estrato", "V1008", "V1014", "V1016", 
  "V4017", "V1023", "V1028", "V2001", "V2003", "V2005", "V2007", "V2008", 
  "V20081", "V20082", "V2009", "V2010", "VD3005", "V4001", "V4009", "V4010", 
  "V4012", "V4013", "V4025", "V4026", "V4029", "V4032", "V4039", "V4041", "V4043", 
  "V4044", "V4048", "V40501", "V405012", "V4056", "V4057", "V4039C", "V4040", 
  "VD2003", "VD2004", "VD3004", "VD3005", "VD4009", "VD4002", "VD4008", "VD4011",
  "VD4015", "V40331", "V403311", "VD4016", "VD4017", "VD4018", "VD4019", 
  "VD4020"
)

# Definindo os anos e trimestres para processar
anos <- 2016:2024
trimestres <- c("01", "02", "03", "04")

# Processando cada trimestre individualmente
for (ano in anos) {
  for (trim in trimestres) {
    
    # Montando o nome do arquivo – ajuste conforme o padrão dos seus arquivos
    nome_arquivo <- paste0("PNADC_", trim, ano, ".txt")
    
    # Lendo o arquivo usando a função do PNADcIBGE
    dados_trim <- read_pnadc(
      microdata = nome_arquivo,
      input_txt = "input_PNADC_trimestral.txt",
      vars = variaveis_selecionadas
    )
    
    # Filtrando ocupados: apenas quem trabalhou ou estagiou pelo menos 1 hora
    # - V4001 == "1" (trabalhou ou estagiou pelo menos 1 hora)
    dados_filtrados <- dados_trim %>%
      filter(V4001 == "1")
    
    # Salvando os dados filtrados para este trimestre em um arquivo RDS
    nome_saida <- paste0(dir_filtrados, "/pnadc_filtrado_", trim, "_", ano, ".rds")
    saveRDS(dados_filtrados, file = nome_saida)
    
    # Limpando memória para o próximo ciclo
    rm(dados_trim, dados_filtrados)
    gc()
  }
}

# Após o processamento, carregue os arquivos filtrados e una-os
arquivos_filtrados <- list.files(dir_filtrados, pattern = "\\.rds$", full.names = TRUE)
lista_filtrados <- lapply(arquivos_filtrados, readRDS)
pnad_final <- do.call(rbind, lista_filtrados)

# Adicionando o dicionário (rotulação das variáveis)
pnad_final <- pnadc_labeller(
  data_pnadc = pnad_final, 
  dictionary.file = "dicionario_PNADC_microdados_trimestral.xls"
)

# Adicionando o deflator
pnad_final <- pnadc_deflator(
  data_pnadc = pnad_final, 
  deflator.file = "deflator_PNADC_2024_trimestral_101112.xls"
)

#Salvando base. Caso vc não tenha memória no pc suficiente para esta etapa, use este arquivo: pnad_final_21_06_25.rds
pnad_final_21_06_25 <- pnad_final
saveRDS(pnad_final_21_06_25, file = "pnad_final_21_06_25.rds")

# Carregando o arquivo .rds
pnad_final_21_06_25 <- readRDS("pnad_final_21_06_25.rds")

# Atribuindo à variável 'pnad_final'
pnad_final <- pnad_final_21_06_25
rm(pnad_final_21_06_25)

# Filtrando por tipo de emprego, remuneração e idade
pnad_filtrada <- pnad_final %>%
  filter(V2009 >= 14, V4012 == "Empregado do setor privado", V40331 == "Em dinheiro")

pnad_final <- pnad_filtrada
rm(pnad_filtrada)


## VERIFICANDO E FILTRANDO A BASE DE DADOS ---------------------------------------------

# Quantos indivíduos tenho na base?
library(openxlsx)
# cria o resumo
resumo <- pnad_final %>% 
  summarise(
    n_obs   = n()
  )

# Criando o workbook 
wb <- createWorkbook()
addWorksheet(wb, "Resumo PNADC")
writeData(wb, "Resumo PNADC", resumo)

# Salvando o arquivo
saveWorkbook(wb, "resumo_pnad_final.xlsx", overwrite = TRUE)

# Contando linhas por entrevista
# Criando o tibble de linhas por entrevista
tabela_linhas <- pnad_final %>%
  group_by(V1016) %>%
  summarise(n_linhas = n()) %>%
  arrange(V1016)

# Salvando em um arquivo .xlsx
write_xlsx(tabela_linhas, path = "linhas_por_entrevista.xlsx")

glimpse(pnad_final)


# criando variável salário EFETIVO REAL - DEFLACIONADO
pnad_final <- pnad_final %>%
  mutate(VD4016_Real = VD4016 * Habitual)

# Verificando salários por entrevistas
stats_salario <- pnad_final %>%
  group_by(V1016) %>%
  summarise(
    media_salario = mean(VD4016_Real, na.rm = TRUE),
    sd_salario    = sd(VD4016_Real,   na.rm = TRUE),
    n_linhas      = n()
  ) %>%
  arrange(V1016)

stats_salario

# Gravando a tabela em um arquivo .xlsx
write_xlsx(stats_salario, path = "salarios_por_entrevistas.xlsx")

# Identificando indivíduos com pelo menos 2 entrevistas

# Chave individuos
# Excluindo indivíduos com valores NA nos dados de nascimento (V2008, V20081, V20082)
pnad_final <- pnad_final %>% 
  filter(!is.na(V2008) & !is.na(V20081) & !is.na(V20082))

# Criando a chave de identificação para cada indivíduo
pnad_final <- pnad_final %>% 
  mutate(chave_individuo = paste(UPA, V1008, V1014, V2003, V2008, V20081, V20082, sep = "_"))


# Verificando salários dos individuos que responderam a 2 ou mais entrevistas
ind2mais <- pnad_final %>%
  count(chave_individuo) %>%
  filter(n >= 2) %>%
  pull(chave_individuo)

# Logaritimizando variável - Considerando horas mensais
pnad_final <- pnad_final %>%
  mutate(Salario_Hora = if_else(!is.na(VD4016_Real) & !is.na(V4039), VD4016_Real / (V4039 * 4.35), NA_real_),  # Considera horas mensais
         VD4016_log_hora = if_else(!is.na(Salario_Hora), log(Salario_Hora), NA_real_))  # Calcula log apenas se válido

head(pnad_final$V4039)
head(pnad_final$VD4016_log_hora)

# Extraindo salário da 1ª e da última entrevista de cada um
sal_pair_log <- pnad_final %>%
  filter(chave_individuo %in% ind2mais) %>%
  arrange(chave_individuo, V1016) %>%
  group_by(chave_individuo) %>%
  summarise(
    log_ini = first(VD4016_log_hora),   # log na 1ª entrevista
    log_fim = last(VD4016_log_hora)     # log na última entrevista
  ) %>%
  ungroup()

# Criando o vetor de diferenças
dif_log <- sal_pair_log$log_fim - sal_pair_log$log_ini

# Write_xlsx recebe um data.frame ou tibble e grava em um arquivo .xlsx
write_xlsx(sal_pair_log, path = "sal_pair_log.xlsx")

# Verificando normalidade das diferenças - nortest para amostras grandes + de 5000 obs
# install.packages("nortest")         # só na primeira vez
library(nortest)

# Executando o teste e guardando num objeto
ad_res <- ad.test(dif_log)

# Extraindo os elementos que interessam num data.frame
df_ad <- data.frame(
  Estatística = as.numeric(ad_res$statistic),
  p_value     = ad_res$p.value,
  row.names   = NULL
)

# Salvando em Excel
write_xlsx(df_ad, path = "resultado_ad_test.xlsx")

# Gráficos normalidade
qqnorm(dif_log); qqline(dif_log)
hist(dif_log, breaks = 50)

# Salvando apenas o QQ-plot em PDF - qq plot nao ta saindo no PDF!
# Abrindo o PDF
pdf("qqplot_dif_log.pdf", width = 6, height = 6)

# Gerando o QQ-plot
qqnorm(dif_log, main = "QQ-Plot de dif_log")
qqline(dif_log)

# Fechando o PDF
dev.off()

# Salvando apenas o histograma em PDF
pdf("histograma_dif_log.pdf", width = 6, height = 6)
hist(
  dif_log,
  breaks = 50,
  main   = "Histograma de dif_log",
  xlab   = "dif_log",
  ylab   = "Frequência"
)
dev.off()

# Teste t pareado nos logs
t_log <- t.test(sal_pair_log$log_fim,
                sal_pair_log$log_ini,
                paired = TRUE)

t_log

# E variação média aproximada em %:
(exp(t_log$estimate) - 1) * 100

# Filtrando dados apenas para 1ª entrevista
pnad_entrev1 <- pnad_final %>%
  filter(V1016 == 1)

# Emprego secundário

# vetor com códigos do turismo
turismo_codes <- c(
  "79000","55000","77020","92000","93011","93020",
  "90000","91000","56011","56012","56020","51000",
  "50000","49010","49030","49090"
)

# Montando a tabela de setor principal
tabela_setor_principal <- pnad_entrev1 %>%
  mutate(
    setor_principal = if_else(V4013 %in% turismo_codes, "Turismo", "Outros")
  ) %>%
  count(setor_principal, name = "n_individuos") %>%
  arrange(desc(n_individuos))

tabela_setor_principal

tabela_secundario_turismo_por_setor <- pnad_entrev1 %>%
  mutate(setor_principal = if_else(V4013 %in% turismo_codes, "Turismo", "Outros")) %>%
  group_by(setor_principal) %>%
  summarise(
    n_individuos       = n(),
    # quem tem ≥2 empregos
    n_secundario       = sum(V4009 %in% c("Dois", "Três ou mais"), na.rm = TRUE),
    # desses, quantos têm 2º emprego NO TURISMO
    n_secundario_tur   = sum(V4009 %in% c("Dois", "Três ou mais") &
                               V4044 %in% turismo_codes,
                             na.rm = TRUE),
    # percentuais
    perc_secundario    = n_secundario    / n_individuos * 100,
    perc_secundario_tur= n_secundario_tur/ n_individuos * 100
  ) %>%
  arrange(setor_principal)

tabela_secundario_turismo_por_setor

# Lista com as duas tabelas nomeadas
minhas_tabelas <- list(
  Setor_Principal          = tabela_setor_principal,
  Secundario_Por_Setor     = tabela_secundario_turismo_por_setor
)

# Gravando em um arquivo .xlsx na sua pasta de trabalho
library(writexl)
write_xlsx(minhas_tabelas, path = "resultados_tabelas.xlsx")

#excluindo variáveis data nascimento e emprego secundário
pnad_filtrada<- pnad_entrev1 %>% 
  select(-V2008, -V20081, -V20082, -V4041, -V4043, -V4044, 
         -V4048, -V40501, -V405012, -V4056, -V4057)

## VERIFICANDO E ELIMINANDO OUTLIERS ---------------------------------------

# Gráficos de densidade e linha quantis salário hora
# Abre o dispositivo PDF
pdf("densidade_salario_hora.pdf", width = 7, height = 5)

plot(density(pnad_filtrada$Salario_Hora, na.rm = TRUE),
     main = "Curva de Densidade - Salário por Hora",
     xlab = "Salário por hora (R$)",
     col = "blue",
     lwd = 2)
abline(v = quantile(pnad_filtrada$Salario_Hora, probs = c(0.01, 0.99), na.rm = TRUE),
       col = "red", lty = 2)

# Fechando o PDF e gravando o arquivo
dev.off()

# Para visualizar melhor a cauda a esquerda calcular a densidade
densidade <- density(pnad_filtrada$Salario_Hora, na.rm = TRUE)

# Obtendo a moda (ponto de maior densidade)
moda_salario <- densidade$x[which.max(densidade$y)]

# Abrindo o PDF
pdf("densidade_ate_moda.pdf", width = 7, height = 5)

# Plotando a curva de densidade até a moda
plot(densidade,
     main = "Curva de Densidade - Salário por Hora (até a Moda)",
     xlab = "Salário por hora (R$)",
     col = "blue",
     lwd = 2,
     xlim = c(0, moda_salario))  # Limita até a moda

# Adicionando as linhas verticais dos quantis
abline(v = quantile(pnad_filtrada$Salario_Hora, probs = c(0.01, 0.99), na.rm = TRUE),
       col = "red", lty = 2)

# Adicionando uma linha na moda
abline(v = moda_salario, col = "darkgreen", lty = 3)

# Fechando o PDF
dev.off()

# Calculando os quantis de 1% e 99% para a variável Salario_Hora
quantis <- quantile(pnad_filtrada$Salario_Hora, probs = c(0.01, 0.99), na.rm = TRUE)
limite_inferior_salhora <- quantis[1]

limite_superior_salhora <- quantis[2]

# Contando o número de observações abaixo do quantil de 1%
num_inferior_salhora <- sum(pnad_filtrada$Salario_Hora < limite_inferior_salhora, na.rm = TRUE)

# Contando o número de observações acima do quantil de 99%
num_superior_salhora <- sum(pnad_filtrada$Salario_Hora > limite_superior_salhora, na.rm = TRUE)

# Exibindo os resultados
cat("Observações abaixo do 1%:", num_inferior_salhora, "\n")
cat("Observações acima do 99%:", num_superior_salhora, "\n")
cat("Total de outliers a serem removidos:", num_inferior_salhora + num_superior_salhora, "\n")

# Montando o data.frame com os resultados
df_outliers <- data.frame(
  métricas                   = c("ABAIXO_1%", "ACIMA_99%", "TOTAL_OUTLIERS"),
  quantidade                 = c(num_inferior_salhora,
                                 num_superior_salhora,
                                 num_inferior_salhora + num_superior_salhora)
)

# Exportando para um arquivo .xlsx
write_xlsx(df_outliers, path = "outliers_salario_hora.xlsx")

# Graficos densidade e linha quantis hora semanal

# Abrindo o dispositivo PDF (ou troque para png() conforme desejar)
pdf("densidade_horas_trabalhadas.pdf", width = 7, height = 5)

plot(density(pnad_filtrada$V4039, na.rm = TRUE),
     main = "Curva de Densidade - Horas Trabalhadas",
     xlab = "Hora Semanal",
     col = "blue",
     lwd = 2)
abline(v = quantile(pnad_filtrada$V4039, probs = c(0.01, 0.99), na.rm = TRUE),
       col = "red", lty = 2)

# Fechando o dispositivo, gravando o PDF
dev.off()

# Calculando os quantis de 1% e 99% para a variável Salario_Hora
quantis <- quantile(pnad_filtrada$V4039, probs = c(0.01, 0.99), na.rm = TRUE)
limite_inferior_V4039 <- quantis[1]
limite_superior_V4039 <- quantis[2]

# Contando o número de observações abaixo do quantil de 1%
num_inferior_V4039 <- sum(pnad_filtrada$V4039 < limite_inferior_V4039, na.rm = TRUE)

# Contando o número de observações acima do quantil de 99%
num_superior_V4039 <- sum(pnad_filtrada$V4039 > limite_superior_V4039, na.rm = TRUE)

# Exibindo os resultados
cat("Observações abaixo do 1%:", num_inferior_V4039, "\n")
cat("Observações acima do 99%:", num_superior_V4039, "\n")
cat("Total de outliers a serem removidos:", num_inferior_V4039 + num_superior_V4039, "\n")

# Montando o data.frame com os resultados de horas trabalhadas
df_outliers_horas <- data.frame(
  métricas       = c("ABAIXO_1%", "ACIMA_99%", "TOTAL_OUTLIERS"),
  quantidade     = c(
    num_inferior_V4039,
    num_superior_V4039,
    num_inferior_V4039 + num_superior_V4039
  )
)

# Exportando para um arquivo .xlsx
write_xlsx(df_outliers_horas, path = "outliers_horas_trabalhadas.xlsx")

# Excluindo outliers

# Calculando os limites para Salario_Hora
quantis_sh <- quantile(pnad_filtrada$Salario_Hora, probs = c(0.01, 0.99), na.rm = TRUE)
limite_inferior_sh <- quantis_sh[1]
limite_superior_sh <- quantis_sh[2]

# Calculando os limites para V4039 (Horas Semanais)
quantis_v4039 <- quantile(pnad_filtrada$V4039, probs = c(0.01, 0.99), na.rm = TRUE)
limite_inferior_v4039 <- quantis_v4039[1]
limite_superior_v4039 <- quantis_v4039[2]

# Filtrando os dados removendo outliers de ambas as variáveis 
pnad_filtrada_sem_outliers <- pnad_filtrada[
  pnad_filtrada$Salario_Hora >= limite_inferior_sh &
    pnad_filtrada$Salario_Hora <= limite_superior_sh &
    pnad_filtrada$V4039 >= limite_inferior_v4039 &
    pnad_filtrada$V4039 <= limite_superior_v4039, ]

# A amostra restante conta com pessoas que trabalham entre 
# 10 e 65 horas e o salário hora está entre R$1,99 - R$80,00
cat("Número de observações originais:", nrow(pnad_filtrada), "\n")
cat("Número de observações após remoção:", nrow(pnad_filtrada_sem_outliers), "\n")

resumo_outliers <- data.frame(
  etapa          = c("Original", "Sem_Outliers"),
  n_observacoes  = c(nrow(pnad_filtrada),
                     nrow(pnad_filtrada_sem_outliers))
)

write_xlsx(resumo_outliers, "resumo_outliers.xlsx")

summary(pnad_filtrada_sem_outliers %>% select(Salario_Hora))
summary(pnad_filtrada_sem_outliers %>% select(V4039))


# Extraindo os summaries como vetores
sum_sh   <- summary(pnad_filtrada_sem_outliers$Salario_Hora)
sum_horas<- summary(pnad_filtrada_sem_outliers$V4039)

# Convertendo cada summary em data.frame “longo”
df_sum_sh <- data.frame(
  Estatística    = names(sum_sh),
  Salario_Hora   = as.numeric(sum_sh),
  row.names      = NULL,
  stringsAsFactors = FALSE
)

df_sum_horas <- data.frame(
  Estatística    = names(sum_horas),
  Horas_Semanais = as.numeric(sum_horas),
  row.names      = NULL,
  stringsAsFactors = FALSE
)

# Colocando ambos num lista
minhas_summaries <- list(
  Resumo_Salario_Hora = df_sum_sh,
  Resumo_Horas        = df_sum_horas
)

# Escrevendo a planilha com duas abas
write_xlsx(minhas_summaries, path = "summaries_pnad_sem_outliers.xlsx")


# Coincidindo nome arquivo para fazer transformações das variáveis

pnad_c16241Entrevista <- pnad_filtrada_sem_outliers

# Verificando quantos trabalham no turismo
resumo_setor <- pnad_c16241Entrevista %>%
  mutate(setor_principal = if_else(V4013 %in% turismo_codes, "Turismo", "Outros")) %>%
  distinct(chave_individuo, setor_principal) %>%   # garante 1 linha por pessoa × setor
  count(setor_principal, name = "n_individuos") %>%
  arrange(desc(n_individuos))

resumo_setor


rm(pnad_filtrada_sem_outliers)
rm(pnad_filtrada)
rm(pnad_c1624_1Entrevista_1ouMaisEmp2)
rm(pnad_final, pnad_entrev1)

## TRANSFORMANDO VARIÁVEIS -------------------------------------------------

# Recodificando Escolaridade categórica - 4 categorias
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(VD3004_nivel_Escol = case_when(
    VD3004 %in% c("Sem instrução e menos de 1 ano de estudo", "Fundamental incompleto ou equivalente") ~ "Fundamental_Incompleto",
    VD3004 %in% c("Fundamental completo ou equivalente", "Médio incompleto ou equivalente") ~ "Fundamental_Completo",
    VD3004 %in% c("Médio completo ou equivalente", "Superior incompleto ou equivalente") ~ "Médio_Completo",
    VD3004 %in% c("Superior completo") ~ "Superior_Completo",
    TRUE ~ NA_character_  # Ignora "Sem instrução" e outros casos
  ))

head(pnad_c16241Entrevista$VD3004_nivel_Escol, n = 100)
table(pnad_c16241Entrevista$VD3004_nivel_Escol)


# Recodificando Escolaridade categórica - 2 categorias - Médio x não médio
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(VD3004_nivel_Escol2 = case_when(
    VD3004 %in% c("Sem instrução e menos de 1 ano de estudo", 
                  "Fundamental incompleto ou equivalente", 
                  "Fundamental completo ou equivalente", 
                  "Médio incompleto ou equivalente") ~ "Sem_Ensino_Medio",
    
    VD3004 %in% c("Médio completo ou equivalente", 
                  "Superior incompleto ou equivalente", 
                  "Superior completo") ~ "Com_Ensino_Medio",
    
    TRUE ~ NA_character_
  ))


head(pnad_c16241Entrevista$VD3004_nivel_Escol2, n = 100)
table(pnad_c16241Entrevista$VD3004_nivel_Escol2)

# Recodificando Escolaridade categórica - 2 categorias - Superior x nao Superior
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(VD3004_nivel_Escol3 = case_when(
    VD3004 %in% c(
      "Sem instrução e menos de 1 ano de estudo", 
      "Fundamental incompleto ou equivalente", 
      "Fundamental completo ou equivalente", 
      "Médio incompleto ou equivalente", 
      "Médio completo ou equivalente", 
      "Superior incompleto ou equivalente"
    ) ~ "Sem_Ensino_Superior",
    
    VD3004 == "Superior completo" ~ "Com_Ensino_Superior",
    
    TRUE ~ NA_character_
  ))

head(pnad_c16241Entrevista$VD3004_nivel_Escol3, n = 100)
table(pnad_c16241Entrevista$VD3004_nivel_Escol3)

# Transformando 'VD3005' em uma variável contínua (de 0 a 16 anos)
# Verificando os valores únicos de VD3005
unique(pnad_c16241Entrevista$VD3005)
# Aplicando o case_when com os rótulos textuais corretos
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(VD3005_cont = case_when(
    VD3005 == "Sem instrução e menos de 1 ano de estudo" ~ 0,
    VD3005 == "1 ano de estudo" ~ 1,
    VD3005 == "2 anos de estudo" ~ 2,
    VD3005 == "3 anos de estudo" ~ 3,
    VD3005 == "4 anos de estudo" ~ 4,
    VD3005 == "5 anos de estudo" ~ 5,
    VD3005 == "6 anos de estudo" ~ 6,
    VD3005 == "7 anos de estudo" ~ 7,
    VD3005 == "8 anos de estudo" ~ 8,
    VD3005 == "9 anos de estudo" ~ 9,
    VD3005 == "10 anos de estudo" ~ 10,
    VD3005 == "11 anos de estudo" ~ 11,
    VD3005 == "12 anos de estudo" ~ 12,
    VD3005 == "13 anos de estudo" ~ 13,
    VD3005 == "14 anos de estudo" ~ 14,
    VD3005 == "15 anos de estudo" ~ 15,
    VD3005 == "16 anos ou mais de estudo" ~ 16,
    TRUE ~ NA_real_
  ))

# Verificando os valores transformados
head(pnad_c16241Entrevista$VD3005_cont, n = 100)


# Recodificando Raça

# Variável grupos separados e sem o 'NÃO INFORMADO'

# Variável grupos separados com Não informado para evitar NA
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V2010_sep = case_when(
    V2010 == "Branca" ~ "Branca",
    V2010 %in% c("Preta") ~ "Preta",
    V2010 %in% c("Parda") ~ "Parda",
    V2010 %in% c("Indígena") ~ "Indígena",
    V2010 %in% c("Amarela") ~ "Amarela",
    TRUE ~ "Não_Informado"  # Substituir os casos não informados por "Desconhecido"
  ))

table(pnad_c16241Entrevista$V2010_sep)

# Variável BRANCA, PP E -99
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(
    V2010_grupo = case_when(
      V2010 == "Branca" ~ "Branca",
      V2010 %in% c("Preta", "Parda") ~ "PP",
      TRUE ~ NA_character_
    ),
    V2010_grupo = replace(V2010_grupo, is.na(V2010_grupo), "-99")
  )


table(pnad_c16241Entrevista$V2010_grupo)

# Variável BRANCA, PPI E -99
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(
    V2010_grupo2 = case_when(
      V2010 == "Branca" ~ "Branca",
      V2010 %in% c("Preta", "Parda", "Indígena", "Amarela") ~ "Nao_Branca",
      TRUE ~ "Não_Informado"))

table(pnad_c16241Entrevista$V2010_grupo2)

# Recodificando Posição Domicílio
unique(pnad_c16241Entrevista$V2005)

# Recodificando a variável V2005 em "Pessoa responsável", "Cônjuge", "Filhos..." e "Outros"
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V2005 = case_when(
    V2005 == 'Pessoa responsável pelo domicílio' ~ 'Pessoa_responsável',
    V2005 %in% c('Cônjuge ou companheiro(a) de sexo diferente', 
                 'Cônjuge ou companheiro(a) do mesmo sexo') ~ 'Cônjuge',   
    V2005 %in% c('Filho(a) do responsável e do cônjuge') ~ 'Filho_Resp_e_Conj',   
    V2005 %in% c('Filho(a) somente do responsável') ~ 'Filho_Resp',
    V2005 %in% c('Enteado(a)') ~ 'Enteado',
    V2005 %in% c('Genro ou nora', 
                 'Pai, mãe, padrasto ou madrasta', 
                 'Sogro(a)', 
                 'Neto(a)', 
                 'Bisneto(a)', 
                 'Irmão ou irmã', 
                 'Avô ou avó', 
                 'Outro parente', 
                 'Agregado(a) - Não parente que não compartilha despesas', 
                 'Convivente - Não parente que compartilha despesas', 
                 'Pensionista', 
                 'Empregado(a) doméstico(a)', 
                 'Parente do(a) empregado(a) doméstico(a)') ~ 'Outros',
    TRUE ~ 'Não Informado'  # Para qualquer outro valor não previsto
  ))
table(pnad_c16241Entrevista$V2005)
# Criando a variável que indica se o responsável ou cônjuge tem filhos no domicílio
# Verificando se há filhos no domicílio


# Codificando filhos
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V2005_filhos = case_when(
    V2005 == 'Filho_Resp_e_Conj' ~ 'Filho_Resp_e_Conj', 
    V2005 == 'Filho_Resp' ~ 'Filho_Resp',
    V2005 == 'Enteado' ~ 'Enteado',
    TRUE ~ NA_character_  # Alterar 'Outro' para NA
  ))

table(pnad_c16241Entrevista$V2005_filhos)

# Recodificando a variável V2005 em "Pessoa responsável", "Cônjuge", e "Outros"
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V2005_recode = case_when(
    V2005 == 'Pessoa_responsável' ~ 'Pessoa_responsável',
    V2005 %in% c('Cônjuge') ~ 'Cônjuge',
    TRUE ~ 'Outros'
  ))

table(pnad_c16241Entrevista$V2005_recode)

# Recategorizando Idade

# Criando histograma da variável de IDADE
ggplot(pnad_c16241Entrevista, aes(x = V2009)) +
  geom_histogram(binwidth = 5, fill = "blue", color = "black", alpha = 0.7) +
  labs(
    title = "idade",
    x = "idade",
    y = "Frequência"
  ) +
  theme_minimal()

# Regressão Local para Idade
library(ggplot2)
library(dplyr)

dados_idade <- pnad_c16241Entrevista %>%
  filter(!is.na(V2009), !is.na(VD4016_log_hora), V2009 >= 14, V2009 <= 80)

ggplot(dados_idade, aes(x = V2009, y = VD4016_log_hora)) +
  geom_point(alpha = 0.1) +
  geom_smooth(method = "loess", span = 0.75, se = FALSE, color = "blue") +
  labs(
    x = "Idade (V2009)",
    y = "Log do salário-hora (VD4016_log_hora)",
    title = "Relação entre idade e salário-hora (regressão local)"
  ) +
  theme_minimal()


# Recategorizando a idade após regressão local
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(idade_faixa = case_when(
    V2009 < 30 ~ "Ate_29",            # crescimento do salário-hora
    V2009 >= 30 & V2009 < 55 ~ "De_30_a_54", # salário estabilizado
    V2009 >= 55 ~ "Mais_de_55",           # possível saída do mercado
    TRUE ~ NA_character_
  ))

table(pnad_c16241Entrevista$idade_faixa)


# Recategorizando Horas Trabalhadas na Semana

# Criando histograma da variável de horas trabalhadas
ggplot(pnad_c16241Entrevista, aes(x = V4039)) +
  geom_histogram(binwidth = 5, fill = "blue", color = "black", alpha = 0.7) +
  labs(
    title = "Distribuição das Horas Trabalhadas (V4039)",
    x = "Horas Trabalhadas",
    y = "Frequência"
  ) +
  theme_minimal()

# Opção com base nos Regimes CLT
# Recategorizando V4039
# Criando uma nova variável categorizada com base em V4039
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(Horas_trabalhadas2 = case_when(
    V4039 <= 32 ~ "Parcial", #regime parcial
    V4039 >= 33 ~ "Integral", #regime integral
    TRUE ~ NA_character_  # Para lidar com valores NA ou não definidos
  ))

# Verificando a distribuição da nova variável
table(pnad_c16241Entrevista$Horas_trabalhadas2, useNA = "ifany")


# Criando variável idade ao quadrado
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V2009_quad = V2009^2)  # Criando a variável idade ao quadrado

head(pnad_c16241Entrevista$V2009_quad)


# Mapeamento UF-região:
mapa_regioes <- data.frame (UF = c("Acre", "Alagoas", "Amapá", "Amazonas", "Bahia", "Ceará", "Distrito Federal",
                                   "Espírito Santo", "Goiás", "Maranhão", "Mato Grosso", "Mato Grosso do Sul", 
                                   "Minas Gerais", "Pará", "Paraíba", "Paraná", "Pernambuco", "Piauí", "Rio de Janeiro",
                                   "Rio Grande do Norte", "Rio Grande do Sul", "Rondônia", "Roraima", "Santa Catarina", 
                                   "São Paulo", "Sergipe", "Tocantins"),
                            Regiao = c("Norte", "Nordeste", "Norte", "Norte", "Nordeste", "Nordeste", 
                                       "Centro_Oeste", "Sudeste", "Centro_Oeste", "Nordeste", "Centro_Oeste", 
                                       "Centro_Oeste", "Sudeste", "Norte", "Nordeste", "Sul", "Nordeste", 
                                       "Nordeste", "Sudeste", "Nordeste", "Sul", "Norte", "Norte", "Sul", 
                                       "Sudeste", "Nordeste", "Norte"))

# Unindo 'meu_survey' com 'mapa_regioes' para obter a região correspondente para cada UF
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  left_join(mapa_regioes, by = c("UF" = "UF"))

glimpse(pnad_c16241Entrevista)

head(pnad_c16241Entrevista$V1023)

# Renomeando V1023 em capital, METROPOLITANA,E RESTO UF 
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V1023_recode = case_when(
    V1023 == "Capital" ~ "Capital",
    V1023 == "Resto da RM (Região Metropolitana, excluindo a capital)" ~ "Região_Metropolitana",
    V1023 == "Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)" ~ "RIDE",
    V1023 == "Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)" ~ "Resto_UF",
    TRUE ~ NA_character_
  ))

table(pnad_c16241Entrevista$V1023_recode)

# Renomeando V1023 em capital+ METROPOLITANA E RIDE + RESTO UF 
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V1023_recode2 = case_when(
    V1023 == "Capital" ~ "Capital",
    V1023 == "Resto da RM (Região Metropolitana, excluindo a capital)" ~ "Regiao_Metropolitana",
    V1023 %in% c(
      "Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)",
      "Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)"
    ) ~ "Resto_UF",
    TRUE ~ NA_character_
  ),
  V1023_recode = factor(V1023_recode2, levels = c("Capital", "Regiao_Metropolitana", "Resto_UF")))

table(pnad_c16241Entrevista$V1023_recode2)

# Capital + Metropolitana x Resto UF
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V1023_recode3 = case_when(
    V1023 %in% c(
      "Capital", 
      "Resto da RM (Região Metropolitana, excluindo a capital)"
    ) ~ "Capital_e_Metropolitana",
    
    V1023 %in% c(
      "Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)", 
      "Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)"
    ) ~ "Resto_UF",
    
    TRUE ~ NA_character_
  ))

table(pnad_c16241Entrevista$V1023_recode3)

# Recodificando a variável V1023 como "Capital" e "Não Capital"
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(
    V1023_capncap = case_when(
      V1023 == "Capital" ~ "Capital",  # Caso 1: Capital
      
      V1023 %in% c(
        "Resto da RM (Região Metropolitana, excluindo a capital)", 
        "Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)", 
        "Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)"
      ) ~ "Não_Capital",  # Caso 2: Todas as demais categorias agrupadas
      
      TRUE ~ NA_character_  # Segurança: se houver algo inesperado
    )
  )

table(pnad_c16241Entrevista$V1023_capncap)


# Carregando dicionário CNAES
cnae_mapping <- readRDS("cnae_mapping.rds")

# Verificando se o dicionário CNAE está carregado corretamente
head(cnae_mapping)  # Deve mostrar os primeiros elementos

# Função para obter o nome da atividade a partir do código CNAE

get_activity_name <- function(cnae_code) {
  if (cnae_code %in% names(cnae_mapping)) {
    return(cnae_mapping[[cnae_code]])
  } else {
    return("Código CNAE não encontrado")
  }
}

# Exemplos de uso da função
cnae_code <- "01101"
activity_name <- get_activity_name(cnae_code)
print(activity_name)  # Isso imprimirá "Cultivo de arroz"

cnae_code <- "03002"
activity_name <- get_activity_name(cnae_code)
print(activity_name)  # Isso imprimirá "Aqüicultura"


# Substituindo os códigos pelos nomes correspondentes
pnad_c16241Entrevista$cnae_mapping <- cnae_mapping[as.character(pnad_c16241Entrevista$V4013)]

# Exibindo o resultado - VER TBL_DF
glimpse(pnad_c16241Entrevista)


# Dicionário Códigos de ocupação

# Carregando dicionário CNAES
nomes_ocupacao <- readRDS("nomes_ocupacao.rds")

# Verificando se o dicionário CNAE está carregado corretamente
head(nomes_ocupacao)  # Deve mostrar os primeiros elementos

# Função para obter o nome da atividade a partir do código CNAE
get_job_name <- function(job_code) {
  if (job_code %in% names(nomes_ocupacao)) {
    return(nomes_ocupacao[[job_code]])
  } else {
    return("Código CBO não encontrado")
  }
}

# Exemplos de uso da função
job_code <- "0512"
job_name <- get_job_name(job_code)
print(job_name)  # Isso imprimirá "Graduados e praças do corpo de bombeiros"

job_code <- "0110"
job_name <- get_job_name(job_code)
print(job_name)  # Isso imprimirá "Oficiais das forças armadas"


# Substituindo os códigos pelos nomes correspondentes
pnad_c16241Entrevista$nomes_ocupacao <- nomes_ocupacao[as.character(pnad_c16241Entrevista$V4010)]

# Exibir o resultado

glimpse(pnad_c16241Entrevista)

# Definindo a função de atribuição de grupos de CNAE
atribuir_grupo <- function(cnae) {
  ifelse(cnae %in% c("79000"), "Agencias_de_viagens_e_operadoras",
         ifelse(cnae %in% c("55000"), "Alojamento",
                ifelse(cnae %in% c("77020"), "Alugue_de_automoveis",
                       ifelse(cnae %in% c("92000", "93011", "93020"), "Atividade_desportiva_e_recreativa",
                              ifelse(cnae %in% c("90000", "91000"), "Atividade_Cultural",
                                     ifelse(cnae %in% c("56011", "56012", "56020"), "Alimentacao",
                                            ifelse(cnae %in% c("51000"), "Transporte_Aereo",
                                                   ifelse(cnae %in% c("50000"), "Transporte_Aquaviario",
                                                          ifelse(cnae %in% c("49010"), "Transporte_rodoviario",
                                                                 ifelse(cnae %in% c("49030", "49090"), "Transporte_ferroviario",
                                                                        "Outro"))))))))))
}

# Aplicando a função aos seus dados e criar uma nova coluna
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(grupo_cnae = atribuir_grupo(V4013))

# Criando a variável dummy para atividades de turismo - 1 se trabalha em turismo, 0 se não
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(turismo_dummy = ifelse(grupo_cnae %in% c("Agencias_de_viagens_e_operadoras", 
                                                  "Alojamento", 
                                                  "Aluguel_de_automoveis", 
                                                  "Atividade_desportiva_e_recreativa", 
                                                  "Atividade_Cultural", 
                                                  "Alimentacao", 
                                                  "Transporte_Aereo", 
                                                  "Transporte_Aquaviario", 
                                                  "Transporte_rodoviario", 
                                                  "Transporte_ferroviario"), 1, 0))
head(pnad_c16241Entrevista$turismo_dummy, n = 200)
glimpse(pnad_c16241Entrevista)

table(pnad_c16241Entrevista$turismo_dummy)

# Recodificando Composição domiciliar VD2004

pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(grupo_moradia = case_when(
    VD2004 == "Unipessoal" ~ "Unipessoal",
    VD2004 %in% c("Nuclear", "Estendida", "Composta") ~ "Coletivo",
    TRUE ~ NA_character_ # Caso queira lidar com outros valores
  )) 
table(pnad_c16241Entrevista$grupo_moradia)

# Recodificando tempo no emprego
# Resumo estatístico das horas trabalhadas
summary(pnad_c16241Entrevista$V4040)

# Média salarial por tempo no emprego
pnad_c16241Entrevista %>%
  group_by(V4040) %>%
  summarise(media_log_hora = mean(VD4016_log_hora, na.rm = TRUE),
            n = n()) %>%
  arrange(desc(n))


# Criando um gráfico de barras para variável categórica V4040
ggplot(pnad_c16241Entrevista, aes(x = V4040)) +
  geom_bar(fill = "blue", color = "black", alpha = 0.7) +
  labs(
    title = "Distribuição do Tempo no Emprego (V4040)",
    x = "Tempo no Emprego",
    y = "Frequência"
  ) +
  theme_minimal()

# Recodificando tempo no emprego em 2 categorias
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(V4040_recode = case_when(
    V4040 %in% c('Menos de 1 mês', 'De 1 mês a menos de 1 ano', 'De 1 ano a menos de 2 anos') ~ "Menos_de_2_anos",   
    V4040 == '2 anos ou mais' ~ "Mais_de_2_anos",                                
    TRUE ~ NA_character_  # Ignorar "Não aplicável" e outros valores
  ))

table(pnad_c16241Entrevista$V4040_recode)

# Criando variável experiência
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(
    experiencia = V2009 - VD3005_cont - 6,  # Idade menos anos de estudo menos 6
    experiencia_quad = experiencia^2        # Quadrado da experiência
  )

summary(pnad_c16241Entrevista$VD4011)

library(ggplot2)

# Criando o gráfico de barras para a variável VD4011
ggplot(pnad_c16241Entrevista, aes(x = VD4011)) +
  geom_bar(fill = "steelblue", color = "black", alpha = 0.7) +
  labs(
    title = "Distribuição das Ocupações (VD4011)",
    x = "Categorias Ocupacionais",
    y = "Frequência"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))  # Rotacionar os textos para melhor visualização

# Recategorização
library(dplyr)

pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  # Excluir a categoria "Membros das forças armadas, policiais e bombeiros militares"
  filter(VD4011 != "Membros das forças armadas, policiais e bombeiros militares") %>%
  # Recodificar as categorias em três grupos
  mutate(
    VD4011_recode = case_when(
      VD4011 %in% c("Diretores e gerentes", 
                    "Profissionais das ciências e intelectuais") ~ "Alta_qualificacao",
      
      VD4011 %in% c("Técnicos e profissionais de nível médio",
                    "Trabalhadores de apoio administrativo",
                    "Trabalhadores dos serviços, vendedores dos comércios e mercados",
                    "Trabalhadores qualificados da agropecuária, florestais, da caça e da pesca",
                    "Trabalhadores qualificados, operários e artesões da construção, das artes mecânicas e outros ofícios") ~ "Media_qualificacao",
      
      VD4011 %in% c("Operadores de instalações e máquinas e montadores",
                    "Ocupações elementares",
                    "Ocupações maldefinidas") ~ "Baixa_qualificacao",
      
      TRUE ~ NA_character_
    )
  )

table(pnad_c16241Entrevista$VD4011_recode)

# Criando períodos Pandemia
pnad_c16241Entrevista <- pnad_c16241Entrevista %>%
  mutate(Pandemia = case_when(
    Ano %in% c(2016, 2017, 2018, 2019) ~ "Antes_Pandemia",
    Ano %in% c(2020, 2021) ~ "Durante_Pandemia",
    Ano %in% c(2022, 2023, 2024) ~ "Apos_Pandemia"
  )) %>%
  mutate(Pandemia = factor(Pandemia, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia")))

table(pnad_c16241Entrevista$Pandemia)

table(pnad_c16241Entrevista$Pandemia, useNA = "ifany")


## INCORPORANDO DESENHO AMOSTRAL COMPLEXO ----------------------------------

library(survey)

# Definindo o desenho amostral
pnad_survey <- svydesign(
  ids = ~UPA,
  strata = ~Estrato,
  weights = ~V1028,
  data = pnad_c16241Entrevista,
  nest = TRUE
)

# Verificando medias com e sem plano amostral
# Média simples (sem pesos)
mean_sem_pesos_salario <- mean(pnad_c16241Entrevista$VD4016_Real, na.rm = TRUE)
mean_sem_pesos_hora <- mean(pnad_c16241Entrevista$Salario_Hora, na.rm = TRUE)

# Média com pesos (desenho amostral)
mean_com_pesos_salario <- svymean(~VD4016_Real, pnad_survey, na.rm = TRUE)
mean_com_pesos_hora <- svymean(~Salario_Hora, pnad_survey, na.rm = TRUE)

# Exibindo resultados
cat("🟡 Média SALÁRIO MENSAL\n")
cat("- Sem pesos: ", round(mean_sem_pesos_salario, 2), "\n")
print(mean_com_pesos_salario)

cat("\n🟢 Média SALÁRIO HORA\n")
cat("- Sem pesos: ", round(mean_sem_pesos_hora, 2), "\n")
print(mean_com_pesos_hora)

library(fastDummies)

# Selecionando variáveis desejadas e criando dummies
pnad_Filtrada <- pnad_c16241Entrevista %>%
  dplyr::select(Ano, Trimestre, UPA, Estrato, V1028, ID_DOMICILIO, V2007, V2009, V2009_quad, idade_faixa, 
                V2010_sep, V2010_grupo, V2010_grupo2, V2005_recode, grupo_moradia, VD2003, VD3004_nivel_Escol,VD3004_nivel_Escol2, VD3004_nivel_Escol3, 
                VD3005_cont, experiencia, Regiao, V1023_recode, V1023_recode2, V1023_recode3, V1023_capncap, V4029, V4025, V4039, V4040_recode, 
                Horas_trabalhadas2, VD4011_recode, V4013, grupo_cnae, nomes_ocupacao, Salario_Hora, VD4016_Real, 
                VD4016_log_hora, VD4017, turismo_dummy,  Pandemia) %>%
  dummy_cols(select_columns = c("V2007", "idade_faixa", "V2010_sep", "V2010_grupo", "V2010_grupo2", 
                                "V2005_recode", "V1023_recode", "V1023_recode2", "V1023_recode3", "V1023_capncap", "grupo_moradia", 
                                "VD3004_nivel_Escol", "VD3004_nivel_Escol2", "VD3004_nivel_Escol3", "Regiao", "V1023_recode", "V4029", "V4025", 
                                "V4040_recode", "Horas_trabalhadas2", "VD4011_recode", "grupo_cnae", "Ano", "Trimestre", "Pandemia"),
             remove_first_dummy = FALSE,  # Mantém todas as dummies
             remove_selected_columns = FALSE)  # Mantém as colunas originais

glimpse(pnad_Filtrada)

## CRIANDO A BASE DE AUDITORIA COM AMOSTRAGEM ESTRATIFICADA ----------------------------------

# O objetivo é garantir a presença de TODOS os anos, trimestres e ambos os setores,
# e corrigir o problema de Estratos com apenas uma UPA (PSU).

# Definindo o percentual de amostragem por estrato
proporcao_amostra_estratificada <- 0.05 

# Amostragem Estratificada
pnad_auditoria_bruta <- pnad_Filtrada %>%
  # Agrupando pelos estratos cruciais para manter a representação (PSM)
  group_by(Ano, Trimestre, turismo_dummy) %>%
  slice_sample(prop = proporcao_amostra_estratificada, replace = FALSE) %>%
  ungroup()

# Verificação e correção do prob lema de estrato/PSU único (Solução para 'onestrat()')
# Identificando estratos na amostra que têm apenas 1 PSU (UPA)
psu_por_estrato <- pnad_auditoria_bruta %>%
  group_by(Estrato) %>%
  summarise(n_psu = n_distinct(UPA), .groups = "drop")

estratos_problematicos <- psu_por_estrato %>%
  filter(n_psu <= 1) %>% # Estratos com 0 ou 1 UPA (o erro ocorre em 1)
  pull(Estrato)

# Removendo todas as observações pertencentes aos estratos problemáticos
# Isso garante que a condição do pacote survey seja atendida.
pnad_auditoria_limpa <- pnad_auditoria_bruta %>%
  filter(!Estrato %in% estratos_problematicos)

# Contagem para auditoria:
cat(
  "Observações originais na base auditável: ", nrow(pnad_auditoria_bruta), "\n",
  "Estratos problemáticos removidos: ", length(estratos_problematicos), "\n",
  "Observações finais na base auditável: ", nrow(pnad_auditoria_limpa), "\n"
)

# Salvando a versão final limpa
saveRDS(pnad_auditoria_limpa, file = "pnad_auditoria_amostra_estratificada_limpa.rds")


# Substituindo a base grande pela amostra auditável limpa
pnad_Filtrada <- pnad_auditoria_limpa

# Limpando objetos temporários
rm(pnad_auditoria_bruta, pnad_auditoria_limpa, psu_por_estrato, estratos_problematicos)
gc()


## ABRINDO BASE AUDITÁVEL -------------------------------------

setwd("C:/Users/Ana Oliveira/Desktop/pnadc 2023") #Altere para o nome do seu diretório

# Carregando o arquivo .rds
pnad_auditoria_limpa <- readRDS("pnad_auditoria_amostra_estratificada_limpa.rds")

# Substituindo a base grande pela amostra auditável limpa
pnad_Filtrada <- pnad_auditoria_limpa

# Abrindo pacotes, caso ainda nao tenha feito isso
library(tidyverse)
library(survey)
library(srvyr)
library(PNADcIBGE)
library(dplyr)


## TRANSFORMANDO EM OBJETO SRVYR -------------------------------------

pnad_Filtrada_srvyr <- pnad_Filtrada %>%
  as_survey_design(
    ids     = UPA,
    strata  = Estrato,
    weights = V1028,
    nest    = TRUE
  )
nrow(pnad_Filtrada_srvyr)

## ANÁLISES DESCRITIVAS ----------------------------------------------------

#  Pacotes necessários
library(srvyr)
library(dplyr)
library(rlang)
library(purrr)
library(ggplot2)
library(writexl)
library(tidyr)


# Preparando para obter rótulos corretos
pnad_Filtrada_srvyr <- pnad_Filtrada_srvyr %>%
  mutate(
    Carteira_assinada_f = factor(V4029_Sim,
                                 levels = c(0,1),
                                 labels = c("Não","Sim")),
    Contrato_temp_f     = factor(V4025_Não,
                                 levels = c(1,0),
                                 labels = c("Não","Sim"))
  )


# Lista das variáveis categóricas
vars_cat <- c(
  "Ano",
  "V2007",               # Sexo
  "V2010_grupo",       # Raça (grupo)
  "idade_faixa",         # Faixa etária
  "VD3004_nivel_Escol", # Escolaridade Nível
  "VD3004_nivel_Escol2", # Escolaridade Nível 2
  "VD3004_nivel_Escol3", # Escolaridade Nível 3
  "V2005_recode",        # Posição domiciliar
  "grupo_moradia",       # Grupo moradia
  "Regiao",              # Região
  "V1023_recode3",       # Tipo região 3
  "V4040_recode",        # Tempo de emprego
  "VD4011_recode",       # Qualificação
  "Carteira_assinada_f",         # Carteira assinada
  "Contrato_temp_f",          # Contrato temporário
  "Horas_trabalhadas2"
)

glimpse(pnad_Filtrada)

# Vetor de rótulos (nome_original = rótulo_amigável)
rotulos <- c(
  Ano                        = "Ano",
  Trimestre                  = "Trimestre",
  V2007                      = "Sexo",
  V2010_grupo               = "Raça",
  idade_faixa                = "Faixa etária",
  VD3004_nivel_Escol        = "Escolaridade Nível",
  VD3004_nivel_Escol2        = "Escolaridade Nível_",
  VD3004_nivel_Escol3        = "Escolaridade Nível__",
  V2005_recode               = "Posição domiciliar",
  grupo_moradia              = "Grupo moradia",
  Regiao                     = "Região",
  V1023_recode3              = "Tipo região",
  Horas_trabalhadas2         = "Regime Horas Trabalhadas",
  Horas_trabalhadas2_Integral = "Integral",
  Horas_trabalhadas2_Parcial = "Parcial",
  V4040_recode               = "Tempo de emprego",
  VD4011_recode              = "Qualificação",
  Carteira_assinada_f                  = "Carteira assinada",
  Contrato_temp_f                  = "Contrato temporário",
  V2009          = "Idade (anos)",
  experiencia    = "Experiência (anos)",
  VD3005_cont    = "Anos de Escolaridade",
  VD4016_Real    = "Salário Real (R$)",
  Salario_Hora   = "Salário por Hora (R$)",
  grupo_cnae     = "Atividade Econômica",
  nomes_ocupacao = "Ocupação"
)

# Descritivas com percentual interno por grupo 

# Função que calcula pct interna e salário médio por categoria dentro de cada grupo
tabela_cat_dist_interna <- function(var_nome) {
  var_sym <- sym(var_nome)
  
  pnad_Filtrada_srvyr %>%
    group_by(
      Tipo      = factor(turismo_dummy, levels = c(1,0),
                         labels = c("Turismo","Não turismo")),
      Categoria = !!var_sym
    ) %>%
    summarise(
      total   = survey_total(vartype = NULL),
      sal_med = survey_mean(VD4016_Real, vartype = NULL),
      .groups = "drop_last"
    ) %>%
    mutate(
      Categoria   = as.character(Categoria),
      pct_interna = total / sum(total) * 100,
      Variavel    = rotulos[var_nome]
    ) %>%
    ungroup() %>%
    select(Variavel, Tipo, Categoria, pct_interna, sal_med)
}

# Aplicando a todas as variáveis categóricas
dist_interna <- map_dfr(vars_cat, tabela_cat_dist_interna)

# Organizando em wide para Excel (pct_interna_* e sal_med_*)
dist_interna_wide <- dist_interna %>%
  pivot_wider(
    names_from  = Tipo,
    values_from = c(pct_interna, sal_med),
    names_glue  = "{.value}_{Tipo}"
  )

# Exportando
write_xlsx(
  list(Distribuição_Interna = dist_interna_wide),
  path = "Descritivas_PCT_interno_por_tipo_trabalhador_com_salario_medio.xlsx"
)

# Gráficos para descritivas separadas por categorias de trabalhadores

library(ggplot2)
library(dplyr)
library(tidyr)

# Sem a categoria -99 de raça:

# Abrindo o PDF de várias páginas
pdf("graficos_dist_interna_com_salario.pdf", onefile = TRUE, width = 10, height = 6)

for (var in unique(dist_interna$Variavel)) {
  df <- dist_interna %>% 
    filter(Variavel == var)
  
  # Removendo o -99 somente para Raça
  if (var == "Raça") {
    df <- df %>% filter(Categoria != "-99")
  }
  
  # Gráfico de distribuição interna por tipo de trabalhador
  p1 <- ggplot(df, aes(x = Categoria, y = pct_interna, fill = Tipo)) +
    geom_col(position = "dodge") +
    labs(
      title = paste0("Distribuição interna – ", var),
      x     = var,
      y     = "Percentual interno (%)"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(p1)
  
  # Gráfico de salário médio por categoria e tipo de trabalhador
  p2 <- ggplot(df, aes(x = Categoria, y = sal_med, fill = Tipo)) +
    geom_col(position = "dodge") +
    labs(
      title = paste0("Salário médio – ", var),
      x     = var,
      y     = "Salário médio (R$)"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(p2)
}

dev.off()


# Descritivas Numéricas para cada grupo Turismo vs não Turismo

# Lista das variáveis numéricas para média + desvio-padrão
vars_cont <- c("V2009", "V4039", "experiencia", "VD3005_cont", "VD4016_Real", "Salario_Hora")

# Função que calcula média e DP dentro de cada grupo, com labels sem espaço
tabela_cont_dist_interna <- function(var_nome) {
  var_sym <- sym(var_nome)
  
  pnad_Filtrada_srvyr %>%
    group_by(
      Tipo = factor(turismo_dummy,
                    levels = c(1, 0),
                    labels = c("Turismo", "Nao_turismo"))
    ) %>%
    summarise(
      media  = survey_mean(!!var_sym, vartype = NULL),
      desvio = survey_sd(  !!var_sym, vartype = NULL),
      .groups = "drop"
    ) %>%
    mutate(
      Variavel = rotulos[var_nome]
    ) %>%
    select(Variavel, Tipo, media, desvio)
}

# Empilhando
tabelas_cont_dist_interna <- map_dfr(vars_cont, tabela_cont_dist_interna)

# Pivot_wider e adiciona a diferença de médias
t_cont_wide <- tabelas_cont_dist_interna %>%
  pivot_wider(
    names_from  = Tipo,
    values_from = c(media, desvio),
    names_glue  = "{.value}_{Tipo}"
  ) %>%
  mutate(
    diff_media = media_Turismo - media_Nao_turismo
  )

# Exporta
write_xlsx(
  list(`Contínuas_Dist_Interna` = t_cont_wide),
  path = "descr_cont_dist_interna_por_trab.xlsx"
)


# Gráficos variáveis por grupo turismo vs nao turismo
library(ggplot2)

# Abrindo o PDF de várias páginas
pdf("graficos_continuas_e_salario_por_trab.pdf",
    onefile = TRUE, width = 10, height = 6)

# Para cada variável contínua, média ±1DP
for (var in unique(tabelas_cont_dist_interna$Variavel)) {
  dfp <- tabelas_cont_dist_interna %>%
    filter(Variavel == var)
  
  p <- ggplot(dfp, aes(x = Tipo, y = media, fill = Tipo)) +
    geom_col(width = 0.6) +
    geom_errorbar(aes(
      ymin = media - desvio,
      ymax = media + desvio
    ), width = 0.2) +
    labs(
      title = paste0("Média ±1 DP de ", var, " por tipo de trabalhador"),
      x     = "Tipo de trabalhador",
      y     = var
    ) +
    theme_minimal() +
    theme(
      legend.position = "none",
      axis.text.x   = element_text(angle = 45, hjust = 1)
    )
  print(p)
}

# Distribuição salarial (densidade) por grupo
salary_df <- pnad_Filtrada_srvyr %>%
  mutate(
    Tipo = factor(turismo_dummy,
                  levels = c(1, 0),
                  labels = c("Turismo", "Não turismo"))
  ) %>%
  select(Tipo, Salario = VD4016_Real) %>%
  filter(!is.na(Salario))

p_hist <- ggplot(salary_df, aes(x = Salario, fill = Tipo)) +
  geom_density(alpha = 0.4) +
  labs(
    title = "Densidade da distribuição salarial por tipo de trabalhador",
    x     = "Salário (R$)",
    y     = "Densidade"
  ) +
  theme_minimal()
print(p_hist)

# Boxplot salarial por grupo
p_box <- ggplot(salary_df, aes(x = Tipo, y = Salario, fill = Tipo)) +
  geom_boxplot() +
  labs(
    title = "Boxplot salarial por tipo de trabalhador",
    x     = "Tipo de trabalhador",
    y     = "Salário (R$)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(p_box)

# Fechando o dispositivo e gera o PDF
dev.off()

# Frequência por ACT
freq_turismo_cnae <- pnad_Filtrada_srvyr %>%
  filter(turismo_dummy == 1) %>%
  group_by(grupo_cnae) %>%
  summarise(freq_ponderada = survey_total(vartype = NULL)) %>%
  arrange(desc(freq_ponderada))

# Vendo resultado
freq_turismo_cnae


total_turismo <- pnad_Filtrada_srvyr %>%
  filter(turismo_dummy == 1) %>%
  summarise(total = survey_total(vartype = NULL)) %>%
  pull(total)

freq_turismo_cnae <- freq_turismo_cnae %>%
  mutate(freq_pct = freq_ponderada / total_turismo * 100)

freq_turismo_cnae

# Salvando no Excel
write_xlsx(freq_turismo_cnae, "freq_turismo_grupo_cnae.xlsx")


# Contando pessoas por CNAE e por quantis

# Percentis de interesse
quantis_percent <- c(10, 25, 50, 75, 90)

# Criando percent_rank (de 1 a 100) por grupo CNAE — percentil aproximado
# mas filtrando SÓ turismo_dummy == 1
pnad_srvyr_percent_rank <- pnad_Filtrada_srvyr %>%
  filter(turismo_dummy == 1) %>%           # só trabalhadores do turismo
  group_by(grupo_cnae) %>%
  mutate(percent_rank = ntile(VD4016_Real, 100)) %>%
  ungroup()

# Filtrando só os percent_rank que interessam e calcula frequência ponderada
freq_por_quantil <- pnad_srvyr_percent_rank %>%
  filter(percent_rank %in% quantis_percent) %>%
  group_by(grupo_cnae, percent_rank) %>%
  summarise(
    freq_ponderada = survey_total(vartype = NULL),
    .groups = "drop"
  ) %>%
  group_by(grupo_cnae) %>%
  mutate(
    total_cnae = sum(freq_ponderada),
    percentual = freq_ponderada / total_cnae * 100
  ) %>%
  arrange(grupo_cnae, percent_rank)

# Transformando para formato largo -> cada quantil vira uma coluna
tabela_final <- freq_por_quantil %>%
  select(grupo_cnae, percent_rank, percentual) %>%
  pivot_wider(
    names_from  = percent_rank,
    values_from = percentual,
    names_prefix = "quantil_"
  )

# Visualizando no console ou View()
print(tabela_final)

# View(tabela_final)   # se quiser abrir no Viewer do RStudio

# Exportando para Excel
write_xlsx(tabela_final,
           "Salario_percentil_cnae_turismo.xlsx")


# Verificando proporção por ACT com valores salariais por pecentis


# Definindo os percentis de interesse (em proporção)

quantis_prop <- c(0.10, 0.25, 0.50, 0.75, 0.90)
quantis_int  <- quantis_prop * 100   # = c(10, 25, 50, 75, 90)

# (Re)Criando o objeto srvyr, caso ainda não exista
#    Ajuste "ids", "strata" e "weights" de acordo com sua base PNAD

# pnad_Filtrada_srvyr <- pnad_original %>% 
as_survey_design(
  ids     = UPA,      # ou outra coluna de conglomerado
  strata  = Estrato,  # ou outra coluna de estrato
  weights = V1028,    # ajuste para a variável de peso
  nest    = TRUE
)

# Criando o subconjunto “turismo” (turismo_dummy == 1 e salário não-NA)
pnad_turismo_srvyr <- pnad_Filtrada_srvyr %>%
  filter(
    turismo_dummy == 1,
    !is.na(VD4016_Real)
  )

# Calculando o valor de salário em cada percentil (10, 25, 50, 75, 90)
#    Este “survey_quantile(…, vartype = NULL)” gera colunas:
#      quantil_10, quantil_25, quantil_50, quantil_75, quantil_90

valores_quantis <- pnad_turismo_srvyr %>%
  group_by(grupo_cnae) %>%
  summarise(
    quantil_10 = survey_quantile(VD4016_Real, quantile = 0.10, vartype = NULL),
    quantil_25 = survey_quantile(VD4016_Real, quantile = 0.25, vartype = NULL),
    quantil_50 = survey_quantile(VD4016_Real, quantile = 0.50, vartype = NULL),
    quantil_75 = survey_quantile(VD4016_Real, quantile = 0.75, vartype = NULL),
    quantil_90 = survey_quantile(VD4016_Real, quantile = 0.90, vartype = NULL),
    .groups = "drop"
  )

# Verificando que o data.frame “valores_quantis” ficou com colunas:
#    grupo_cnae | quantil_10 | quantil_25 | quantil_50 | quantil_75 | quantil_90
# Cada quantil_X é o valor de salário que separa exatamente o Xº percentil.

# Criando “percent_rank” e agrupar cada registro em faixas:
#    Faixas definidas em “cut_bins”:
#
#    1) “0_10”   = percent_rank <= 10,
#    2) “10_25”  = 10 < percent_rank <= 25,
#    3) “25_50”  = 25 < percent_rank <= 50,
#    4) “50_75”  = 50 < percent_rank <= 75,
#    5) “75_90”  = 75 < percent_rank <= 90,
#    6) “90_100” = percent_rank > 90
# ————————————————————————————————————————————————————————
faixas_percentil <- pnad_turismo_srvyr %>%
  # Gerando percent_rank de 1 a 100 por grupo_cnae
  mutate(percent_rank = ntile(VD4016_Real, 100)) %>%
  # Criando uma coluna “bin” que descreve a faixa de percentil de cada registro
  mutate(
    bin = case_when(
      percent_rank <= 10  ~ "0_10",
      percent_rank <= 25  ~ "10_25",
      percent_rank <= 50  ~ "25_50",
      percent_rank <= 75  ~ "50_75",
      percent_rank <= 90  ~ "75_90",
      TRUE                ~ "90_100"
    )
  ) %>%
  # Agora agrupando por (grupo_cnae, bin) e somando os pesos
  group_by(grupo_cnae, bin) %>%
  summarise(
    freq_bin = survey_total(vartype = NULL),  # soma de pesos naquela faixa
    .groups = "drop"
  )


# Calculando para cada grupo_cnae, o TOTAL (soma de todos os pesos)
# para depois transformar freq_bin em percentual.
total_por_cnae <- pnad_turismo_srvyr %>%
  group_by(grupo_cnae) %>%
  summarise(
    total_cnae = survey_total(vartype = NULL),
    .groups = "drop"
  )


# Juntando “faixas_percentil” com “total_por_cnae” e calcular % de cada bin
perc_por_faixa <- faixas_percentil %>%
  left_join(total_por_cnae, by = "grupo_cnae") %>%
  mutate(
    perc_ft = freq_bin / total_cnae * 100
  ) %>%
  select(grupo_cnae, bin, perc_ft)

# Transformando “perc_por_faixa” em formato WIDE, de modo que cada “bin”
# vire uma coluna separada: “perc_ft_0_10”, “perc_ft_10_25”, …, “perc_ft_90_100”

perc_por_faixa_wide <- perc_por_faixa %>%
  pivot_wider(
    names_from  = bin,
    values_from = perc_ft,
    names_prefix = "perc_ft_"
  )


# Unindo “valores_quantis” + “perc_por_faixa_wide” em uma tabela única
tabela_final <- valores_quantis %>%
  left_join(perc_por_faixa_wide, by = "grupo_cnae") %>%
  # selecionando colunas na ordem que desejar
  select(
    grupo_cnae,
    quantil_10, quantil_25, quantil_50, quantil_75, quantil_90,
    perc_ft_0_10, perc_ft_10_25, perc_ft_25_50,
    perc_ft_50_75, perc_ft_75_90, perc_ft_90_100
  )

names(valores_quantis)
# Renomeando percentis
valores_quantis <- valores_quantis %>%
  rename(
    quantil_10 = quantil_10_q10,
    quantil_25 = quantil_25_q25,
    quantil_50 = quantil_50_q50,
    quantil_75 = quantil_75_q75,
    quantil_90 = quantil_90_q90
  ) %>%
  select(grupo_cnae, quantil_10, quantil_25, quantil_50, quantil_75, quantil_90)
names(valores_quantis)
# Rodando passo anterior novamente


# Visualizando e exportando para Excel

print(tabela_final)
# View(tabela_final)   # se quiser abrir no Viewer do RStudio

write_xlsx(
  tabela_final,
  "Salario_quantis_e_percentual_por_faixa_cnae_turismo.xlsx"
)


# Obtendo ocupações mais frequentes por grupo e percentil
library(dplyr)
library(tidyr)
glimpse(pnad_Filtrada_srvyr)

# Definindo “cortes” (percentis) de interesse

# Esses são os valores de percent_rank que definem o topo de cada faixa
cortes <- c(10, 25, 50, 75, 90)   


# Criando percent_rank (1 a 100) dentro de cada grupo “turismo_dummy”
pnad_classificada <- pnad_Filtrada %>%
  group_by(turismo_dummy) %>%
  mutate(
    # percent_rank de 1 a 100
    percent_rank = ntile(VD4016_Real, 100)
  ) %>%
  ungroup()


# Criando coluna “bin” para agrupar percent_rank em intervalos:
#    0_10 (1≤r≤10), 10_25 (11≤r≤25), 25_50 (26≤r≤50),
#    50_75 (51≤r≤75), 75_90 (76≤r≤90), 90_100 (91≤r≤100).

pnad_classificada <- pnad_classificada %>%
  mutate(
    bin = case_when(
      percent_rank <= 10  ~ "0_10",
      percent_rank <= 25  ~ "10_25",
      percent_rank <= 50  ~ "25_50",
      percent_rank <= 75  ~ "50_75",
      percent_rank <= 90  ~ "75_90",
      TRUE                ~ "90_100"
    )
  )


# Calculando o “tamanho” (quantidade de linhas) de cada bin
#    sem ponderação, para cada combinação (turismo_dummy, bin)

group_sizes <- pnad_classificada %>%
  group_by(turismo_dummy, bin) %>%
  summarise(
    group_size = n(),  # número de linhas naquele bin
    .groups    = "drop"
  ) %>%
  # Para juntar mais tarde com os “cortes de quantil”, vamos associar
  # a cada “bin” seu percent_rank de corte correspondente:
  mutate(
    percent_rank = case_when(
      bin == "0_10"   ~ 10L,
      bin == "10_25"  ~ 25L,
      bin == "25_50"  ~ 50L,
      bin == "50_75"  ~ 75L,
      bin == "75_90"  ~ 90L,
      bin == "90_100" ~ 100L  # opcional; se você não quiser usar 100, remova ou ajuste
    )
  )


# Calculando os valores “reais” de salário que definem cada percent_rank de corte
#    (0.10, 0.25, 0.50, 0.75, 0.90, e opcionalmente 1.00)
#    Aqui usamos quantile() sem ponderação 
group_quantiles <- pnad_Filtrada %>%
  group_by(turismo_dummy) %>%
  summarise(
    p10  = quantile(VD4016_Real, probs = 0.10, na.rm = TRUE),
    p25  = quantile(VD4016_Real, probs = 0.25, na.rm = TRUE),
    p50  = quantile(VD4016_Real, probs = 0.50, na.rm = TRUE),
    p75  = quantile(VD4016_Real, probs = 0.75, na.rm = TRUE),
    p90  = quantile(VD4016_Real, probs = 0.90, na.rm = TRUE),
    p100 = quantile(VD4016_Real, probs = 1.00, na.rm = TRUE),  # opcional
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = starts_with("p"),
    names_to     = "percent_rank",
    names_prefix = "p",
    values_to    = "VD4016_Real_valor"
  ) %>%
  mutate(percent_rank = as.integer(percent_rank))


# Encontrando o Top-5 de “nomes_ocupacao” POR FREQUÊNCIA (não ponderada)
# dentro de cada bin (“0_10”, “10_25”, etc.) E cada “turismo_dummy”.
# Em seguida, recalcule o percentual **dentro do Top-5**, de modo que 
# sum(freq_pct) == 100 para as 5 linhas de cada bin.

top_extended <- pnad_classificada %>%
  # Filtrando apenas quem caiu em algum dos bins de interesse
  filter(bin %in% c("0_10", "10_25", "25_50", "50_75", "75_90", "90_100")) %>%
  
  # Para cada (turismo_dummy, bin, nomes_ocupacao), contar quantas linhas
  group_by(turismo_dummy, bin, nomes_ocupacao) %>%
  summarise(
    quantidade = n(), 
    .groups = "drop"
  ) %>%
  
  # Dentro de cada (turismo_dummy, bin), pegar as 5 ocupações de maior frequência:
  group_by(turismo_dummy, bin) %>%
  slice_max(quantidade, n = 5) %>%  # top 5 por quantidade
  ungroup() %>%
  
  # Recalculando, para cada (turismo_dummy, bin), a soma das quantidades do Top-5:
  group_by(turismo_dummy, bin) %>%
  mutate(
    sum_top5 = sum(quantidade)  # soma das 5 quantidades daquele bin
  ) %>%
  ungroup() %>%
  
  # Juntando “group_sizes” (que tem group_size e percent_rank) e 
  # “group_quantiles” (que tem VD4016_Real_valor para cada percent_rank)
  # Precisamos do percent_rank em group_sizes → já está lá
  left_join(group_sizes,     by = c("turismo_dummy", "bin")) %>%
  left_join(group_quantiles, by = c("turismo_dummy", "percent_rank")) %>%
  
  # Recalculando “freq_pct” de modo que some 100% somente dentro do Top-5:
  mutate(
    freq_pct = quantidade / sum_top5 * 100
  ) %>%
  
  # Ordenando para facilitar visualização
  arrange(turismo_dummy, bin, desc(freq_pct)) %>%
  
  # Selecionando as colunas finais na ordem em que queremos exportar
  select(
    turismo_dummy,
    bin,                  # “0_10”, “10_25” etc.
    percent_rank,         # o corte do percent_rank (10, 25, 50, 75, 90 ou 100)
    VD4016_Real_valor,    # valor de salário que define aquele percent_rank
    group_size,           # total de linhas naquele bin
    nomes_ocupacao,
    quantidade,           # contagem bruta daquela ocupação no bin
    sum_top5,             # soma das quantidades das 5 ocupações mais frequentes no bin
    freq_pct              # porcentual (dentro do Top-5) que cada ocupação representa
  )


# Visualizando e exportando para Excel

print(top_extended)
# View(top_extended)   # se estiver usando RStudio

write_xlsx(
  top_extended,
  "top5_ocupacoes_faixas_percentil_turismo_vs_nao_turismo.xlsx"
)
# Top-10 ocupações mais frequentes com freq% e salário médio
top_freq_pct <- pnad_Filtrada %>%
  # conta por ocupação em cada grupo
  group_by(turismo_dummy, nomes_ocupacao) %>%
  summarise(
    frequencia    = n(),
    salario_medio = mean(VD4016_Real, na.rm = TRUE),
    .groups = "drop_last"
  ) %>%
  # calcula % sobre o total de cada turismo_dummy
  group_by(turismo_dummy) %>%
  mutate(freq_pct = frequencia / sum(frequencia) * 100) %>%
  # seleciona top-10
  arrange(desc(frequencia)) %>%
  slice_head(n = 10) %>%
  ungroup()

View(top_freq_pct)

#  Top-10 ocupações com maiores salários médios, com freq%
top_salario_pct <- pnad_Filtrada %>%
  group_by(turismo_dummy, nomes_ocupacao) %>%
  summarise(
    salario_medio = mean(VD4016_Real, na.rm = TRUE),
    frequencia    = n(),
    .groups = "drop_last"
  ) %>%
  group_by(turismo_dummy) %>%
  mutate(freq_pct = frequencia / sum(frequencia) * 100) %>%
  arrange(desc(salario_medio)) %>%
  slice_head(n = 10) %>%
  ungroup()

View(top_salario_pct)

# Top-10 ocupações com menores salários médios, com freq%
bottom_salario_pct <- pnad_Filtrada %>%
  group_by(turismo_dummy, nomes_ocupacao) %>%
  summarise(
    salario_medio = mean(VD4016_Real, na.rm = TRUE),
    frequencia    = n(),
    .groups = "drop_last"
  ) %>%
  group_by(turismo_dummy) %>%
  mutate(freq_pct = frequencia / sum(frequencia) * 100) %>%
  arrange(salario_medio) %>%
  slice_head(n = 10) %>%
  ungroup()

View(bottom_salario_pct)

# Montando uma lista com nomes das abas e os respectivos data.frames
tabelas_para_excel <- list(
  Percentis            = top_extended,
  Top10_Frequentes     = top_freq_pct,
  Top10_MaioresSalarios= top_salario_pct,
  Top10_MenoresSalarios= bottom_salario_pct
)

# Escrevendo tudo em um único arquivo, cada elemento da lista vira uma aba
write_xlsx(tabelas_para_excel,
           path = "tabelas_salários ocupação_turismo_vs_naoturismo.xlsx")


## ANÁLISE DE MATCHING -----------------------------------------------------

### Análise de Matching Anos e Trimestres ---------------------------------------

# Carregando pacotes
library(Matching)
library(tableone)
library(writexl)
library(dplyr)
library(ggplot2)
library(tidyr) # Necessário para a função drop_na()


# Preparando dados
df <- pnad_Filtrada

# Convertendo as colunas de Ano e Trimestre para formato numérico
df <- df %>%
  mutate(
    Ano = as.numeric(as.character(Ano)),
    Trimestre = as.numeric(as.character(Trimestre))
  )

# Obtendo as combinações únicas de Ano e Trimestre para o loop
groups <- df %>% distinct(Ano, Trimestre) %>% arrange(Ano, Trimestre)
print(groups)

glimpse(df)

# Definindo as covariáveis para o modelo de propensity score
xvars <- c(
  "V2007_Mulher", "V2009", "V2010_grupo_PP",
  "V2005_recode_Pessoa_responsável", "V2005_recode_Cônjuge",
  "grupo_moradia_Coletivo", "VD3004_nivel_Escol_Fundamental_Completo",
  "VD3004_nivel_Escol_Médio_Completo", "VD3004_nivel_Escol_Superior_Completo",
  "Regiao_Nordeste", "Regiao_Norte",
  "Regiao_Sudeste", "Regiao_Sul", "V1023_recode3_Capital_e_Metropolitana",
  "V4029_Sim", "V4040_recode_Mais_de_2_anos", "V4039", "Horas_trabalhadas2_Integral",
  "V4025_Não"
)

# Função logit para transformar os escores
logit <- function(p) log(p/(1-p))

# Inicializando listas para armazenar os resultados de cada iteração
balance_list <- list()
ttest_list <- list()
pares_global <- list()
dados_salvos_para_analise_final <- list() # Lista para análise pós-loop


# Loop principal de matching por período
for (i in 1:nrow(groups)) {
  
  current_year <- groups$Ano[i]
  current_trimester <- groups$Trimestre[i]
  
  cat("Processando Ano =", current_year, "Trimestre =", current_trimester, "\n")
  
  # Filtra os dados para o período atual
  mydata_subset <- df %>% filter(Ano == current_year, Trimestre == current_trimester)
  
  # Remove explicitamente linhas com NAs nas variáveis do modelo para evitar erros
  mydata_subset_clean <- mydata_subset %>%
    drop_na(turismo_dummy, all_of(xvars))
  
  cat("Observações iniciais:", nrow(mydata_subset), " | Observações após limpeza de NAs:", nrow(mydata_subset_clean), "\n")
  
  
  
  # Estimando o propensity score
  formula <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
  psmodel <- glm(formula, family = binomial(), data = mydata_subset_clean)
  
  mydata_subset_clean$pscore <- psmodel$fitted.values
  mydata_subset_clean$pscore <- pmin(pmax(mydata_subset_clean$pscore, 1e-6), 1 - 1e-6)
  
  # Definindo e aplicando o common support
  pscore_t <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 1]
  pscore_c <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 0]
  min_common <- max(min(pscore_t), min(pscore_c))
  max_common <- min(max(pscore_t), max(pscore_c))
  
  mydata_subset_cs <- mydata_subset_clean %>%
    filter(pscore >= min_common & pscore <= max_common)
  
  cat("Observações dentro do common support:", nrow(mydata_subset_cs), "\n")
  
  # Realizando o matching
  psmatch <- Match(
    Tr = mydata_subset_cs$turismo_dummy,
    M = 1,
    X = log(mydata_subset_cs$pscore / (1 - mydata_subset_cs$pscore)),
    replace = FALSE,
    caliper = 0.2
  )
  
  # Avaliação de balanceamento (original)
  balance_check <- MatchBalance(formula, data = mydata_subset_cs, match.out = psmatch, nboots = 500)
  print(balance_check)
  
  # Selecionando os pares encontrados, removendo NAs de pares não formados
  indices_pareados <- unlist(psmatch[c("index.treated", "index.control")])
  indices_limpos <- na.omit(indices_pareados)
  matched <- mydata_subset_cs[indices_limpos, ]
  
  # Filtrando por Salario_Hora > 0
  matched <- matched %>% filter(Salario_Hora > 0)
  
  # Tabela de balanceamento pós-match (original)
  if (nrow(matched) > 0 && length(unique(matched$turismo_dummy)) > 1) {
    table1 <- CreateTableOne(vars = xvars, strata = "turismo_dummy", data = matched, test = FALSE)
    table1_df <- as.data.frame(print(table1, smd = TRUE))
    table1_df$Ano <- current_year
    table1_df$Trimestre <- current_trimester
    table1_df$Variable <- rownames(table1_df)
    
    filename_table <- paste0("matchedtab1_", current_year, "_", current_trimester, ".xlsx")
    write_xlsx(table1_df, filename_table)
    balance_list[[paste0("Balance_", current_year, "_", current_trimester)]] <- table1_df
  }
  
  # Analisando salários (original)
  y_trt <- matched$Salario_Hora[matched$turismo_dummy == 1]
  y_con <- matched$Salario_Hora[matched$turismo_dummy == 0]
  
  cat("Tamanho dos grupos pareados: Tratados =", length(y_trt), "Controles =", length(y_con), "\n")
  
  if (length(y_trt) == length(y_con) && length(y_trt) > 0) {
    diff_log <- log(y_trt) - log(y_con)
    t_test_result <- t.test(diff_log, mu = 0)
    
    media_perc <- (exp(mean(diff_log)) - 1) * 100
    
    t_test_df <- data.frame(
      Ano = current_year,
      Trimestre = current_trimester,
      Estatistica_t = t_test_result$statistic,
      Graus_de_Liberdade = t_test_result$parameter,
      p_valor = t_test_result$p.value,
      Media_diferenca_log = mean(diff_log),
      Media_diferenca_percentual_aprox = media_perc,
      Conf_Inf_Lower = t_test_result$conf.int[1],
      Conf_Inf_Upper = t_test_result$conf.int[2],
      Hipotese_Alternativa = t_test_result$alternative
    )
    
    filename_ttest <- paste0("t_test_result_", current_year, "_", current_trimester, ".xlsx")
    write_xlsx(t_test_df, filename_ttest)
    ttest_list[[paste0("TTest_", current_year, "_", current_trimester)]] <- t_test_df
    
    pares_df <- data.frame(
      Ano = current_year,
      Trimestre = current_trimester,
      salario_turismo = y_trt,
      salario_controle = y_con,
      diff_log = diff_log,
      diff_percentual_aprox = (exp(diff_log) - 1) * 100
    )
    
    pares_global[[paste0(current_year, "_T", current_trimester)]] <- pares_df
    
    # Gráfico de densidade do propensity score (original)
    df_plot <- mydata_subset_cs
    df_plot$logit_pscore <- log(df_plot$pscore / (1 - df_plot$pscore))
    df_plot$grupo <- ifelse(df_plot$turismo_dummy == 1, "Turismo (Tratado)", "Controle")
    
    caliper_limite <- 0.2
    media_t <- mean(df_plot$logit_pscore[df_plot$turismo_dummy == 1])
    lim_inf <- media_t - caliper_limite
    lim_sup <- media_t + caliper_limite
    
    g <- ggplot(df_plot, aes(x = logit_pscore, fill = grupo)) +
      geom_density(alpha = 0.4) +
      geom_vline(xintercept = c(lim_inf, lim_sup), linetype = "dashed", color = "red") +
      labs(
        title = paste("Distribuição do Logit do Propensity Score -", current_year, "T", current_trimester),
        x = "Logit do Propensity Score",
        y = "Densidade"
      ) +
      scale_fill_manual(values = c("Turismo (Tratado)" = "#1b9e77", "Controle" = "#d95f02")) +
      theme_minimal()
    
    print(g)
    filename_grafico <- paste0("logit_pscore_densidade_", current_year, "_T", current_trimester, ".png")
    ggsave(filename_grafico, plot = g, width = 9, height = 5)
    
  } else {
    cat("Não é possível realizar o teste t pareado para este grupo.\n")
  }
  
  # Salvando os dados necessários para a análise final
  if (exists("psmatch")) {
    dados_salvos_para_analise_final[[paste0(current_year, "_T", current_trimester)]] <- list(
      dados_com_pscore = mydata_subset_clean,
      dados_pos_cs = mydata_subset_cs,
      objeto_match = psmatch,
      variaveis_x = xvars
    )
  }
  
  cat("Processo concluído para Ano =", current_year, "Trimestre =", current_trimester, "\n\n")
  rm(mydata_subset, mydata_subset_clean, mydata_subset_cs, psmodel, psmatch, matched)
  gc()
}

# Análise pós-loop: Observações Excluídas e Gráficos SMD
cat("\n\nIniciando análises pós-execução (Contagem Common Support e Gráficos SMD)...\n")

lista_stats_cs_final <- list()

for (periodo in names(dados_salvos_para_analise_final)) {
  
  cat("Processando análises para o período:", periodo, "\n")
  
  # RecuperaNDO os dados salvos do loop principal
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_inicial_limpo <- dados_periodo$dados_com_pscore
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  
  # Funcionalidade 1: Contagem de Observações Excluídas --
  n_antes_cs <- nrow(df_inicial_limpo)
  n_depois_cs <- nrow(df_depois_cs)
  n_excluidas <- n_antes_cs - n_depois_cs
  
  stats_cs_df <- data.frame(
    Periodo = periodo,
    Obs_Iniciais_Limpas = n_antes_cs,
    Obs_Excluidas_CS = n_excluidas,
    Obs_Mantidas_CS = n_depois_cs,
    Perc_Excluido = round((n_excluidas / n_antes_cs) * 100, 2)
  )
  lista_stats_cs_final[[periodo]] <- stats_cs_df
  
  # Funcionalidade 2: Gráfico Comparativo de SMDs --
  
  contagem_grupos_cs <- table(df_depois_cs$turismo_dummy)
  if (length(contagem_grupos_cs) < 2 || any(contagem_grupos_cs == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos após o common support. Gráfico não será gerado.\n")
    next
  }
  
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  
  contagem_grupos_pareado <- table(df_pareado$turismo_dummy)
  if (length(contagem_grupos_pareado) < 2 || any(contagem_grupos_pareado == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos APÓS O MATCHING. Gráfico não será gerado.\n")
    next 
  }
  
  df_depois_cs$turismo_dummy <- as.factor(df_depois_cs$turismo_dummy)
  df_pareado$turismo_dummy <- as.factor(df_pareado$turismo_dummy)
  
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs), test = FALSE)
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado), test = FALSE)
  
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  smd_antes <- smd_df_antes[xvars_usadas, "SMD"]
  smd_depois <- smd_df_depois[xvars_usadas, "SMD"]
  names(smd_antes) <- xvars_usadas
  names(smd_depois) <- xvars_usadas
  
  df_smd_plot <- data.frame(
    Variable = names(smd_antes),
    SMD = c(smd_antes, smd_depois),
    Status = factor(rep(c("Antes do Pareamento", "Depois do Pareamento"), each = length(smd_antes)),
                    levels = c("Antes do Pareamento", "Depois do Pareamento"))
  )
  
  love_plot <- ggplot(df_smd_plot, aes(x = SMD, y = reorder(Variable, SMD), color = Status, shape = Status)) +
    geom_point(size = 3.5, alpha = 0.8) +
    geom_vline(xintercept = 0, linetype = "solid", color = "black") +
    geom_vline(xintercept = c(-0.1, 0.1), linetype = "dashed", color = "grey50") +
    labs(
      title = paste("Balanceamento das Covariáveis -", periodo),
      subtitle = "Diferença Média Padronizada (SMD)",
      x = "SMD",
      y = "Covariável",
      color = "Status",
      shape = "Status"
    ) +
    scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "blue")) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5), plot.subtitle = element_text(hjust = 0.5))
  
  filename_love_plot <- paste0("GRAFICO_SMD_LOVEPLOT_", gsub("T", "T", periodo), ".png")
  ggsave(filename_love_plot, plot = love_plot, width = 9, height = 10, dpi = 300)
  cat("Gráfico SMD salvo em:", filename_love_plot, "\n")
}

# Consolidação dos Resultados (Original e novos)
# Salvando a contagem de observações excluídas --
summary_common_support_final <- do.call(rbind, lista_stats_cs_final)
rownames(summary_common_support_final) <- NULL
print("-----------------------------------------------------------")
print("Resumo Final das Observações Excluídas no Common Support:")
print(summary_common_support_final)
write_xlsx(summary_common_support_final, "resumo_final_exclusoes_common_support.xlsx")
cat("\nResumo das exclusões salvo em: resumo_final_exclusoes_common_support.xlsx\n")


# Seção de análise original --
ttest_summary_df <- do.call(rbind, ttest_list) %>%
  arrange(Ano, Trimestre)
print(head(ttest_summary_df))
write_xlsx(ttest_summary_df, "resumo_t_test_log_por_ano_trimestre.xlsx")

df_global_pares <- do.call(rbind, pares_global)
write_xlsx(df_global_pares, "resultado_global_pares_log_2016_2024.xlsx")

teste_global <- t.test(df_global_pares$diff_log, mu = 0)
print(teste_global)

teste_global_df <- data.frame(
  Estatistica_t = teste_global$statistic,
  Graus_de_Liberdade = teste_global$parameter,
  p_valor = teste_global$p.value,
  Media_diferenca_log = mean(df_global_pares$diff_log),
  Media_diferenca_percentual_aprox = (exp(mean(df_global_pares$diff_log)) - 1) * 100,
  Conf_Inf_Lower = teste_global$conf.int[1],
  Conf_Inf_Upper = teste_global$conf.int[2],
  Hipotese_Alternativa = teste_global$alternative
)
write_xlsx(teste_global_df, "resultado_t_test_global_2016_2024.xlsx")

smd_summary_df <- do.call(rbind, balance_list)
smd_summary_df <- dplyr::select(smd_summary_df, Ano, Trimestre, Variable, SMD)
print(head(smd_summary_df))
write_xlsx(smd_summary_df, "resumo_balanceamento_smds_por_ano_trimestre.xlsx")

smd_resumo <- smd_summary_df %>%
  group_by(Ano, Trimestre) %>%
  summarise(Media_SMD = mean(as.numeric(SMD), na.rm = TRUE))

grafico_smd <- ggplot(smd_resumo, aes(x = interaction(Ano, Trimestre), y = Media_SMD)) +
  geom_line(group = 1) +
  geom_point() +
  labs(x = "Ano-Trimestre", y = "Média dos SMDs",
       title = "Evolução da Média dos SMDs após o Pareamento") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
print(grafico_smd)
ggsave("grafico_media_smds_anoetrimestre.png", plot = grafico_smd, width = 10, height = 6, dpi = 300)

ttest_summary_df <- ttest_summary_df %>%
  mutate(
    Ano_Trim = paste0(Ano, "T", Trimestre),
    significativo = ifelse(p_valor < 0.05, TRUE, FALSE)
  )

grafico_linha <- ggplot(ttest_summary_df, aes(x = Ano_Trim, y = Media_diferenca_percentual_aprox, group = 1)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(aes(color = significativo), size = 2.5) +
  scale_color_manual(values = c("FALSE" = "black", "TRUE" = "red")) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Diferença percentual média de salários (Turismo vs Outros)",
    subtitle = "Trimestres com p < 0.05 destacados em vermelho",
    x = "Ano e Trimestre",
    y = "Diferença percentual média (%)",
    color = "Significativo"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
print(grafico_linha)
ggsave("grafico_diferenca_percentual_por_trimestre.png", plot = grafico_linha, width = 10, height = 6, dpi = 300)

df_global_pares <- df_global_pares %>%
  mutate(Ano = as.factor(Ano))

grafico_boxplot <- ggplot(df_global_pares, aes(x = Ano, y = diff_log)) +
  geom_boxplot(fill = "lightblue", color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Distribuição da diferença logarítmica dos salários por ano",
    subtitle = "log(salário_turismo / salário_controle)",
    x = "Ano",
    y = "Diferença logarítmica"
  ) +
  theme_minimal()
ggsave("boxplot_diferenca_log_por_ano.png", plot = grafico_boxplot, width = 10, height = 6, dpi = 300)

ttest_summary_df <- ttest_summary_df %>%
  mutate(
    IC_inferior_perc = (exp(Conf_Inf_Lower) - 1) * 100,
    IC_superior_perc = (exp(Conf_Inf_Upper) - 1) * 100
  )

grafico_ic <- ggplot(ttest_summary_df, aes(x = Ano_Trim, y = Media_diferenca_percentual_aprox)) +
  geom_line(aes(group = 1), color = "steelblue", linewidth = 1) +
  geom_ribbon(aes(ymin = IC_inferior_perc, ymax = IC_superior_perc, group = 1),
              fill = "steelblue", alpha = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  labs(
    title = "Diferença Percentual Média de Salários por Trimestre",
    subtitle = "Com intervalo de confiança (95%)",
    x = "Ano e Trimestre",
    y = "Diferença percentual média (%)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    axis.title = element_text(face = "italic"),
    panel.grid.major = element_line(color = "gray90"),
    panel.background = element_rect(fill = "#f5f5f5", color = NA),
    plot.background = element_rect(fill = "#f5f5f5", color = NA)
  )
print(grafico_ic)
ggsave("grafico_ic_diferenca_percentual.png", plot = grafico_ic, width = 10, height = 6, dpi = 300)

balance_list_trimestre <- balance_list
ttest_list_trimestre <- ttest_list
pares_global_trimestre <- pares_global
ttest_summary_df_trimestre <- ttest_summary_df
df_global_pares_trimestre <- df_global_pares
smd_summary_df_trimestre <- smd_summary_df

calcular_ajuste_propensity <- function(dados, formula) {
  dados_limpos <- dados %>% drop_na(all_of(all.vars(formula)))
  
  psmodel <- glm(formula, family = binomial(), data = dados_limpos)
  
  nullmodel <- glm(as.formula(paste(all.vars(formula)[1], "~ 1")),
                   family = binomial(), data = dados_limpos)
  
  aic <- AIC(psmodel)
  bic <- BIC(psmodel)
  loglik <- as.numeric(logLik(psmodel))
  
  pseudo_r2 <- 1 - (logLik(psmodel) / logLik(nullmodel))
  
  resultados <- data.frame(
    AIC = round(aic, 2),
    BIC = round(bic, 2),
    LogLikelihood = round(loglik, 2),
    Pseudo_R2 = round(as.numeric(pseudo_r2), 4)
  )
  
  return(resultados)
}

formula_trimestre <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
resultado_ajuste_trimestre <- calcular_ajuste_propensity(pnad_Filtrada, formula_trimestre)
print(resultado_ajuste_trimestre)

cat("\n\n-- ANÁLISE COMPLETA FINALIZADA --\n")

# Gráfico SMDs antes e depois do pareamento
# Evolução da Média de SMD (Antes vs. Depois) ##

cat("\n\nGerando gráfico comparativo da evolução da média de SMD...\n")

# Inicializando uma lista para guardar as médias de SMD de cada período
smd_evolution_list <- list()

# Loop através dos dados já salvos para extrair as médias
for (periodo in names(dados_salvos_para_analise_final)) {
  
  # Recupera os dados do período
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  
  # Recria o dataframe pareado
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  
  # Pula se algum dos dataframes não tiver os dois grupos
  if (length(unique(df_depois_cs$turismo_dummy)) < 2 || length(unique(df_pareado$turismo_dummy)) < 2) {
    next
  }
  
  # Usa o método robusto para extrair os SMDs
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs))
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado))
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  # Calcula a média dos SMDs absolutos (a magnitude do desbalanceamento)
  media_smd_antes <- mean(abs(as.numeric(smd_df_antes[xvars_usadas, "SMD"])), na.rm = TRUE)
  media_smd_depois <- mean(abs(as.numeric(smd_df_depois[xvars_usadas, "SMD"])), na.rm = TRUE)
  
  # Guarda os resultados do período
  smd_evolution_list[[periodo]] <- data.frame(
    Periodo = periodo,
    Media_SMD_Antes = media_smd_antes,
    Media_SMD_Depois = media_smd_depois
  )
}

# Consolida e prepara os dados para o ggplot
# Une todos os dataframes da lista em um só
smd_evolution_df <- do.call(rbind, smd_evolution_list)

# Separa Ano e Trimestre para ordenação correta
smd_evolution_df <- smd_evolution_df %>%
  separate(Periodo, into = c("Ano", "Trimestre"), sep = "_T", remove = FALSE) %>%
  mutate(Ano = as.numeric(Ano), Trimestre = as.numeric(Trimestre)) %>%
  arrange(Ano, Trimestre) %>%
  # Garante que 'Periodo' seja um fator ordenado para o gráfico
  mutate(Periodo = factor(Periodo, levels = unique(Periodo)))

# Transforma o dataframe do formato "wide" para "long", ideal para o ggplot
smd_long_df <- smd_evolution_df %>%
  pivot_longer(
    cols = c("Media_SMD_Antes", "Media_SMD_Depois"),
    names_to = "Status",
    values_to = "Media_SMD"
  ) %>%
  # Renomeia as categorias para a legenda do gráfico
  mutate(Status = ifelse(Status == "Media_SMD_Antes", "Antes do Pareamento", "Depois do Pareamento"))


# Gera o gráfico final
grafico_smd_comparativo <- ggplot(smd_long_df, aes(x = Periodo, y = Media_SMD, group = Status, color = Status)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.5) +
  # Adiciona uma linha de referência (limite comum de balanceamento aceitável)
  geom_hline(yintercept = 0.1, linetype = "dashed", color = "red") +
  # Adiciona um texto explicando a linha de referência
  annotate("text", x = nrow(smd_evolution_df) - 2, y = 0.11, label = "Limite (SMD = 0.1)", color = "red", size = 3) +
  scale_y_continuous(labels = scales::number_format(accuracy = 0.01)) +
  scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "steelblue")) +
  labs(
    title = "Evolução da Média do SMD Absoluto",
    subtitle = "Comparativo Antes e Depois do Pareamento por Propensity Score",
    x = "Ano e Trimestre",
    y = "Média do SMD Absoluto",
    color = "Situação"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 10),
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5)
  )

# Exibe e salva o gráfico
print(grafico_smd_comparativo)
ggsave("grafico_smd_comparativo_evolucao.png", plot = grafico_smd_comparativo, width = 14, height = 8, dpi = 300)

cat("\nGráfico comparativo da evolução do SMD salvo como 'grafico_smd_comparativo_evolucao.png'\n")


# Preparação para comparação de modelos e ajuste
cat("\n\nPreparando objetos e calculando ajuste do modelo...\n")

balance_list_trimestre <- balance_list
ttest_list_trimestre <- ttest_list
pares_global_trimestre <- pares_global
ttest_summary_df_trimestre <- ttest_summary_df
df_global_pares_trimestre <- df_global_pares
smd_summary_df_trimestre <- smd_summary_df

# Função para calcular indicadores do modelo de propensity score
calcular_ajuste_propensity <- function(dados, formula) {
  
  # Remove NAs para garantir que os modelos sejam comparados nos mesmos dados
  dados_limpos <- dados %>% drop_na(all_of(all.vars(formula)))
  
  # Rodando modelo logit de propensity
  psmodel <- glm(formula, family = binomial(), data = dados_limpos)
  
  # Modelo nulo (apenas intercepto) para Pseudo R²
  nullmodel <- glm(as.formula(paste(all.vars(formula)[1], "~ 1")),
                   family = binomial(), data = dados_limpos)
  
  # Calculando métricas
  aic <- AIC(psmodel)
  bic <- BIC(psmodel)
  loglik <- as.numeric(logLik(psmodel))
  
  # Pseudo R² de McFadden
  pseudo_r2 <- 1 - (logLik(psmodel) / logLik(nullmodel))
  
  # Retornando resultados como data frame
  resultados <- data.frame(
    AIC = round(aic, 2),
    BIC = round(bic, 2),
    LogLikelihood = round(loglik, 2),
    Pseudo_R2 = round(as.numeric(pseudo_r2), 4)
  )
  
  return(resultados)
}

formula_trimestre <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
resultado_ajuste_trimestre <- calcular_ajuste_propensity(pnad_Filtrada, formula_trimestre)

print("--- Métricas de Ajuste do Modelo de Propensity Score (em toda a base) ---")
print(resultado_ajuste_trimestre)

# Salvando em Excel
write_xlsx(resultado_ajuste_trimestre, "metricas_ajuste_modelo_anoetrimestre.xlsx")
cat("\n\n-- ANÁLISE COMPLETA FINALIZADA --\n")


### Análise de Matching sem Trimestres - Apenas Anos ---------------------------------------

# Carregando pacotes
library(Matching)
library(tableone)
library(writexl)
library(dplyr)
library(ggplot2)
library(tidyr) # Necessário para a função drop_na()

# Preparando dados
df <- pnad_Filtrada

# Converte a coluna Ano para formato numérico
df <- df %>%
  mutate(Ano = as.numeric(as.character(Ano)))

# Obtém os anos únicos para o loop
groups <- df %>% distinct(Ano) %>% arrange(Ano)
print(groups)

# Define as covariáveis para o modelo de propensão
xvars <- c(
  "V2007_Mulher", "V2009", "V2010_grupo_PP",
  "V2005_recode_Pessoa_responsável", "V2005_recode_Cônjuge",
  "grupo_moradia_Coletivo", "VD3004_nivel_Escol_Fundamental_Completo",
  "VD3004_nivel_Escol_Médio_Completo", "VD3004_nivel_Escol_Superior_Completo",
  "Regiao_Nordeste", "Regiao_Norte",
  "Regiao_Sudeste", "Regiao_Sul", "V1023_recode3_Capital_e_Metropolitana",
  "V4029_Sim", "V4040_recode_Mais_de_2_anos", "V4039", "Horas_trabalhadas2_Integral",
  "V4025_Não"
)

# Inicializa listas para armazenar os resultados de cada iteração
balance_list <- list()
ttest_list <- list()
pares_global <- list()
dados_salvos_para_analise_final <- list() # Lista para análise pós-loop


# Loop principal de Matching por ano
for (i in 1:nrow(groups)) {
  
  current_year <- groups$Ano[i]
  
  cat("Processando Ano =", current_year, "\n")
  
  # Filtra os dados para o ano atual
  mydata_subset <- df %>% filter(Ano == current_year)
  
  # Remove explicitamente linhas com NAs nas variáveis do modelo para evitar erros
  mydata_subset_clean <- mydata_subset %>%
    drop_na(turismo_dummy, all_of(xvars))
  
  cat("Observações iniciais:", nrow(mydata_subset), " | Observações após limpeza de NAs:", nrow(mydata_subset_clean), "\n")
  
  
  
  # Estima o propensity score
  formula <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
  psmodel <- glm(formula, family = binomial(), data = mydata_subset_clean)
  
  mydata_subset_clean$pscore <- psmodel$fitted.values
  mydata_subset_clean$pscore <- pmin(pmax(mydata_subset_clean$pscore, 1e-6), 1 - 1e-6)
  
  # Define e aplica o common support
  pscore_t <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 1]
  pscore_c <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 0]
  min_common <- max(min(pscore_t), min(pscore_c))
  max_common <- min(max(pscore_t), max(pscore_c))
  
  mydata_subset_cs <- mydata_subset_clean %>%
    filter(pscore >= min_common & pscore <= max_common)
  
  cat("Observações dentro do common support:", nrow(mydata_subset_cs), "\n")
  
  # Realiza o matching
  psmatch <- Match(
    Tr = mydata_subset_cs$turismo_dummy,
    M = 1,
    X = log(mydata_subset_cs$pscore / (1 - mydata_subset_cs$pscore)),
    replace = FALSE,
    caliper = 0.2
  )
  
  # Avaliação de balanceamento (original)
  balance_check <- MatchBalance(formula, data = mydata_subset_cs, match.out = psmatch, nboots = 500)
  print(balance_check)
  
  # Seleciona os pares encontrados, removendo NAs de pares não formados
  indices_pareados <- unlist(psmatch[c("index.treated", "index.control")])
  indices_limpos <- na.omit(indices_pareados)
  matched <- mydata_subset_cs[indices_limpos, ]
  
  # Filtra por Salario_Hora > 0
  matched <- matched %>% filter(Salario_Hora > 0)
  
  # Tabela de balanceamento pós-match (original)
  if (nrow(matched) > 0 && length(unique(matched$turismo_dummy)) > 1) {
    table1 <- CreateTableOne(vars = xvars, strata = "turismo_dummy", data = matched, test = FALSE)
    table1_df <- as.data.frame(print(table1, smd = TRUE))
    table1_df$Ano <- current_year
    table1_df$Variable <- rownames(table1_df)
    
    filename_table <- paste0("matchedtab1_ano_", current_year, ".xlsx")
    write_xlsx(table1_df, filename_table)
    balance_list[[as.character(current_year)]] <- table1_df
  }
  
  # Análise de salários (original)
  y_trt <- matched$Salario_Hora[matched$turismo_dummy == 1]
  y_con <- matched$Salario_Hora[matched$turismo_dummy == 0]
  
  cat("Tamanho dos grupos pareados: Tratados =", length(y_trt), "Controles =", length(y_con), "\n")
  
  if (length(y_trt) == length(y_con) && length(y_trt) > 0) {
    diff_log <- log(y_trt) - log(y_con)
    t_test_result <- t.test(diff_log, mu = 0)
    
    media_perc <- (exp(mean(diff_log)) - 1) * 100
    
    t_test_df <- data.frame(
      Ano = current_year,
      Estatistica_t = t_test_result$statistic,
      Graus_de_Liberdade = t_test_result$parameter,
      p_valor = t_test_result$p.value,
      Media_diferenca_log = mean(diff_log),
      Media_diferenca_percentual_aprox = media_perc,
      Conf_Inf_Lower = t_test_result$conf.int[1],
      Conf_Inf_Upper = t_test_result$conf.int[2],
      Hipotese_Alternativa = t_test_result$alternative
    )
    
    filename_ttest <- paste0("t_test_result_ano_", current_year, ".xlsx")
    write_xlsx(t_test_df, filename_ttest)
    ttest_list[[as.character(current_year)]] <- t_test_df
    
    pares_df <- data.frame(
      Ano = current_year,
      salario_turismo = y_trt,
      salario_controle = y_con,
      diff_log = diff_log,
      diff_percentual_aprox = (exp(diff_log) - 1) * 100
    )
    
    pares_global[[as.character(current_year)]] <- pares_df
    
    # Gráfico de densidade do propensity score 
    df_plot <- mydata_subset_cs
    df_plot$logit_pscore <- log(df_plot$pscore / (1 - df_plot$pscore))
    df_plot$grupo <- ifelse(df_plot$turismo_dummy == 1, "Turismo (Tratado)", "Controle")
    
    # Código para calcular os limites do caliper adicionado novamente
    caliper_limite <- 0.2
    media_t <- mean(df_plot$logit_pscore[df_plot$turismo_dummy == 1], na.rm = TRUE)
    lim_inf <- media_t - caliper_limite
    lim_sup <- media_t + caliper_limite
    
    g <- ggplot(df_plot, aes(x = logit_pscore, fill = grupo)) +
      geom_density(alpha = 0.4) +
      # Linha para desenhar os limites do caliper adicionada novamente
      geom_vline(xintercept = c(lim_inf, lim_sup), linetype = "dashed", color = "red") +
      labs(
        title = paste("Distribuição do Logit do Propensity Score -", current_year),
        x = "Logit do Propensity Score",
        y = "Densidade"
      ) +
      scale_fill_manual(values = c("Turismo (Tratado)" = "#1b9e77", "Controle" = "#d95f02")) +
      theme_minimal()
    
    print(g)
    filename_grafico <- paste0("logit_pscore_densidade_ano_", current_year, ".png")
    ggsave(filename_grafico, plot = g, width = 9, height = 5)
    
  } else {
    cat("Não é possível realizar o teste t pareado para este grupo.\n")
  }
  
  # Salvando os dados necessários para a análise final
  if (exists("psmatch")) {
    dados_salvos_para_analise_final[[as.character(current_year)]] <- list(
      dados_com_pscore = mydata_subset_clean,
      dados_pos_cs = mydata_subset_cs,
      objeto_match = psmatch,
      variaveis_x = xvars
    )
  }
  
  cat("Processo concluído para Ano =", current_year, "\n\n")
  rm(mydata_subset, mydata_subset_clean, mydata_subset_cs, psmodel, psmatch, matched)
  gc()
}

# Análise pós-loop: Observações excluídas e gráficosSMD
cat("\n\nIniciando análises pós-execução (Contagem Common Support e Gráficos SMD)...\n")

lista_stats_cs_final <- list()

for (periodo in names(dados_salvos_para_analise_final)) {
  
  cat("Processando análises para o período:", periodo, "\n")
  
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_inicial_limpo <- dados_periodo$dados_com_pscore
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  
  # Funcionalidade 1: Contagem de Observações Excluídas --
  n_antes_cs <- nrow(df_inicial_limpo)
  n_depois_cs <- nrow(df_depois_cs)
  n_excluidas <- n_antes_cs - n_depois_cs
  
  stats_cs_df <- data.frame(
    Periodo = periodo,
    Obs_Iniciais_Limpas = n_antes_cs,
    Obs_Excluidas_CS = n_excluidas,
    Obs_Mantidas_CS = n_depois_cs,
    Perc_Excluido = round((n_excluidas / n_antes_cs) * 100, 2)
  )
  lista_stats_cs_final[[periodo]] <- stats_cs_df
  
  # Funcionalidade 2: Gráfico Comparativo de SMDs --
  
  contagem_grupos_cs <- table(df_depois_cs$turismo_dummy)
  if (length(contagem_grupos_cs) < 2 || any(contagem_grupos_cs == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos após o common support. Gráfico não será gerado.\n")
    next
  }
  
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  
  contagem_grupos_pareado <- table(df_pareado$turismo_dummy)
  if (length(contagem_grupos_pareado) < 2 || any(contagem_grupos_pareado == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos APÓS O MATCHING. Gráfico não será gerado.\n")
    next 
  }
  
  df_depois_cs$turismo_dummy <- as.factor(df_depois_cs$turismo_dummy)
  df_pareado$turismo_dummy <- as.factor(df_pareado$turismo_dummy)
  
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs), test = FALSE)
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado), test = FALSE)
  
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  smd_antes <- smd_df_antes[xvars_usadas, "SMD"]
  smd_depois <- smd_df_depois[xvars_usadas, "SMD"]
  names(smd_antes) <- xvars_usadas
  names(smd_depois) <- xvars_usadas
  
  df_smd_plot <- data.frame(
    Variable = names(smd_antes),
    SMD = c(smd_antes, smd_depois),
    Status = factor(rep(c("Antes do Pareamento", "Depois do Pareamento"), each = length(smd_antes)),
                    levels = c("Antes do Pareamento", "Depois do Pareamento"))
  )
  
  love_plot <- ggplot(df_smd_plot, aes(x = SMD, y = reorder(Variable, SMD), color = Status, shape = Status)) +
    geom_point(size = 3.5, alpha = 0.8) +
    geom_vline(xintercept = 0, linetype = "solid", color = "black") +
    geom_vline(xintercept = c(-0.1, 0.1), linetype = "dashed", color = "grey50") +
    labs(
      title = paste("Balanceamento das Covariáveis - Ano", periodo),
      subtitle = "Diferença Média Padronizada (SMD)",
      x = "SMD",
      y = "Covariável",
      color = "Status",
      shape = "Status"
    ) +
    scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "blue")) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5), plot.subtitle = element_text(hjust = 0.5))
  
  filename_love_plot <- paste0("GRAFICO_SMD_LOVEPLOT_ano_", periodo, ".png")
  ggsave(filename_love_plot, plot = love_plot, width = 9, height = 10, dpi = 300)
  cat("Gráfico SMD salvo em:", filename_love_plot, "\n")
}

# Consolidando os resultados
# Salvando a contagem de observações excluídas --
summary_common_support_final <- do.call(rbind, lista_stats_cs_final)
rownames(summary_common_support_final) <- NULL
print("-----------------------------------------------------------")
print("Resumo Final das Observações Excluídas no Common Support (por Ano):")
print(summary_common_support_final)
write_xlsx(summary_common_support_final, "resumo_final_exclusoes_common_support_ano.xlsx")
cat("\nResumo das exclusões salvo em: resumo_final_exclusoes_common_support_ano.xlsx\n")

# Gráfico de Evolução da Média de SMDs por Ano 

smd_evolution_list <- list()
for (periodo in names(dados_salvos_para_analise_final)) {
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  if (length(unique(df_depois_cs$turismo_dummy)) < 2 || length(unique(df_pareado$turismo_dummy)) < 2) next
  
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs))
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado))
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  media_smd_antes <- mean(abs(as.numeric(smd_df_antes[xvars_usadas, "SMD"])), na.rm = TRUE)
  media_smd_depois <- mean(abs(as.numeric(smd_df_depois[xvars_usadas, "SMD"])), na.rm = TRUE)
  
  smd_evolution_list[[periodo]] <- data.frame(Ano = as.numeric(periodo), Media_SMD_Antes = media_smd_antes, Media_SMD_Depois = media_smd_depois)
}
smd_evolution_df <- do.call(rbind, smd_evolution_list) %>% arrange(Ano)
smd_long_df <- smd_evolution_df %>%
  pivot_longer(cols = c("Media_SMD_Antes", "Media_SMD_Depois"), names_to = "Status", values_to = "Media_SMD") %>%
  mutate(Status = ifelse(Status == "Media_SMD_Antes", "Antes do Pareamento", "Depois do Pareamento"))

grafico_smd_comparativo_ano <- ggplot(smd_long_df, aes(x = Ano, y = Media_SMD, group = Status, color = Status)) +
  geom_line(linewidth = 1.2) + 
  geom_point(size = 2.5) +
  geom_hline(yintercept = 0.1, linetype = "dashed", color = "red") +
  annotate("text", x = max(smd_evolution_df$Ano) - 0.5, y = 0.11, label = "Limite (SMD = 0.1)", color = "red", size = 3.5) +
  
  # Adicionando a paleta de cores manual para consistência
  scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "steelblue")) +
  
  scale_x_continuous(breaks = scales::pretty_breaks()) +
  labs(
    title = "Evolução da Média do SMD Absoluto por Ano", 
    subtitle = "Antes e Depois do Pareamento", 
    x = "Ano", 
    y = "Média do SMD Absoluto", 
    color = "Situação"
  ) +
  theme_minimal(base_size = 14) + 
  theme(
    legend.position = "bottom", 
    plot.title = element_text(hjust = 0.5, face = "bold"), 
    plot.subtitle = element_text(hjust = 0.5)
  )

print(grafico_smd_comparativo_ano)
ggsave("grafico_smd_comparativo_evolucao_ano.png", plot = grafico_smd_comparativo_ano, width = 12, height = 7, dpi = 300)

# Início da sua seção de análise original --
ttest_summary_df <- do.call(rbind, ttest_list) %>% arrange(Ano)
print(head(ttest_summary_df))
write_xlsx(ttest_summary_df, "resumo_t_test_log_por_ano.xlsx")

df_global_pares <- do.call(rbind, pares_global)
write_xlsx(df_global_pares, "resultado_global_pares_log_por_ano.xlsx")

teste_global <- t.test(df_global_pares$diff_log, mu = 0)
print(teste_global)

teste_global_df <- data.frame(
  Estatistica_t = teste_global$statistic,
  Graus_de_Liberdade = teste_global$parameter,
  p_valor = teste_global$p.value,
  Media_diferenca_log = mean(df_global_pares$diff_log),
  Media_diferenca_percentual_aprox = (exp(mean(df_global_pares$diff_log)) - 1) * 100,
  Conf_Inf_Lower = teste_global$conf.int[1],
  Conf_Inf_Upper = teste_global$conf.int[2],
  Hipotese_Alternativa = teste_global$alternative
)
write_xlsx(teste_global_df, "resultado_t_test_global_por_ano.xlsx")

smd_summary_df <- do.call(rbind, balance_list)
smd_summary_df <- dplyr::select(smd_summary_df, Ano, Variable, SMD)
print(head(smd_summary_df))
write_xlsx(smd_summary_df, "resumo_balanceamento_smds_por_ano.xlsx")

ttest_summary_df <- ttest_summary_df %>%
  mutate(
    significativo = ifelse(p_valor < 0.05, TRUE, FALSE)
  )

grafico_linha <- ggplot(ttest_summary_df, aes(x = as.factor(Ano), y = Media_diferenca_percentual_aprox, group = 1)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(aes(color = significativo), size = 2.5) +
  scale_color_manual(values = c("FALSE" = "black", "TRUE" = "red")) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(title = "Diferença percentual média de salários por Ano", x = "Ano", y = "Diferença percentual média (%)", color = "Significativo (p < 0.05)") +
  theme_minimal()
print(grafico_linha)
ggsave("grafico_diferenca_percentual_por_ano.png", plot = grafico_linha, width = 10, height = 6, dpi = 300)

ttest_summary_df <- ttest_summary_df %>%
  mutate(
    IC_inferior_perc = (exp(Conf_Inf_Lower) - 1) * 100,
    IC_superior_perc = (exp(Conf_Inf_Upper) - 1) * 100
  )

grafico_ic <- ggplot(ttest_summary_df, aes(x = as.factor(Ano), y = Media_diferenca_percentual_aprox, group = 1)) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_ribbon(aes(ymin = IC_inferior_perc, ymax = IC_superior_perc), fill = "steelblue", alpha = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  labs(title = "Diferença Percentual Média de Salários por Ano com IC (95%)", x = "Ano", y = "Diferença percentual média (%)") +
  theme_minimal()
print(grafico_ic)
ggsave("grafico_ic_diferenca_percentual_por_ano.png", plot = grafico_ic, width = 10, height = 6, dpi = 300)

df_global_pares <- df_global_pares %>%
  mutate(Ano = as.factor(Ano))

grafico_boxplot <- ggplot(df_global_pares, aes(x = Ano, y = diff_log)) +
  geom_boxplot(fill = "lightblue", color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(title = "Distribuição da diferença logarítmica dos salários por ano", x = "Ano", y = "Diferença logarítmica") +
  theme_minimal()
print(grafico_boxplot)
ggsave("boxplot_diferenca_log_por_ano.png", plot = grafico_boxplot, width = 10, height = 6, dpi = 300)


# Preparando para comparanção de modelos e ajuste
cat("\n\nPreparando objetos e calculando ajuste do modelo...\n")

balance_list_ano <- balance_list
ttest_list_ano <- ttest_list
pares_global_ano <- pares_global
ttest_summary_df_ano <- ttest_summary_df
df_global_pares_ano <- df_global_pares
smd_summary_df_ano <- smd_summary_df

calcular_ajuste_propensity <- function(dados, formula) {
  dados_limpos <- dados %>% drop_na(all_of(all.vars(formula)))
  
  psmodel <- glm(formula, family = binomial(), data = dados_limpos)
  nullmodel <- glm(as.formula(paste(all.vars(formula)[1], "~ 1")), family = binomial(), data = dados_limpos)
  
  aic <- AIC(psmodel)
  bic <- BIC(psmodel)
  loglik <- as.numeric(logLik(psmodel))
  pseudo_r2 <- 1 - (logLik(psmodel) / logLik(nullmodel))
  
  resultados <- data.frame(
    AIC = round(aic, 2),
    BIC = round(bic, 2),
    LogLikelihood = round(loglik, 2),
    Pseudo_R2 = round(as.numeric(pseudo_r2), 4)
  )
  return(resultados)
}

formula_ano <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
resultado_ajuste_ano <- calcular_ajuste_propensity(pnad_Filtrada, formula_ano)

print("--- Métricas de Ajuste do Modelo de Propensity Score (Modelo por Ano) ---")
print(resultado_ajuste_ano)

# Adicionando para salvar em excel
write_xlsx(resultado_ajuste_ano, "metricas_ajuste_modelo_ano.xlsx")


cat("\n\n-- ANÁLISE COMPLETA FINALIZADA --\n")


### Análise de Matching com Períodos da Pandemia ---------------------------------------

# Carregando pacotes
library(Matching)
library(tableone)
library(writexl)
library(dplyr)
library(ggplot2)
library(tidyr) # Necessário para a função drop_na()

# Preparando dados
df <- pnad_Filtrada

# Garante que a variável Pandemia seja um fator com a ordem correta
df <- df %>%
  mutate(Pandemia = factor(Pandemia, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia")))

# Obtendo os períodos únicos da pandemia para o loop
groups <- df %>% distinct(Pandemia) %>% arrange(Pandemia)
print(groups)

# Define as covariáveis para o modelo de propensão
xvars <- c(
  "V2007_Mulher", "V2009", "V2010_grupo_PP",
  "V2005_recode_Pessoa_responsável", "V2005_recode_Cônjuge",
  "grupo_moradia_Coletivo", "VD3004_nivel_Escol_Fundamental_Completo",
  "VD3004_nivel_Escol_Médio_Completo", "VD3004_nivel_Escol_Superior_Completo",
  "Regiao_Nordeste", "Regiao_Norte",
  "Regiao_Sudeste", "Regiao_Sul", "V1023_recode3_Capital_e_Metropolitana",
  "V4029_Sim", "V4040_recode_Mais_de_2_anos", "V4039", "Horas_trabalhadas2_Integral",
  "V4025_Não"
)

# Inicializa listas para armazenar os resultados de cada iteração
balance_list <- list()
ttest_list <- list()
pares_global <- list()
dados_salvos_para_analise_final <- list() # Lista para análise pós-loop


# Loop principal de Matching por períodos da pandemia
for (i in 1:nrow(groups)) {
  
  current_period <- as.character(groups$Pandemia[i])
  
  cat("Processando Período da Pandemia =", current_period, "\n")
  
  # Filtra os dados para o período atual
  mydata_subset <- df %>% filter(Pandemia == current_period)
  
  # Remove explicitamente linhas com NAs nas variáveis do modelo para evitar erros
  mydata_subset_clean <- mydata_subset %>%
    drop_na(turismo_dummy, all_of(xvars))
  
  cat("Observações iniciais:", nrow(mydata_subset), " | Observações após limpeza de NAs:", nrow(mydata_subset_clean), "\n")
  
  
  
  # Estima o propensity score
  formula <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
  psmodel <- glm(formula, family = binomial(), data = mydata_subset_clean)
  
  mydata_subset_clean$pscore <- psmodel$fitted.values
  mydata_subset_clean$pscore <- pmin(pmax(mydata_subset_clean$pscore, 1e-6), 1 - 1e-6)
  
  # Define e aplica o common support
  pscore_t <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 1]
  pscore_c <- mydata_subset_clean$pscore[mydata_subset_clean$turismo_dummy == 0]
  min_common <- max(min(pscore_t), min(pscore_c))
  max_common <- min(max(pscore_t), max(pscore_c))
  
  mydata_subset_cs <- mydata_subset_clean %>%
    filter(pscore >= min_common & pscore <= max_common)
  
  cat("Observações dentro do common support:", nrow(mydata_subset_cs), "\n")
  
  # Realiza o matching
  psmatch <- Match(
    Tr = mydata_subset_cs$turismo_dummy,
    M = 1,
    X = log(mydata_subset_cs$pscore / (1 - mydata_subset_cs$pscore)),
    replace = FALSE,
    caliper = 0.2
  )
  
  # Avaliação de balanceamento (original)
  balance_check <- MatchBalance(formula, data = mydata_subset_cs, match.out = psmatch, nboots = 500)
  print(balance_check)
  
  # Seleciona os pares encontrados, removendo NAs de pares não formados
  indices_pareados <- unlist(psmatch[c("index.treated", "index.control")])
  indices_limpos <- na.omit(indices_pareados)
  matched <- mydata_subset_cs[indices_limpos, ]
  
  # Filtra por Salario_Hora > 0
  matched <- matched %>% filter(Salario_Hora > 0)
  
  # Tabela de balanceamento pós-match (original)
  if (nrow(matched) > 0 && length(unique(matched$turismo_dummy)) > 1) {
    table1 <- CreateTableOne(vars = xvars, strata = "turismo_dummy", data = matched, test = FALSE)
    table1_df <- as.data.frame(print(table1, smd = TRUE))
    table1_df$Pandemia <- current_period
    table1_df$Variable <- rownames(table1_df)
    
    filename_table <- paste0("matchedtab1_pandemia_", current_period, ".xlsx")
    write_xlsx(table1_df, filename_table)
    balance_list[[current_period]] <- table1_df
  }
  
  # Análise de salários (original)
  y_trt <- matched$Salario_Hora[matched$turismo_dummy == 1]
  y_con <- matched$Salario_Hora[matched$turismo_dummy == 0]
  
  cat("Tamanho dos grupos pareados: Tratados =", length(y_trt), "Controles =", length(y_con), "\n")
  
  if (length(y_trt) == length(y_con) && length(y_trt) > 0) {
    diff_log <- log(y_trt) - log(y_con)
    t_test_result <- t.test(diff_log, mu = 0)
    
    media_perc <- (exp(mean(diff_log)) - 1) * 100
    
    t_test_df <- data.frame(
      Pandemia = current_period,
      Estatistica_t = t_test_result$statistic,
      Graus_de_Liberdade = t_test_result$parameter,
      p_valor = t_test_result$p.value,
      Media_diferenca_log = mean(diff_log),
      Media_diferenca_percentual_aprox = media_perc,
      Conf_Inf_Lower = t_test_result$conf.int[1],
      Conf_Inf_Upper = t_test_result$conf.int[2],
      Hipotese_Alternativa = t_test_result$alternative
    )
    
    filename_ttest <- paste0("t_test_result_pandemia_", current_period, ".xlsx")
    write_xlsx(t_test_df, filename_ttest)
    ttest_list[[current_period]] <- t_test_df
    
    pares_df <- data.frame(
      Pandemia = current_period,
      salario_turismo = y_trt,
      salario_controle = y_con,
      diff_log = diff_log,
      diff_percentual_aprox = (exp(diff_log) - 1) * 100
    )
    
    pares_global[[current_period]] <- pares_df
    
    # Gráfico de densidade do propensity score (CORRIGIDO)
    df_plot <- mydata_subset_cs
    df_plot$logit_pscore <- log(df_plot$pscore / (1 - df_plot$pscore))
    df_plot$grupo <- ifelse(df_plot$turismo_dummy == 1, "Turismo (Tratado)", "Controle")
    
    # Adicionando Cálculo do caliper para as linhas pontilhadas
    caliper_limite <- 0.2
    media_t <- mean(df_plot$logit_pscore[df_plot$turismo_dummy == 1], na.rm = TRUE)
    lim_inf <- media_t - caliper_limite
    lim_sup <- media_t + caliper_limite
    
    g <- ggplot(df_plot, aes(x = logit_pscore, fill = grupo)) +
      geom_density(alpha = 0.4) +
      # ADICIONADO: Camada para desenhar as linhas do caliper
      geom_vline(xintercept = c(lim_inf, lim_sup), linetype = "dashed", color = "red") +
      labs(
        title = paste("Distribuição do Logit do Propensity Score -", current_period),
        x = "Logit do Propensity Score",
        y = "Densidade"
      ) +
      scale_fill_manual(values = c("Turismo (Tratado)" = "#1b9e77", "Controle" = "#d95f02")) +
      theme_minimal()
    
    print(g)
    filename_grafico <- paste0("logit_pscore_densidade_pandemia_", current_period, ".png")
    ggsave(filename_grafico, plot = g, width = 9, height = 5)
    
  } else {
    cat("Não é possível realizar o teste t pareado para este grupo.\n")
  }
  
  # Salva os dados necessários para a análise final
  if (exists("psmatch")) {
    dados_salvos_para_analise_final[[current_period]] <- list(
      dados_com_pscore = mydata_subset_clean,
      dados_pos_cs = mydata_subset_cs,
      objeto_match = psmatch,
      variaveis_x = xvars
    )
  }
  
  cat("Processo concluído para o período =", current_period, "\n\n")
  rm(mydata_subset, mydata_subset_clean, mydata_subset_cs, psmodel, psmatch, matched)
  gc()
}



# Análise de pós-loop: Observações excluídas e gráficos SMD
cat("\n\nIniciando análises pós-execução (Contagem Common Support e Gráficos SMD)...\n")

lista_stats_cs_final <- list()

for (periodo in names(dados_salvos_para_analise_final)) {
  
  cat("Processando análises para o período:", periodo, "\n")
  
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_inicial_limpo <- dados_periodo$dados_com_pscore
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  
  # Funcionalidade 1: Contagem de Observações Excluídas --
  n_antes_cs <- nrow(df_inicial_limpo)
  n_depois_cs <- nrow(df_depois_cs)
  n_excluidas <- n_antes_cs - n_depois_cs
  
  stats_cs_df <- data.frame(
    Periodo = periodo,
    Obs_Iniciais_Limpas = n_antes_cs,
    Obs_Excluidas_CS = n_excluidas,
    Obs_Mantidas_CS = n_depois_cs,
    Perc_Excluido = round((n_excluidas / n_antes_cs) * 100, 2)
  )
  lista_stats_cs_final[[periodo]] <- stats_cs_df
  
  # Funcionalidade 2: Gráfico Comparativo de SMDs --
  
  contagem_grupos_cs <- table(df_depois_cs$turismo_dummy)
  if (length(contagem_grupos_cs) < 2 || any(contagem_grupos_cs == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos após o common support. Gráfico não será gerado.\n")
    next
  }
  
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  
  contagem_grupos_pareado <- table(df_pareado$turismo_dummy)
  if (length(contagem_grupos_pareado) < 2 || any(contagem_grupos_pareado == 0)) {
    cat("--- AVISO: Período:", periodo, "não possui ambos os grupos APÓS O MATCHING. Gráfico não será gerado.\n")
    next 
  }
  
  df_depois_cs$turismo_dummy <- as.factor(df_depois_cs$turismo_dummy)
  df_pareado$turismo_dummy <- as.factor(df_pareado$turismo_dummy)
  
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs), test = FALSE)
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado), test = FALSE)
  
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  smd_antes <- smd_df_antes[xvars_usadas, "SMD"]
  smd_depois <- smd_df_depois[xvars_usadas, "SMD"]
  names(smd_antes) <- xvars_usadas
  names(smd_depois) <- xvars_usadas
  
  df_smd_plot <- data.frame(
    Variable = names(smd_antes),
    SMD = c(smd_antes, smd_depois),
    Status = factor(rep(c("Antes do Pareamento", "Depois do Pareamento"), each = length(smd_antes)),
                    levels = c("Antes do Pareamento", "Depois do Pareamento"))
  )
  
  love_plot <- ggplot(df_smd_plot, aes(x = SMD, y = reorder(Variable, SMD), color = Status, shape = Status)) +
    geom_point(size = 3.5, alpha = 0.8) +
    geom_vline(xintercept = 0, linetype = "solid", color = "black") +
    geom_vline(xintercept = c(-0.1, 0.1), linetype = "dashed", color = "grey50") +
    labs(
      title = paste("Balanceamento das Covariáveis -", periodo),
      subtitle = "Diferença Média Padronizada (SMD)",
      x = "SMD",
      y = "Covariável",
      color = "Status",
      shape = "Status"
    ) +
    scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "blue")) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5), plot.subtitle = element_text(hjust = 0.5))
  
  filename_love_plot <- paste0("GRAFICO_SMD_LOVEPLOT_pandemia_", periodo, ".png")
  ggsave(filename_love_plot, plot = love_plot, width = 9, height = 10, dpi = 300)
  cat("Gráfico SMD salvo em:", filename_love_plot, "\n")
}

# Conslidação dos resultados
# Salva a contagem de observações excluídas --
summary_common_support_final <- do.call(rbind, lista_stats_cs_final)
rownames(summary_common_support_final) <- NULL
print("-----------------------------------------------------------")
print("Resumo Final das Observações Excluídas no Common Support (por Período Pandêmico):")
print(summary_common_support_final)
write_xlsx(summary_common_support_final, "resumo_final_exclusoes_common_support_pandemia.xlsx")
cat("\nResumo das exclusões salvo em: resumo_final_exclusoes_common_support_pandemia.xlsx\n")

# Gráfico de Barras da Média de SMDs por Período da Pandemia --
smd_evolution_list <- list()
for (periodo in names(dados_salvos_para_analise_final)) 
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
df_depois_cs <- dados_periodo$dados_pos_cs
match_salvo <- dados_periodo$objeto_match
xvars_usadas <- dados_periodo$variaveis_x
indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
indices_limpos <- na.omit(indices_pareados)
df_pareado <- df_depois_cs[indices_limpos, ]
if (length(unique(df_depois_cs$turismo_dummy)) < 2 || length(unique(df_pareado$turismo_dummy)) < 2) next

tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs))
tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado))
smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))

media_smd_antes <- mean(abs(as.numeric(smd_df_antes[xvars_usadas, "SMD"])), na.rm = TRUE)
media_smd_depois <- mean(abs(as.numeric(smd_df_depois[xvars_usadas, "SMD"])), na.rm = TRUE)

smd_evolution_list <- list()
for (periodo in names(dados_salvos_para_analise_final)) {
  dados_periodo <- dados_salvos_para_analise_final[[periodo]]
  df_depois_cs <- dados_periodo$dados_pos_cs
  match_salvo <- dados_periodo$objeto_match
  xvars_usadas <- dados_periodo$variaveis_x
  indices_pareados <- c(match_salvo$index.treated, match_salvo$index.control)
  indices_limpos <- na.omit(indices_pareados)
  df_pareado <- df_depois_cs[indices_limpos, ]
  if (length(unique(df_depois_cs$turismo_dummy)) < 2 || length(unique(df_pareado$turismo_dummy)) < 2) next
  
  tabela_antes <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_depois_cs))
  tabela_depois <- CreateTableOne(vars = xvars_usadas, strata = "turismo_dummy", data = as.data.frame(df_pareado))
  smd_df_antes <- as.data.frame(print(tabela_antes, smd = TRUE))
  smd_df_depois <- as.data.frame(print(tabela_depois, smd = TRUE))
  
  media_smd_antes <- mean(abs(as.numeric(smd_df_antes[xvars_usadas, "SMD"])), na.rm = TRUE)
  media_smd_depois <- mean(abs(as.numeric(smd_df_depois[xvars_usadas, "SMD"])), na.rm = TRUE)
  
  smd_evolution_list[[periodo]] <- data.frame(Periodo = periodo, Media_SMD_Antes = media_smd_antes, Media_SMD_Depois = media_smd_depois)
}
smd_evolution_df <- do.call(rbind, smd_evolution_list)
smd_evolution_df$Periodo <- factor(smd_evolution_df$Periodo, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia"))

smd_long_df <- smd_evolution_df %>%
  pivot_longer(cols = c("Media_SMD_Antes", "Media_SMD_Depois"), names_to = "Status", values_to = "Media_SMD") %>%
  mutate(Status = ifelse(Status == "Media_SMD_Antes", "Antes do Pareamento", "Depois do Pareamento"))

# Alterado de geom_bar para geom_line + geom_point
grafico_smd_comparativo_pandemia <- ggplot(smd_long_df, aes(x = Periodo, y = Media_SMD, group = Status, color = Status)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  geom_text(aes(label = round(Media_SMD, 3)), vjust = -1.5, size = 3.5, show.legend = FALSE) + # Adiciona rótulos de texto
  geom_hline(yintercept = 0.1, linetype = "dashed", color = "red") +
  scale_color_manual(values = c("Antes do Pareamento" = "orange", "Depois do Pareamento" = "steelblue")) +
  # Expande um pouco o limite do eixo Y para os rótulos caberem
  ylim(0, max(smd_long_df$Media_SMD) * 1.15) + 
  labs(
    title = "Média do SMD Absoluto por Período da Pandemia", 
    subtitle = "Antes e Depois do Pareamento", 
    x = "Período", 
    y = "Média do SMD Absoluto", 
    color = "Situação"
  ) +
  theme_minimal(base_size = 14) + 
  theme(
    legend.position = "bottom", 
    plot.title = element_text(hjust = 0.5, face = "bold"), 
    plot.subtitle = element_text(hjust = 0.5)
  )

print(grafico_smd_comparativo_pandemia)
ggsave("grafico_smd_comparativo_pandemia_linha.png", plot = grafico_smd_comparativo_pandemia, width = 10, height = 7, dpi = 300)

# Início da sua seção de análise original --
ttest_summary_df <- do.call(rbind, ttest_list)
print(head(ttest_summary_df))
write_xlsx(ttest_summary_df, "resumo_t_test_log_por_pandemia.xlsx")

df_global_pares <- do.call(rbind, pares_global)
write_xlsx(df_global_pares, "resultado_global_pares_log_pandemia.xlsx")

teste_global <- t.test(df_global_pares$diff_log, mu = 0)
print(teste_global)

teste_global_df <- data.frame(
  Estatistica_t = teste_global$statistic,
  Graus_de_Liberdade = teste_global$parameter,
  p_valor = teste_global$p.value,
  Media_diferenca_log = mean(df_global_pares$diff_log),
  Media_diferenca_percentual_aprox = (exp(mean(df_global_pares$diff_log)) - 1) * 100,
  Conf_Inf_Lower = teste_global$conf.int[1],
  Conf_Inf_Upper = teste_global$conf.int[2],
  Hipotese_Alternativa = teste_global$alternative
)
write_xlsx(teste_global_df, "resultado_t_test_global_pandemia.xlsx")

smd_summary_df <- do.call(rbind, balance_list)
smd_summary_df <- dplyr::select(smd_summary_df, Pandemia, Variable, SMD)
print(head(smd_summary_df))
write_xlsx(smd_summary_df, "resumo_balanceamento_smds_por_pandemia.xlsx")


# Gráfico de Diferença Percentual Média de Salários por Pandemia 

ttest_summary_df <- ttest_summary_df %>%
  mutate(
    Pandemia = factor(Pandemia, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia")),
    significativo = ifelse(p_valor < 0.05, TRUE, FALSE)
  )

# ## CÓDIGO DO GRÁFICO ATUALIZADO PARA O ESTILO FINAL ##
grafico_linha_diferenca <- ggplot(ttest_summary_df, aes(x = Pandemia, y = Media_diferenca_percentual_aprox, group = 1)) +
  # Linha azul conectando os pontos
  geom_line(color = "blue", linewidth = 1) +
  # Pontos coloridos por significância
  geom_point(aes(color = significativo), size = 3.5) +
  # Escala de cores manual (preto/vermelho) com drop = FALSE para sempre mostrar a legenda completa
  scale_color_manual(values = c("FALSE" = "black", "TRUE" = "red"), 
                     name = "Significativo (p < 0.05)", 
                     drop = FALSE) +
  # Linha de referência no zero
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Diferença Percentual Média de Salários (Turismo vs. Outros)",
    subtitle = "Períodos com p < 0.05 destacados em vermelho",
    x = "Período",
    y = "Diferença Percentual Média (%)"
  ) +
  theme_minimal(base_size = 14)

print(grafico_linha_diferenca)
ggsave("grafico_diferenca_percentual_por_pandemia_linha.png", plot = grafico_linha_diferenca, width = 10, height = 6, dpi = 300)

# Boxplot: Diferença logarítmica por Pandemia
df_global_pares <- df_global_pares %>%
  mutate(Pandemia = factor(Pandemia, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia")))

grafico_boxplot <- ggplot(df_global_pares, aes(x = Pandemia, y = diff_log, fill = Pandemia)) +
  geom_boxplot() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Distribuição da Diferença Logarítmica dos Salários por Período",
    x = "Período da Pandemia",
    y = "Diferença Logarítmica"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
print(grafico_boxplot)
ggsave("boxplot_diferenca_log_por_pandemia.png", plot = grafico_boxplot, width = 8, height = 6, dpi = 300)


# Gráfico de Intervalo de Confiança (95%) por Período da Pandemia

cat("\nGerando gráfico de diferença salarial com Intervalo de Confiança...\n")

# Calcula os limites do intervalo de confiança em percentual
ttest_summary_df_ic <- ttest_summary_df %>%
  mutate(
    Pandemia = factor(Pandemia, levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia")),
    IC_inferior_perc = (exp(Conf_Inf_Lower) - 1) * 100,
    IC_superior_perc = (exp(Conf_Inf_Upper) - 1) * 100
  )

# Gera o gráfico
grafico_ic_pandemia <- ggplot(ttest_summary_df_ic, aes(x = Pandemia, y = Media_diferenca_percentual_aprox, group = 1)) +
  # A faixa sombreada para o intervalo de confiança
  geom_ribbon(aes(ymin = IC_inferior_perc, ymax = IC_superior_perc),
              fill = "steelblue", alpha = 0.2) +
  # A linha para a média
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(color = "steelblue", size = 3) +
  # Linha de referência no zero
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Diferença Percentual Média de Salários por Período da Pandemia",
    subtitle = "Com intervalo de confiança (95%)",
    x = "Período",
    y = "Diferença Percentual Média (%)"
  ) +
  theme_minimal(base_size = 14)

print(grafico_ic_pandemia)
ggsave("grafico_ic_diferenca_percentual_por_pandemia.png", plot = grafico_ic_pandemia, width = 10, height = 7, dpi = 300)

cat("\nGráfico com Intervalo de Confiança salvo como 'grafico_ic_diferenca_percentual_por_pandemia.png'\n")


# Comparando sa há diferença esttística entre resultdo dos períodos períodos- pré, durante e após pandemia
# Certificando-se de que 'Antes_Pandemia' seja a categoria base
df_global_pares$Pandemia <- factor(df_global_pares$Pandemia, 
                                   levels = c("Antes_Pandemia", "Durante_Pandemia", "Apos_Pandemia"))

# Rodando um modelo de regressão para comparar as médias das diferenças logarítmicas por período
# Este é um modelo ANOVA, que testará a significância das diferenças entre os grupos de período
model_diferenca_entre_periodos <- lm(diff_log ~ Pandemia, data = df_global_pares)

# Exibindo os resultados
summary(model_diferenca_entre_periodos)

# Guardando resultados comparação períodos
# Extraindo a tabela de coeficientes para um dataframe
resultados_df <- as.data.frame(coef(summary(model_diferenca_entre_periodos)))

# Adicionando os nomes das variáveis como uma coluna
resultados_df$Variavel <- rownames(resultados_df)

# Salvando o dataframe em um arquivo Excel
write_xlsx(resultados_df, "resultado_comparacao_entre_periodos.xlsx")

# Opção para salvar em formato mais bonito
# install.packages("modelsummary")
library(modelsummary)

# Apenas para visualizar a tabela no RStudio
modelsummary(model_diferenca_entre_periodos)

# Para salvar a tabela em um arquivo HTML ou Word
modelsummary(model_diferenca_entre_periodos, output = "tabela_modelo_final.html")


# Preparação para comparação de modelos e ajuste
cat("\n\nPreparando objetos e calculando ajuste do modelo...\n")

balance_list_pandemia <- balance_list
ttest_list_pandemia <- ttest_list
pares_global_pandemia <- pares_global
ttest_summary_df_pandemia <- ttest_summary_df
df_global_pares_pandemia <- df_global_pares
smd_summary_df_pandemia <- smd_summary_df

# Função para calcular indicadores do modelo de propensity score
calcular_ajuste_propensity <- function(dados, formula) {
  dados_limpos <- dados %>% drop_na(all_of(all.vars(formula)))
  
  psmodel <- glm(formula, family = binomial(), data = dados_limpos)
  nullmodel <- glm(as.formula(paste(all.vars(formula)[1], "~ 1")), family = binomial(), data = dados_limpos)
  
  aic <- AIC(psmodel)
  bic <- BIC(psmodel)
  loglik <- as.numeric(logLik(psmodel))
  pseudo_r2 <- 1 - (logLik(psmodel) / logLik(nullmodel))
  
  resultados <- data.frame(
    AIC = round(aic, 2),
    BIC = round(bic, 2),
    LogLikelihood = round(loglik, 2),
    Pseudo_R2 = round(as.numeric(pseudo_r2), 4)
  )
  return(resultados)
}

formula_pandemia <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))
resultado_ajuste_pandemia <- calcular_ajuste_propensity(pnad_Filtrada, formula_pandemia)

print("--- Métricas de Ajuste do Modelo de Propensity Score (Modelo Pandemia) ---")
print(resultado_ajuste_pandemia)

# Adição para salvar em excel
write_xlsx(resultado_ajuste_pandemia, "metricas_ajuste_modelo_pandemia.xlsx")

cat("\n\n-- ANÁLISE COMPLETA FINALIZADA --\n")



# Comparação final dos 3 modelos de Matching

# Carregando pacotes
library(dplyr)
library(ggplot2)
library(writexl)
library(tidyr) # Para drop_na()

# Funções de apoio

# Função para calcular a média dos SMDs de um dataframe de resumo
calcular_media_smd <- function(smd_summary_df) {
  smd_summary_df$SMD <- as.numeric(smd_summary_df$SMD)
  mean(smd_summary_df$SMD, na.rm = TRUE)
}

# Função para calcular a proporção de observações pareadas
# Nota: Esta função é uma aproximação, pois não considera as exclusões em cada etapa.
# Uma métrica mais precisa é a contagem de exclusão que já foi salva.

calcular_proporcao_pareados <- function(df_global_pares, total_obs) {
  total_pares <- nrow(df_global_pares)
  perc_pareado <- (total_pares * 2) / total_obs * 100
  return(perc_pareado)
}

# Função robusta para calcular o ajuste do modelo de propensity score
calcular_ajuste_propensity <- function(dados, formula) {
  dados_limpos <- dados %>% drop_na(all_of(all.vars(formula)))
  
  psmodel <- glm(formula, family = binomial(), data = dados_limpos)
  nullmodel <- glm(as.formula(paste(all.vars(formula)[1], "~ 1")), family = binomial(), data = dados_limpos)
  
  aic <- AIC(psmodel)
  bic <- BIC(psmodel)
  loglik <- as.numeric(logLik(psmodel))
  pseudo_r2 <- 1 - (logLik(psmodel) / logLik(nullmodel))
  
  resultados <- data.frame(
    AIC = round(aic, 2),
    BIC = round(bic, 2),
    LogLikelihood = round(loglik, 2),
    Pseudo_R2 = round(as.numeric(pseudo_r2), 4)
  )
  return(resultados)
}


# Cálculo das métricas de ajuste para cada modelo
cat("Calculando métricas de ajuste para os 3 modelos...\n")

# Re-define as covariáveis para a função
xvars <- c(
  "V2007_Mulher", "V2009", "V2010_grupo_PP",
  "V2005_recode_Pessoa_responsável", "V2005_recode_Cônjuge",
  "grupo_moradia_Coletivo", "VD3004_nivel_Escol_Fundamental_Completo",
  "VD3004_nivel_Escol_Médio_Completo", "VD3004_nivel_Escol_Superior_Completo",
  "Regiao_Nordeste", "Regiao_Norte",
  "Regiao_Sudeste", "Regiao_Sul", "V1023_recode3_Capital_e_Metropolitana",
  "V4029_Sim", "V4040_recode_Mais_de_2_anos", "V4039", "Horas_trabalhadas2_Integral",
  "V4025_Não"
)

# A fórmula é a mesma para todos os modelos
formula_ps <- as.formula(paste("turismo_dummy ~", paste(xvars, collapse = " + ")))

# Calcula o ajuste para cada modelo
# (Assumindo que pnad_Filtrada está carregado)
resultado_ajuste_trimestre <- calcular_ajuste_propensity(pnad_Filtrada, formula_ps)
resultado_ajuste_ano <- calcular_ajuste_propensity(pnad_Filtrada, formula_ps)
resultado_ajuste_pandemia <- calcular_ajuste_propensity(pnad_Filtrada, formula_ps)

# Monta a tabela comparativa de ajuste
tabela_ajuste_modelos <- rbind(
  cbind(Modelo = "Ano + Trimestre", resultado_ajuste_trimestre),
  cbind(Modelo = "Ano", resultado_ajuste_ano),
  cbind(Modelo = "Pandemia", resultado_ajuste_pandemia)
)

print("--- Tabela Comparativa de Ajuste dos Modelos de Propensity Score ---")
print(tabela_ajuste_modelos)
write_xlsx(tabela_ajuste_modelos, "tabela_comparativa_ajuste_propensity_scores.xlsx")


# Cálculo das métricas de resultado do Matching
cat("\nCalculando métricas de resultado do matching...\n")

total_obs <- nrow(pnad_Filtrada)

# Métricas para o modelo Ano + Trimestre
media_smd_trimestre <- calcular_media_smd(smd_summary_df_trimestre)
perc_pareado_trimestre <- calcular_proporcao_pareados(df_global_pares_trimestre, total_obs)
media_dif_trimestre <- mean(ttest_summary_df_trimestre$Media_diferenca_percentual_aprox, na.rm = TRUE)

# Métricas para o modelo Ano
media_smd_ano <- calcular_media_smd(smd_summary_df_ano)
perc_pareado_ano <- calcular_proporcao_pareados(df_global_pares_ano, total_obs)
media_dif_ano <- mean(ttest_summary_df_ano$Media_diferenca_percentual_aprox, na.rm = TRUE)

# Métricas para o modelo Pandemia
media_smd_pandemia <- calcular_media_smd(smd_summary_df_pandemia)
perc_pareado_pandemia <- calcular_proporcao_pareados(df_global_pares_pandemia, total_obs)
media_dif_pandemia <- mean(ttest_summary_df_pandemia$Media_diferenca_percentual_aprox, na.rm = TRUE)

# Monta a tabela comparativa de resultados
tabela_comparativa <- data.frame(
  Modelo = c("Ano + Trimestre", "Ano", "Pandemia"),
  Media_SMD_Apos_Match = round(c(media_smd_trimestre, media_smd_ano, media_smd_pandemia), 4),
  Perc_Obs_Pareadas_Aprox = round(c(perc_pareado_trimestre, perc_pareado_ano, perc_pareado_pandemia), 2),
  Media_Dif_Salarial_Perc = round(c(media_dif_trimestre, media_dif_ano, media_dif_pandemia), 2)
)

print("--- Tabela Comparativa de Resultados do Matching ---")
print(tabela_comparativa)
write_xlsx(tabela_comparativa, "tabela_comparativa_resultados_matching.xlsx")


# Gráficos Comparativos
cat("\nGerando gráficos comparativos...\n")

# Gráfico 1: Média dos SMDs
grafico_comp_smd <- ggplot(tabela_comparativa, aes(x = Modelo, y = Media_SMD_Apos_Match, fill = Modelo)) +
  geom_bar(stat = "identity", color = "black") +
  geom_text(aes(label = round(Media_SMD_Apos_Match, 4)), vjust = -0.5) +
  labs(
    title = "Média dos SMDs após o Matching",
    subtitle = "Comparação entre Modelos",
    x = "Modelo", y = "Média dos SMDs"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

print(grafico_comp_smd)
ggsave("grafico_comparativo_smd.png", plot = grafico_comp_smd, width = 8, height = 6, dpi = 300)

# Gráfico 2: Diferença Percentual Média dos Salários
grafico_comp_dif <- ggplot(tabela_comparativa, aes(x = Modelo, y = Media_Dif_Salarial_Perc, fill = Modelo)) +
  geom_bar(stat = "identity", color = "black") +
  geom_text(aes(label = paste0(round(Media_Dif_Salarial_Perc, 2), "%")), vjust = 1.5, color="white", size=5) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  labs(
    title = "Diferença Percentual Média de Salários (Turismo vs Outros)",
    subtitle = "Comparação entre Modelos",
    x = "Modelo", y = "Diferença Percentual Média (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

print(grafico_comp_dif)
ggsave("grafico_comparativo_diferenca_salarial.png", plot = grafico_comp_dif, width = 8, height = 6, dpi = 300)

cat("\n\n-- COMPARAÇÃO DE MODELOS FINALIZADA --\n")


## FILTRANDO APENAS EMPREGADOS ACTS PARA AS PRÓXIMAS ANÁLISES --------------------------------
pnad_tur_Filtrada <- pnad_Filtrada %>%
  filter(turismo_dummy == 1)

# Corrigindo idade ao quadrado
pnad_tur_Filtrada <- pnad_tur_Filtrada %>%
  mutate(V2009_quad = V2009^2)

variable.names(pnad_tur_Filtrada)

# Como data.frame base
# pnad_tur_Filtrada <- as.data.frame(pnad_tur_Filtrada_srvyr)


## DECOMPOSIÇÃO DE OAXACA BLINDER THREEFOLD --------------------------------

glimpse(pnad_tur_Filtrada)

library(oaxaca)

### Decomposição de Oaxaca Blinder por Gênero--------------------------------

oaxaca_result <- oaxaca(
  formula = VD4016_log_hora ~ V2010_grupo_PP + V2009 + I(V2009^2) + VD3005_cont + 
    VD3004_nivel_Escol3_Sem_Ensino_Superior + V1023_recode3_Resto_UF + Regiao_Sul + Regiao_Centro_Oeste + Regiao_Norte + Regiao_Nordeste +
    V4029_Sim + V4025_Não + V4039 + Horas_trabalhadas2_Integral +  V4040_recode_Mais_de_2_anos +
    Ano_2017 + Ano_2018 + Ano_2019 + Ano_2020 + Ano_2021 + Ano_2022 + Ano_2023 + Ano_2024 + Trimestre_2 + Trimestre_3 + Trimestre_4
  | V2007_Mulher, 
  data = pnad_tur_Filtrada, 
  reg.fun = lm, 
  R = 500,  # Bootstrap para ICs
  group.weights = c(0.5, 0.5)  # Ponderação de coeficientes segundo Jann (2008)
)


# Visualizando os resultados
print(oaxaca_result)
summary(oaxaca_result)



# Carregar as bibliotecas necessárias
library(dplyr)
library(tidyr)
library(broom)
library(writexl)

# Definição dos Rótulos (deve estar no início do seu script)
rotulos <- c(
  `VD4016_log_hora` = "Log Salário por Hora",
  `V2010_grupo_PP` = "Pretas e Pardas",
  `V2009` = "Idade (anos)",
  `I(V2009^2)` = "Idade² (anos²)",
  `VD3005_cont` = "Escolaridade (Anos)",
  `VD3004_nivel_Escol3_Sem_Ensino_Superior` = "Sem Ensino Superior",
  `V1023_recode3_Resto_UF` = "Resto da UF",
  `Regiao_Sul` = "Região Sul",
  `Regiao_Centro_Oeste` = "Região Centro Oeste",
  `Regiao_Norte` = "Região Norte",
  `Regiao_Nordeste` = "Região Nordeste",
  `Regiao_Sudeste` = "Região Sudeste",
  `V4029_Sim` = "Carteira Assinada (Sim)",
  `V4025_Não` = "Contrato Temporário (Não)",
  `V4039` = "Horas Semanais Trabalhadas",
  `Horas_trabalhadas2_Integral` = "Integral",
  `V4040_recode_Mais_de_2_anos` = "Tempo de Emprego > 2 anos",
  `V2007_Mulher` = "Mulheres"
)

rotulos_df <- tibble(
  Variavel_tecnica = names(rotulos),
  Variavel = unname(rotulos)
)

# Criar os Modelos de Regressão Separados
dados_homens <- subset(pnad_tur_Filtrada, V2007_Mulher == 0)
dados_mulheres <- subset(pnad_tur_Filtrada, V2007_Mulher == 1)
formula_regressao <- VD4016_log_hora ~ V2010_grupo_PP + V2009 + I(V2009^2) + VD3005_cont + 
  VD3004_nivel_Escol3_Sem_Ensino_Superior + V1023_recode3_Resto_UF + Regiao_Sul + Regiao_Centro_Oeste + Regiao_Norte + Regiao_Nordeste +
  V4029_Sim + V4025_Não + V4039 + Horas_trabalhadas2_Integral + V4040_recode_Mais_de_2_anos +
  Ano_2017 + Ano_2018 + Ano_2019 + Ano_2020 + Ano_2021 + Ano_2022 + Ano_2023 + Ano_2024 + Trimestre_2 + Trimestre_3 + Trimestre_4
modelo_homens <- lm(formula_regressao, data = dados_homens)
modelo_mulheres <- lm(formula_regressao, data = dados_mulheres)


# Extrair o RESUMO GERAL da decomposição
overall_raw <- summary(oaxaca_result)$threefold$overall
resumo_geral <- tibble(
  Componente = c("Endowments (Explicado)", "Coefficients (Não Explicado)", "Interaction"),
  Valor = overall_raw[c("coef(endowments)", "coef(coefficients)", "coef(interaction)")],
  Erro_Padrao = overall_raw[c("se(endowments)", "se(coefficients)", "se(interaction)")]
) %>%
  mutate(
    Estatistica_t = Valor / Erro_Padrao,
    Valor_p = 2 * (1 - pnorm(abs(Estatistica_t))),
    Significancia = case_when(
      Valor_p < 0.001 ~ "***", Valor_p < 0.01 ~ "**", Valor_p < 0.05 ~ "*", Valor_p < 0.1 ~ ".", TRUE ~ ""
    )
  )

# Extrair os resultados das REGRESSÕES (`β`) com os rótulos
regressao_grupo_A <- tidy(modelo_homens) %>%
  left_join(rotulos_df, by = c("term" = "Variavel_tecnica")) %>%
  mutate(Variavel = coalesce(Variavel, term)) %>%
  mutate(Significancia = case_when(
    p.value < 0.001 ~ "***", p.value < 0.01 ~ "**", p.value < 0.05 ~ "*", p.value < 0.1 ~ ".", TRUE ~ ""
  )) %>%
  # Correção aqui
  dplyr::select(Variavel, Coeficiente_beta = estimate, std.error, statistic, p.value, Significancia)

regressao_grupo_B <- tidy(modelo_mulheres) %>%
  left_join(rotulos_df, by = c("term" = "Variavel_tecnica")) %>%
  mutate(Variavel = coalesce(Variavel, term)) %>%
  mutate(Significancia = case_when(
    p.value < 0.001 ~ "***", p.value < 0.01 ~ "**", p.value < 0.05 ~ "*", p.value < 0.1 ~ ".", TRUE ~ ""
  )) %>%
  # --- CORREÇÃO APLICADA AQUI ---
  dplyr::select(Variavel, Coeficiente_beta = estimate, std.error, statistic, p.value, Significancia)

# Extrair a Decomposição detalhada com os rótulos
contribuicoes_detalhadas <- as.data.frame(oaxaca_result$threefold$variables) %>%
  mutate(Variavel_tecnica = rownames(.)) %>%
  pivot_longer(cols = -Variavel_tecnica, names_to = c(".value", "Componente"), names_pattern = "(coef|se)\\((.*)\\)") %>%
  rename(Contribuicao = coef, Erro_Padrao = se) %>%
  left_join(rotulos_df, by = "Variavel_tecnica") %>%
  mutate(Variavel = coalesce(Variavel, Variavel_tecnica)) %>%
  mutate(
    Estatistica_t = Contribuicao / Erro_Padrao,
    Valor_p = 2 * (1 - pnorm(abs(Estatistica_t))),
    Significancia = case_when(
      Valor_p < 0.001 ~ "***", Valor_p < 0.01 ~ "**", Valor_p < 0.05 ~ "*", Valor_p < 0.1 ~ ".", TRUE ~ ""
    )
  ) %>%
  # Correção aplicada aqui
  dplyr::select(Variavel, Componente, Contribuicao, Erro_Padrao, Estatistica_t, Valor_p, Significancia)

# Extrair as estatísticas de ajuste do modelo
ajuste_modelo_A <- glance(modelo_homens)
ajuste_modelo_B <- glance(modelo_mulheres)

# Criar a lista final com todas as tabelas
lista_de_resultados <- list(
  "Resumo_Geral" = resumo_geral,
  "Decomposicao_Detalhada" = contribuicoes_detalhadas,
  "Regressao_Grupo_A_Homens" = regressao_grupo_A,
  "Regressao_Grupo_B_Mulheres" = regressao_grupo_B,
  "Ajuste_Modelo_A_Homens" = ajuste_modelo_A,
  "Ajuste_Modelo_B_Mulheres" = ajuste_modelo_B
)

# Salvar a lista em um ÚNICO arquivo Excel
write_xlsx(lista_de_resultados, path = "Resultados_Oaxaca_Completos_Rotulados.xlsx")

# Mensagem de confirmação
print("Arquivo 'Resultados_Oaxaca_Completos_Rotulados.xlsx' foi salvo com sucesso!")


# Gráficos
library(readxl)
library(ggplot2)
library(dplyr)

# Carregar os dados
detalhada_df <- read_excel("Resultados_Oaxaca_Completos_Rotulados.xlsx", sheet = "Decomposicao_Detalhada")


# Criando um vetor com os nomes exatos dos rótulos a serem excluídos
exclude_labels <- c(
  "Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021", 
  "Ano_2022", "Ano_2023", "Ano_2024",
  "Trimestre_2", "Trimestre_3", "Trimestre_4"
)

# Preparando os dados para o gráfico
detalhada_plot_df <- detalhada_df %>%
  filter(Variavel != "(Intercept)") %>%
  # 2. Aplicar o filtro: remova as linhas cujo rótulo ESTÁ na lista 'exclude_labels'
  filter(!Variavel %in% exclude_labels) %>%
  mutate(
    Componente_Label = recode(Componente,
                              "endowments"   = "Dotações (Explicado)",
                              "coefficients" = "Retornos (Não Explicado)",
                              "interaction"  = "Interação"
    ),
    Componente_Label = factor(Componente_Label, levels = c(
      "Dotações (Explicado)",
      "Retornos (Não Explicado)",
      "Interação"
    ))
  )

# Criar o gráfico
p2_final <- ggplot(detalhada_plot_df, aes(x = Contribuicao, y = reorder(Variavel, Contribuicao))) +
  geom_vline(xintercept = 0, color = "grey") +
  geom_point(aes(color = Componente_Label), size = 3, show.legend = FALSE) +
  geom_segment(aes(xend = 0, yend = Variavel, color = Componente_Label), show.legend = FALSE) +
  geom_text(
    aes(label = Significancia),
    color = "black",
    hjust = ifelse(detalhada_plot_df$Contribuicao >= 0, -0.5, 1.5),
    size = 4
  ) +
  facet_wrap(~ Componente_Label, scales = "free_y") +
  labs(
    title = "Decomposição Detalhada por Variável",
    x = "Contribuição para a Diferença Salarial",
    y = ""
  ) +
  theme_minimal()

# Mostrar e salvar
print(p2_final)
ggsave("grafico_2_decomposicao_final.pdf", plot = p2_final, width = 12, height = 8)



# Gráficos coeficientes regressao
# Carregar os dados das regressões
reg_homens <- read_excel("Resultados_Oaxaca_Completos_Rotulados.xlsx", sheet = "Regressao_Grupo_A_Homens") %>%
  mutate(Grupo = "Homens")
reg_mulheres <- read_excel("Resultados_Oaxaca_Completos_Rotulados.xlsx", sheet = "Regressao_Grupo_B_Mulheres") %>%
  mutate(Grupo = "Mulheres")


# Criando um vetor com os nomes exatos dos rótulos a serem excluídos
exclude_labels <- c(
  "Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021", 
  "Ano_2022", "Ano_2023", "Ano_2024",
  "Trimestre_2", "Trimestre_3", "Trimestre_4"
)


# Combinando e filtrando
reg_combinada <- bind_rows(reg_homens, reg_mulheres) %>%
  filter(Variavel != "(Intercept)") %>%
  # 2. Aplicar o filtro: remova as linhas cujo rótulo ESTÁ na lista 'exclude_labels'
  filter(!Variavel %in% exclude_labels)

# Criar o gráfico de comparação
p3_final <- ggplot(reg_combinada, aes(x = Coeficiente_beta, y = reorder(Variavel, Coeficiente_beta), color = Grupo)) +
  geom_vline(xintercept = 0, color = "grey", linetype = "dashed") +
  geom_point(size = 3, alpha = 0.8) +
  geom_text(
    aes(label = Significancia),
    color = "black",
    vjust = -1,
    size = 4,
    show.legend = FALSE
  ) +
  labs(
    title = "Comparação dos Coeficientes da Regressão (Retornos) por Grupo",
    x = "Valor do Coeficiente (β)",
    y = "",
    color = "Grupo"
  ) +
  theme_minimal() +
  theme(legend.position = "top")

# Mostrar e salvar
print(p3_final)
ggsave("grafico_3_comparacao_coeficientes_final.pdf", plot = p3_final, width = 10, height = 8)



# Gráficos de barras - Forest Bar Plot

library(readxl)
library(ggplot2)
library(dplyr)
library(forcats)

# Carregar os dados (já está no seu código)
detalhada_df <- read_excel("Resultados_Oaxaca_Completos_Rotulados.xlsx", sheet = "Decomposicao_Detalhada")

# Definição dos rótulos a excluir (LIMPO)
exclude_labels <- c(
  "Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021",
  "Ano_2022", "Ano_2023", "Ano_2024",
  "Trimestre_2", "Trimestre_3", "Trimestre_4"
)

# Novo objeto para os Gráficos de Barra (incluindo IC e ordenação)
detalhada_plot_df_clean <- detalhada_df %>%
  filter(Variavel != "(Intercept)") %>%
  filter(!Variavel %in% exclude_labels) %>%
  mutate(
    # *** CÁLCULO DO INTERVALO DE CONFIANÇA (IC) ***
    CI_low  = Contribuicao - 1.96 * Erro_Padrao,
    CI_high = Contribuicao + 1.96 * Erro_Padrao,
    
    # Ordenação necessária para a função criar_grafico_oaxaca_barra
    Variavel_ordenada = forcats::fct_reorder(Variavel, Contribuicao),
    posicao_texto = Contribuicao,
    hjust_ajustado = ifelse(Contribuicao >= 0, -0.1, 1.1),
    
    # Rótulos para o gráfico de dispersão (p2_final) (LIMPO)
    Componente_Label = recode(Componente,
                              "endowments"   = "Dotações (Explicado)",
                              "coefficients" = "Retornos (Não Explicado)",
                              "interaction"  = "Interação"
    ),
    Componente_Label = factor(Componente_Label, levels = c(
      "Dotações (Explicado)",
      "Retornos (Não Explicado)",
      "Interação"
    ))
  )


# Nota: Este código assume que 'detalhada_plot_df_clean' já foi criada
# com as colunas Contribuicao, Erro_Padrao, CI_low, CI_high e Componente.

# Função para gerar o gráfico de barras horizontais (Forest Bar Plot)
criar_grafico_oaxaca_barra <- function(dados, componente_nome, titulo_grafico, nome_arquivo) {
  # Filtrar dados para o componente específico
  dados_componente <- dados %>%
    filter(Componente == componente_nome) %>%
    # Ordenar as variáveis pela Contribuição (para a ordem correta no eixo Y)
    mutate(Variavel_ordenada = fct_reorder(Variavel, Contribuicao))
  
  # Altura do gráfico ajustada
  altura_plot <- max(6, length(unique(dados_componente$Variavel)) * 0.35)
  
  # Definir o ponto de ancoragem para o texto de significância (ajuste o 'hjust' para colocar no final da barra)
  dados_componente <- dados_componente %>%
    mutate(
      posicao_texto = Contribuicao,
      # Ajusta a posição da estrela para o final da barra, usando o sinal da contribuição
      hjust_ajustado = ifelse(Contribuicao >= 0, -0.1, 1.1) 
    )
  
  p <- ggplot(dados_componente, aes(x = Variavel_ordenada, y = Contribuicao)) +
    
    # Gráfico de Barras (geom_col)
    geom_col(fill = "#1FBCB3", color = "#1FBCB3", width = 0.7) +
    
    # Barras de Erro (Intervalo de Confiança de 95%)
    # Note que o 'geom_errorbar' aqui requer ymin/ymax
    geom_errorbar(aes(ymin = CI_low, ymax = CI_high), width = 0.2, color = "black", linewidth = 0.5) +
    
    # Linha vertical em zero (agora horizontal no gráfico final)
    geom_hline(yintercept = 0, color = "grey", linetype = "solid") +
    
    # Inverte os eixos para obter o gráfico de barras horizontais
    coord_flip() +
    
    # Texto de Significância (posicionado no final da barra)
    geom_text(
      aes(label = Significancia, x = Variavel_ordenada, y = posicao_texto),
      color = "black",
      hjust = dados_componente$hjust_ajustado,
      size = 4
    ) +
    labs(
      title = titulo_grafico,
      x = "", # O eixo Y agora é o das variáveis
      y = "Coeficiente"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 16),
      # Remove as linhas de grade que acompanham o eixo Y original
      panel.grid.major.y = element_blank(), 
      panel.grid.minor.y = element_blank(),
      axis.text.y = element_text(size = 10)
    )
  
  # Salvar o gráfico
  ggsave(nome_arquivo, plot = p, width = 9, height = altura_plot)
  return(p)
}

# Gerar e salvar os 3 gráficos separados

# Gráfico 1: Endowments (Dotação / Explicado)
p_endowments_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_df_clean,
  componente_nome = "endowments",
  titulo_grafico = "Endowments (Dotação / Explicado)",
  nome_arquivo = "grafico_oaxaca_endowments_barra.pdf"
)
print(p_endowments_barra)

# Gráfico 2: Coefficients (Coeficientes / Não-explicado)
p_coefficients_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_df_clean,
  componente_nome = "coefficients",
  titulo_grafico = "Coefficients (Coeficientes / Não-explicado)",
  nome_arquivo = "grafico_oaxaca_coefficients_barra.pdf"
)
print(p_coefficients_barra)

# Gráfico 3: Interaction (Interação)
p_interaction_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_df_clean,
  componente_nome = "interaction",
  titulo_grafico = "Interaction (Interação)",
  nome_arquivo = "grafico_oaxaca_interaction_barra.pdf"
)
print(p_interaction_barra)



### Decomposição de Oaxaca Binder por Raça--------------------------------

# Carregando as bibliotecas necessárias
library(dplyr)
library(tidyr)
library(broom)
library(writexl)
library(readxl)
library(ggplot2)

# Definindo os rótulos para as variáveis (reutilizável para ambas as análises)
rotulos <- c(
  `V2010_grupo_PP` = "Pretas e Pardas",
  `V2009` = "Idade (anos)",
  `I(V2009^2)` = "Idade² (anos²)",
  `VD3005_cont` = "Escolaridade (Anos)",
  `VD3004_nivel_Escol3_Sem_Ensino_Superior` = "Sem Ensino Superior",
  `V1023_recode3_Resto_UF` = "Resto da UF",
  `Regiao_Sul` = "Região Sul",
  `Regiao_Centro_Oeste` = "Região Centro Oeste",
  `Regiao_Norte` = "Região Norte",
  `Regiao_Nordeste` = "Região Nordeste",
  `V4029_Sim` = "Carteira Assinada (Sim)",
  `V4025_Não` = "Contrato Temporário (Não)",
  `V4039` = "Horas Semanais Trabalhadas",
  `Horas_trabalhadas2_Integral` = "Integral",
  `V4040_recode_Mais_de_2_anos` = "Tempo de Emprego > 2 anos",
  `V2007_Mulher` = "Mulheres"
)

rotulos_df <- tibble(
  Variavel_tecnica = names(rotulos),
  Label = unname(rotulos)
)

# Rodando o modelo de Oaxaca-Blinder para RAÇA
oaxaca_raca_result <- oaxaca(
  formula = VD4016_log_hora ~ V2007_Mulher + V2009 + I(V2009^2) + VD3005_cont + 
    VD3004_nivel_Escol3_Sem_Ensino_Superior + V1023_recode3_Resto_UF + Regiao_Sul + Regiao_Centro_Oeste + Regiao_Norte + Regiao_Nordeste +
    V4029_Sim + V4025_Não + V4039 + Horas_trabalhadas2_Integral + V4040_recode_Mais_de_2_anos +
    Ano_2017 + Ano_2018 + Ano_2019 + Ano_2020 + Ano_2021 + Ano_2022 + Ano_2023 + Ano_2024 + Trimestre_2 + Trimestre_3 + Trimestre_4
  | V2010_grupo_PP, 
  data = pnad_tur_Filtrada, 
  reg.fun = lm
)

# Criando os modelos de regressão separados para cada grupo racial
# Assumindo que 0 = Brancos (grupo de referência) e 1 = Pretos e Pardos
dados_brancos <- subset(pnad_tur_Filtrada, V2010_grupo_PP == 0)
dados_pp <- subset(pnad_tur_Filtrada, V2010_grupo_PP == 1)

formula_regressao_raca <- VD4016_log_hora ~ V2007_Mulher + V2009 + I(V2009^2) + VD3005_cont + 
  VD3004_nivel_Escol3_Sem_Ensino_Superior + V1023_recode3_Resto_UF + Regiao_Sul + Regiao_Centro_Oeste + Regiao_Norte + Regiao_Nordeste +
  V4029_Sim + V4025_Não + V4039 + Horas_trabalhadas2_Integral + V4040_recode_Mais_de_2_anos +
  Ano_2017 + Ano_2018 + Ano_2019 + Ano_2020 + Ano_2021 + Ano_2022 + Ano_2023 + Ano_2024 + Trimestre_2 + Trimestre_3 + Trimestre_4

modelo_brancos <- lm(formula_regressao_raca, data = dados_brancos)
modelo_pp <- lm(formula_regressao_raca, data = dados_pp)


# Extraindo e formatando todas as tabelas
# Extrair o RESUMO GERAL da decomposição (Método Manual e Robusto)
overall_raw_raca <- summary(oaxaca_raca_result)$threefold$overall
resumo_geral_raca <- tibble(
  Componente = c("Endowments (Explicado)", "Coefficients (Não Explicado)", "Interaction"),
  Valor = overall_raw_raca[c("coef(endowments)", "coef(coefficients)", "coef(interaction)")],
  Erro_Padrao = overall_raw_raca[c("se(endowments)", "se(coefficients)", "se(interaction)")]
) %>%
  mutate(
    Estatistica_t = Valor / Erro_Padrao,
    Valor_p = 2 * (1 - pnorm(abs(Estatistica_t))),
    Significancia = case_when(
      Valor_p < 0.001 ~ "***", Valor_p < 0.01 ~ "**", Valor_p < 0.05 ~ "*", Valor_p < 0.1 ~ ".", TRUE ~ ""
    )
  )

regressao_brancos <- tidy(modelo_brancos) %>%
  left_join(rotulos_df, by = c("term" = "Variavel_tecnica")) %>% mutate(Variavel = coalesce(Label, term)) %>%
  mutate(Significancia = case_when(p.value < 0.001 ~ "***", p.value < 0.01 ~ "**", p.value < 0.05 ~ "*", p.value < 0.1 ~ ".", TRUE ~ "")) %>%
  dplyr::select(Variavel, Coeficiente_beta = estimate, std.error, statistic, p.value, Significancia)

regressao_pp <- tidy(modelo_pp) %>%
  left_join(rotulos_df, by = c("term" = "Variavel_tecnica")) %>% mutate(Variavel = coalesce(Label, term)) %>%
  mutate(Significancia = case_when(p.value < 0.001 ~ "***", p.value < 0.01 ~ "**", p.value < 0.05 ~ "*", p.value < 0.1 ~ ".", TRUE ~ "")) %>%
  dplyr::select(Variavel, Coeficiente_beta = estimate, std.error, statistic, p.value, Significancia)

contribuicoes_raca <- as.data.frame(oaxaca_raca_result$threefold$variables) %>%
  mutate(Variavel_tecnica = rownames(.)) %>%
  pivot_longer(cols = -Variavel_tecnica, names_to = c(".value", "Componente"), names_pattern = "(coef|se)\\((.*)\\)") %>%
  rename(Contribuicao = coef, Erro_Padrao = se) %>%
  left_join(rotulos_df, by = "Variavel_tecnica") %>% mutate(Variavel = coalesce(Label, Variavel_tecnica)) %>%
  mutate(Estatistica_t = Contribuicao / Erro_Padrao, Valor_p = 2 * (1 - pnorm(abs(Estatistica_t))),
         Significancia = case_when(Valor_p < 0.001 ~ "***", Valor_p < 0.01 ~ "**", Valor_p < 0.05 ~ "*", Valor_p < 0.1 ~ ".", TRUE ~ "")) %>%
  dplyr::select(Variavel, Componente, Contribuicao, Erro_Padrao, Estatistica_t, Valor_p, Significancia)

ajuste_brancos <- glance(modelo_brancos)
ajuste_pp <- glance(modelo_pp)


lista_resultados_raca <- list(
  "Resumo_Geral" = resumo_geral_raca,
  "Decomposicao_Detalhada" = contribuicoes_raca,
  "Regressao_Grupo_A_Brancos" = regressao_brancos,
  "Regressao_Grupo_B_PP" = regressao_pp,
  "Ajuste_Modelo_A_Brancos" = ajuste_brancos,
  "Ajuste_Modelo_B_PP" = ajuste_pp
)
write_xlsx(lista_resultados_raca, path = "Resultados_Oaxaca_por_Raca.xlsx")
print("Arquivo 'Resultados_Oaxaca_por_Raca.xlsx' foi salvo com sucesso!")


# Geração gráficos Raça

# Os outros gráficos já estavam corretos
# Gráfico 2: Contribuições Detalhadas por Raça
exclude_labels <- c("Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021", "Ano_2022", "Ano_2023", "Ano_2024", "Trimestre_2", "Trimestre_3", "Trimestre_4")
detalhada_plot_raca <- contribuicoes_raca %>%
  filter(Variavel != "(Intercept)") %>% filter(!Variavel %in% exclude_labels) %>%
  mutate(
    Componente_Label = recode(Componente, "endowments" = "Dotações (Explicado)", "coefficients" = "Retornos (Não Explicado)", "interaction" = "Interação"),
    Componente_Label = factor(Componente_Label, levels = c("Dotações (Explicado)", "Retornos (Não Explicado)", "Interação"))
  )
p2_raca <- ggplot(detalhada_plot_raca, aes(x = Contribuicao, y = reorder(Variavel, Contribuicao))) +
  geom_vline(xintercept = 0, color = "grey") +
  geom_point(aes(color = Componente_Label), size = 3, show.legend = FALSE) +
  geom_segment(aes(xend = 0, yend = Variavel, color = Componente_Label), show.legend = FALSE) +
  geom_text(aes(label = Significancia), color = "black", hjust = ifelse(detalhada_plot_raca$Contribuicao >= 0, -0.5, 1.5), size = 4) +
  facet_wrap(~ Componente_Label, scales = "free_y") +
  labs(title = "Decomposição Detalhada por Raça", x = "Contribuição para a Diferença Salarial", y = "") +
  theme_minimal()
print(p2_raca)
ggsave("grafico_2_decomposicao_detalhada_raca.pdf", plot = p2_raca, width = 12, height = 8)

# Gráfico 3: Comparação de Coeficientes por Raça
reg_combinada_raca <- bind_rows(mutate(regressao_brancos, Grupo = "Brancos"), mutate(regressao_pp, Grupo = "Pretos e Pardos")) %>%
  filter(Variavel != "(Intercept)") %>% filter(!Variavel %in% exclude_labels)
p3_raca <- ggplot(reg_combinada_raca, aes(x = Coeficiente_beta, y = reorder(Variavel, Coeficiente_beta), color = Grupo)) +
  geom_vline(xintercept = 0, color = "grey", linetype = "dashed") +
  geom_point(size = 3, alpha = 0.8) +
  geom_text(aes(label = Significancia), color = "black", vjust = -1, size = 4, show.legend = FALSE) +
  labs(title = "Comparação dos Coeficientes da Regressão por Raça", x = "Valor do Coeficiente (β)", y = "", color = "Grupo") +
  theme_minimal() + theme(legend.position = "top")
print(p3_raca)
ggsave("grafico_3_comparacao_coeficientes_raca.pdf", plot = p3_raca, width = 10, height = 8)


# Geração de gráficos barra para Raça

# Definições e Preparação dos Dados (reutilizando 'exclude_labels' e 'contribuicoes_raca')
# Nota: 'exclude_labels' e 'contribuicoes_raca' devem ter sido criados nas seções anteriores.

# Preparação do Data Frame para Plotagem (com CIs e filtros)
exclude_labels <- c("Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021", "Ano_2022", "Ano_2023", "Ano_2024", "Trimestre_2", "Trimestre_3", "Trimestre_4")

detalhada_plot_raca_barra <- contribuicoes_raca %>%
  filter(Variavel != "(Intercept)") %>%
  filter(!Variavel %in% exclude_labels) %>%
  # Calcular o Intervalo de Confiança de 95% (assumindo Z=1.96)
  mutate(
    CI_low = Contribuicao - 1.96 * Erro_Padrao,
    CI_high = Contribuicao + 1.96 * Erro_Padrao,
    # Ordenar as variáveis pela Contribuição
    Variavel_ordenada = forcats::fct_reorder(Variavel, Contribuicao),
    
    # Posição e ajuste do texto de significância para o final da barra
    posicao_texto = Contribuicao,
    hjust_ajustado = ifelse(Contribuicao >= 0, -0.1, 1.1) 
  )

# Função para gerar o gráfico de barras horizontais (Forest Bar Plot)
criar_grafico_oaxaca_barra <- function(dados, componente_nome, titulo_grafico, nome_arquivo) {
  # Filtrar dados para o componente específico
  dados_componente <- dados %>%
    filter(Componente == componente_nome)
  
  # Altura do gráfico ajustada
  altura_plot <- max(6, length(unique(dados_componente$Variavel)) * 0.35)
  
  p <- ggplot(dados_componente, aes(x = Variavel_ordenada, y = Contribuicao)) +
    
    # Gráfico de Barras (geom_col)
    geom_col(fill = "#1FBCB3", color = "#1FBCB3", width = 0.7) +
    
    # Barras de Erro (Intervalo de Confiança de 95%)
    geom_errorbar(aes(ymin = CI_low, ymax = CI_high), width = 0.2, color = "black", linewidth = 0.5) +
    
    # Linha vertical em zero (será horizontal no gráfico final)
    geom_hline(yintercept = 0, color = "grey", linetype = "solid") +
    
    # Inverte os eixos para obter o gráfico de barras horizontais
    coord_flip() +
    
    # Texto de Significância (posicionado no final da barra)
    geom_text(
      aes(label = Significancia, x = Variavel_ordenada, y = posicao_texto, hjust = hjust_ajustado),
      color = "black",
      size = 4
    ) +
    labs(
      title = titulo_grafico,
      x = "", 
      y = "Coeficiente"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 16),
      panel.grid.major.y = element_blank(), 
      panel.grid.minor.y = element_blank(),
      axis.text.y = element_text(size = 10)
    )
  
  # Salvar o gráfico
  ggsave(nome_arquivo, plot = p, width = 9, height = altura_plot)
  return(p)
}

# Gerar e salvar os 3 gráficos separados para RAÇA

# Gráfico 1: Endowments (Dotação / Explicado)
p_endowments_raca_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_raca_barra,
  componente_nome = "endowments",
  titulo_grafico = "Endowments (Dotação / Explicado) - Raça",
  nome_arquivo = "grafico_oaxaca_endowments_raca_barra.pdf"
)
print(p_endowments_raca_barra)

# Gráfico 2: Coefficients (Coeficientes / Não-explicado)
p_coefficients_raca_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_raca_barra,
  componente_nome = "coefficients",
  titulo_grafico = "Coefficients (Coeficientes / Não-explicado) - Raça",
  nome_arquivo = "grafico_oaxaca_coefficients_raca_barra.pdf"
)
print(p_coefficients_raca_barra)

# Gráfico 3: Interaction (Interação)
p_interaction_raca_barra <- criar_grafico_oaxaca_barra(
  detalhada_plot_raca_barra,
  componente_nome = "interaction",
  titulo_grafico = "Interaction (Interação) - Raça",
  nome_arquivo = "grafico_oaxaca_interaction_raca_barra.pdf"
)
print(p_interaction_raca_barra)


## REGRESSAO QUANTILICA DE TODOS OS MODELOS COM PARALELIZAÇÃO PARA OTIMIZAÇÃO--------------------------------
 
library(quantreg)
library(dplyr)
library(tidyr)
library(broom)
library(car)
library(lmtest)
library(writexl)
library(ggplot2)
library(stringr)
library(doParallel) # Novo! Para paralelização
library(foreach)   # Novo! Para paralelização

# Variável dependente e quantis
Y <- "VD4016_log_hora"
quantis <- c(0.10, 0.25, 0.50, 0.75, 0.90)
meu_azul <- "#00ACC1"

# Rótulos Completos 
rotulos <- c(
  # Termos individuais
  "(Intercept)" = "Intercepto",
  "V2007_Mulher" = "Mulher",
  "V2010_grupo_PP" = "Raça (PP)",
  "V2009" = "Idade",
  "V2009_quad" = "Idade²",
  "VD3005_cont" = "Escolaridade (anos)",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior" = "Sem Ensino Superior",
  "V1023_recode3_Resto_UF" = "Não Capital ou Metropolitana",
  "Regiao_Nordeste" = "Nordeste",
  "Regiao_Centro_Oeste" = "Centro Oeste",
  "Regiao_Sul" = "Sul",
  "Regiao_Norte" = "Norte",
  "Regiao_Sudeste" = "Sudeste",
  "V4029_Sim" = "Carteira Assinada (Sim)",
  "`V4025_Não`" = "Contrato Temporário (Não)", 
  "V4025_Não" = "Contrato Temporário (Não)", # Versão sem crase
  "V4039" = "Horas Semanais",
  "Horas_trabalhadas2_Integral" = "Regime Integral",
  "V4040_recode_Mais_de_2_anos" = "Mais de 2 anos de Emprego",
  "Ano_2017" = "2017", "Ano_2018" = "2018", "Ano_2019" = "2019",
  "Ano_2020" = "2020", "Ano_2021" = "2021", "Ano_2022" = "2022",
  "Ano_2023" = "2023", "Ano_2024" = "2024",
  "Trimestre_2" = "2º Tri", "Trimestre_3" = "3º Tri", "Trimestre_4" = "4º Tri",
  "Pandemia_Durante_Pandemia" = "Durante a Pandemia (20-21)",
  "Pandemia_Apos_Pandemia" = "Após a Pandemia (22-24)",
  
  # Rótulos para Interações (Usando a ordem alfabética para robustez)
  "V2007_Mulher:V2010_grupo_PP" = "Mulher x Raça (PP)",
  "V2007_Mulher:V2009" = "Mulher x Idade",
  "V2007_Mulher:VD3005_cont" = "Mulher x Escolaridade (anos)",
  "V2007_Mulher:VD3004_nivel_Escol3_Sem_Ensino_Superior" = "Mulher x Sem Ensino Superior",
  "V2007_Mulher:Regiao_Centro_Oeste" = "Mulher x Centro Oeste",
  "V2007_Mulher:Regiao_Nordeste" = "Mulher x Nordeste",
  "V2007_Mulher:Regiao_Norte" = "Mulher x Norte",
  "V2007_Mulher:Regiao_Sul" = "Mulher x Sul",
  "V2007_Mulher:V1023_recode3_Resto_UF" = "Mulher x Não Capital ou Metropolitana",
  "V2007_Mulher:V4029_Sim" = "Mulher x Carteira Assinada (Sim)",
  "V4025_Não:V2007_Mulher" = "Mulher x Contrato Temporário (Não)", # Corrigido: Ordem alfabética
  "V2007_Mulher:V4039" = "Mulher x Horas Semanais",
  "V2007_Mulher:Horas_trabalhadas2_Integral" = "Mulher x Regime Integral",
  "V2007_Mulher:V4040_recode_Mais_de_2_anos" = "Mulher x Mais de 2 anos de Emprego",
  
  # Interações com Raça (V2010_grupo_PP)
  "V2010_grupo_PP:V2009" = "Raça (PP) x Idade",
  "V2010_grupo_PP:VD3005_cont" = "Raça (PP) x Escolaridade (anos)",
  "V2010_grupo_PP:VD3004_nivel_Escol3_Sem_Ensino_Superior" = "Raça (PP) x Sem Ensino Superior",
  "V2010_grupo_PP:Regiao_Centro_Oeste" = "Raça (PP) x Centro Oeste",
  "V2010_grupo_PP:Regiao_Nordeste" = "Raça (PP) x Nordeste",
  "V2010_grupo_PP:Regiao_Norte" = "Raça (PP) x Norte",
  "V2010_grupo_PP:Regiao_Sul" = "Raça (PP) x Sul",
  "V2010_grupo_PP:V1023_recode3_Resto_UF" = "Raça (PP) x Não Capital ou Metropolitana",
  "V2010_grupo_PP:V4029_Sim" = "Raça (PP) x Carteira Assinada (Sim)",
  "V4025_Não:V2010_grupo_PP" = "Raça x Contrato Temporário (Não)", # Corrigido
  "V2010_grupo_PP:V4039" = "Raça (PP) x Horas Semanais",
  "V2010_grupo_PP:Horas_trabalhadas2_Integral" = "Raça (PP) x Regime Integral",
  "V2010_grupo_PP:V4040_recode_Mais_de_2_anos" = "Raça (PP) x Mais de 2 anos de Emprego",
  
  # Interações com Escolaridade (VD3004_nivel_Escol3_Sem_Ensino_Superior)
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:V2009" = "Sem Ensino Superior x Idade",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:Regiao_Centro_Oeste" = "Sem Ensino Superior x Centro Oeste",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:Regiao_Nordeste" = "Sem Ensino Superior x Nordeste",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:Regiao_Norte" = "Sem Ensino Superior x Norte",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:Regiao_Sul" = "Sem Ensino Superior x Sul",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:V1023_recode3_Resto_UF" = "Sem Ensino Superior x Não Capital ou Metropolitana",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:V4029_Sim" = "Sem Ensino Superior x Carteira Assinada (Sim)",
  "V4025_Não:VD3004_nivel_Escol3_Sem_Ensino_Superior" = "Sem Ensino Superior x Contrato Temporário (Não)", # Corrigido
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:V4039" = "Sem Ensino Superior x Horas Semanais",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:Horas_trabalhadas2_Integral" = "Sem Ensino Superior x Regime Integral",
  "VD3004_nivel_Escol3_Sem_Ensino_Superior:V4040_recode_Mais_de_2_anos" = "Sem Ensino Superior x Mais de 2 anos de Emprego",
  
  # Interações com Carteira Assinada (V4029_Sim)
  "V4029_Sim:V2009" = "Carteira Assinada (Sim) x Idade",
  "V4029_Sim:VD3005_cont" = "Carteira Assinada (Sim) x Escolaridade (anos)",
  "V4029_Sim:Regiao_Centro_Oeste" = "Carteira Assinada (Sim) x Centro Oeste",
  "V4029_Sim:Regiao_Nordeste" = "Carteira Assinada (Sim) x Nordeste",
  "V4029_Sim:Regiao_Norte" = "Carteira Assinada (Sim) x Norte",
  "V4029_Sim:Regiao_Sul" = "Carteira Assinada (Sim) x Sul",
  "V4029_Sim:V1023_recode3_Resto_UF" = "Carteira Assinada (Sim) x Não Capital ou Metropolitana",
  "V4025_Não:V4029_Sim" = "Carteira Assinada x Contrato Temporário (Não)", # Corrigido
  "V4029_Sim:V4039" = "Carteira Assinada (Sim) x Horas Semanais",
  "V4029_Sim:Horas_trabalhadas2_Integral" = "Carteira Assinada (Sim) x Regime Integral",
  "V4029_Sim:V4040_recode_Mais_de_2_anos" = "Carteira Assinada (Sim) x Mais de 2 anos de Emprego",
  
  # Interações com Idade (V2009)
  "V2009:VD3005_cont" = "Idade x Escolaridade (anos)",
  "V2009:Regiao_Centro_Oeste" = "Idade x Centro Oeste",
  "V2009:Regiao_Nordeste" = "Idade x Nordeste",
  "V2009:Regiao_Norte" = "Idade x Norte",
  "V2009:Regiao_Sul" = "Idade x Sul",
  "V2009:V1023_recode3_Resto_UF" = "Idade x Não Capital ou Metropolitana",
  "V2009:V4039" = "Idade x Horas Semanais",
  "V4025_Não:V2009" = "Idade x Contrato Temporário (Não)", # Corrigido
  "V2009:Horas_trabalhadas2_Integral" = "Idade x Regime Integral",
  "V2009:V4040_recode_Mais_de_2_anos" = "Idade x Mais de 2 anos de Emprego"
)

# Vetor para fixar a ordem canônica dos fatores no gráfico
ordem_canonica <- names(rotulos)


# Variáveis base (sem termos de tempo)
X_base <- c("V2007_Mulher", "V2010_grupo_PP", "V2009", "V2009_quad", "VD3005_cont",
            "VD3004_nivel_Escol3_Sem_Ensino_Superior",
            "V1023_recode3_Resto_UF", "Regiao_Nordeste", "Regiao_Centro_Oeste", "Regiao_Sul", "Regiao_Norte",
            "V4029_Sim", "`V4025_Não`", "V4039", "Horas_trabalhadas2_Integral",
            "V4040_recode_Mais_de_2_anos")

# Termos de tempo
termos_tempo_base <- c("Ano_2017", "Ano_2018", "Ano_2019", "Ano_2020", "Ano_2021", "Ano_2022", "Ano_2023", "Ano_2024",
                       "Trimestre_2", "Trimestre_3", "Trimestre_4")
termos_pandemia <- c("Pandemia_Durante_Pandemia", "Pandemia_Apos_Pandemia")


# Definição das interações agrupadas por variável base
vars_para_interagir <- c("V2010_grupo_PP", "V2009", "VD3005_cont", "VD3004_nivel_Escol3_Sem_Ensino_Superior",
                         "Regiao_Nordeste", "Regiao_Centro_Oeste", "Regiao_Sul", "Regiao_Norte",
                         "V1023_recode3_Resto_UF", "V4029_Sim", "`V4025_Não`", "V4039", "Horas_trabalhadas2_Integral",
                         "V4040_recode_Mais_de_2_anos")

# Interações para cada modelo
interacoes_mulher <- paste0("V2007_Mulher * ", vars_para_interagir)
interacoes_raca <- paste0("V2010_grupo_PP * ", vars_para_interagir)
interacoes_escolaridade <- paste0("VD3004_nivel_Escol3_Sem_Ensino_Superior * ", vars_para_interagir)
interacoes_cartassinada <- paste0("V4029_Sim * ", vars_para_interagir)
interacoes_idade <- paste0("V2009 * ", vars_para_interagir)


### Lista Mestra de Modelos Regressão Quantílica--------------------------------
lista_modelos <- list(
  "Modelo_Basico" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = NULL,
    nome_arquivo = "basico"
  ),
  "Modelo_Pandemia" = list(
    termos = c(X_base, termos_pandemia),
    interacoes = NULL,
    nome_arquivo = "pandemia"
  ),
  "Modelo_Int_Mulher" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = interacoes_mulher,
    nome_arquivo = "int_mulher"
  ),
  "Modelo_Int_Raca" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = interacoes_raca,
    nome_arquivo = "int_raca"
  ),
  "Modelo_Int_Escolaridade" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = interacoes_escolaridade,
    nome_arquivo = "int_escol"
  ),
  "Modelo_Int_CarteiraAssinada" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = interacoes_cartassinada,
    nome_arquivo = "int_cartAss"
  ),
  "Modelo_Int_Idade" = list(
    termos = c(X_base, termos_tempo_base),
    interacoes = interacoes_idade,
    nome_arquivo = "int_idade"
  )
)



cria_formula <- function(y, termos, interacoes = NULL) {
  if (is.null(interacoes)) {
    formula_str <- paste(y, "~", paste(termos, collapse = " + "))
  } else {
    termos_full <- unique(c(termos, interacoes))
    formula_str <- paste(y, "~", paste(termos_full, collapse = " + "))
  }
  return(as.formula(formula_str))
}


processa_modelo_quantilica <- function(formula, data, taus, nome_modelo, rotulos_map) {
  cat(paste0("Ajustando: ", nome_modelo, " (Bootstrap B=500)\n"))
  
  # Passo 1: Ajuste da Regressão Quantílica 
  p.erq <- rq(
    formula = formula,
    tau = taus,
    method = "br",
    data = data
  )
  
  # Defina o número de repetições do Bootstrap aqui
  NUM_BOOTSTRAP <- 500 
  
  # Passo 2: Resumo Tidy usando Bootstrap 
  resultados_tidy <- tidy(
    p.erq, 
    se.type = "boot",          # Usa o método Bootstrap
    B = NUM_BOOTSTRAP          # Define o número de repetições
  ) %>%
    mutate(
      significancia = case_when(
        p.value < 0.001 ~ "***",
        p.value < 0.01  ~ "**",
        p.value < 0.05  ~ "*",
        TRUE            ~ ""
      ),
      term_label = dplyr::recode(term, !!!rotulos_map, .default = term) 
    )
  
  # Passo 3: Filtro e Tabela Wide 
  resultados_tidy <- resultados_tidy %>%
    filter(term_label != "NA" & !is.na(term_label))
  
  coeficientes_wide <- resultados_tidy %>%
    dplyr::select(tau, term_label, estimate, significancia) %>%
    dplyr::mutate(
      estimate = paste0(format(round(estimate, 4), nsmall = 4), significancia)
    ) %>%
    dplyr::select(tau, term_label, estimate) %>%
    tidyr::pivot_wider(names_from = tau, values_from = estimate, names_prefix = "Quantil_")
  
  return(list(
    p.erq = p.erq,
    resultados_tidy = resultados_tidy,
    coeficientes_wide = coeficientes_wide
  ))
}


calcula_ajuste <- function(formula, data, taus, Y) {
  n <- nrow(data)
  resultados_list <- list()
  for(t in taus){
    modelo <- rq(formula, tau = t, data = data, method = "br")
    modelo_nulo <- rq(as.formula(paste(Y, "~ 1")), tau = t, data = data, method = "br")
    
    pseudo_R2 <- 1 - modelo$rho / modelo_nulo$rho
    k <- length(coef(modelo))
    AIC_pseudo <- n * log(modelo$rho / n) + 2 * k 
    
    resultados_list[[as.character(t)]] <- data.frame(
      Quantil = t,
      Pseudo_R2 = pseudo_R2,
      AIC = AIC_pseudo
    )
  }
  return(bind_rows(resultados_list))
}


gera_grafico_main <- function(df_tidy, nome_modelo, rotulos_map, ordem_cana, color, filtro_termos_excluir = "Ano|Trimestre") {
  
  df_tidy <- df_tidy %>% filter(!is.na(term_label))
  
  term_col_name <- "term"
  niveis_presentes <- intersect(ordem_cana, unique(df_tidy[[term_col_name]]))
  
  df_plot <- df_tidy %>%
    filter(term %in% niveis_presentes) %>%
    mutate(!!term_col_name := factor(.data[[term_col_name]], levels = niveis_presentes)) %>%
    filter(!grepl(filtro_termos_excluir, term))
  
  grafico <- df_plot %>%
    ggplot(aes(x = tau, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    geom_line(size = 1, color = color) +
    geom_point(aes(shape = significancia), size = 3, color = color) +
    facet_wrap(~ term, scales = "free_y", labeller = as_labeller(rotulos_map)) +
    labs(
      title = paste("Coeficientes por Quantil (Modelo: ", nome_modelo, ")", sep=""),
      x = "Quantil",
      y = "Coeficiente Estimado",
      shape = "Significância"
    ) +
    scale_shape_manual(
      values = c(" " = 1, "*" = 16, "**" = 17, "***" = 18),
      labels = c(" " = "Sem significância", "*" = "p < 0.05", "**" = "p < 0.01", "***" = "p < 0.001"),
      drop = FALSE
    ) +
    theme_minimal() +
    theme(
      text = element_text(size = 12),
      strip.text = element_text(size = 10, face = "bold"),
      legend.position = "bottom",
      plot.title = element_text(hjust = 0.5)
    )
  return(grafico)
}



# Configurar o Cluster de Paralelização
# Tente usar todos os núcleos menos um para evitar travar o PC
num_cores <- detectCores() - 1 
if (num_cores < 1) num_cores <- 1 # Garante pelo menos um núcleo

cat(paste("Iniciando paralelização em", num_cores, " núcleos...\n"))
cl <- makeCluster(num_cores)
registerDoParallel(cl)

# Loop paralelo 
# Exporta todas as funções e variáveis necessárias para os núcleos
# O retorno é suprimido, pois salvamos os arquivos diretamente no loop
# O dataframe pnad_tur_Filtrada deve estar carregado globalmente.
tempo_inicio <- Sys.time()

resultados_paralelos <- foreach(
  nome = names(lista_modelos), 
  .packages = c("quantreg", "dplyr", "tidyr", "broom", "stringr", "writexl", "ggplot2"),
  .export = c("Y", "quantis", "meu_azul", "rotulos", "ordem_canonica", "lista_modelos", 
              "cria_formula", "processa_modelo_quantilica", "calcula_ajuste", 
              "gera_grafico_main", "pnad_tur_Filtrada"),
  .errorhandling = "stop"
) %dopar% {
  
  # O corpo loop original (que agora roda em paralelo)
  
  modelo_info <- lista_modelos[[nome]]
  arquivo_base <- modelo_info$nome_arquivo 
  
  # Cria a fórmula
  formula_modelo <- cria_formula(Y, modelo_info$termos, modelo_info$interacoes)
  
  # Processa (ajusta, resume e cria tabela wide)
  resultados <- processa_modelo_quantilica(
    formula = formula_modelo,
    data = pnad_tur_Filtrada, 
    taus = quantis,
    nome_modelo = nome,
    rotulos_map = rotulos
  )
  
  # Gera e salva a Tabela Wide (Coeficientes com Significância)
  nome_arquivo_excel_coef <- paste0("coeficientes_quantil_significancia_", arquivo_base, ".xlsx")
  writexl::write_xlsx(resultados$coeficientes_wide, nome_arquivo_excel_coef)
  
  # Calcula e Salva Pseudo R² e AIC
  ajuste_df <- calcula_ajuste(formula_modelo, pnad_tur_Filtrada, quantis, Y)
  nome_arquivo_excel_ajuste <- paste0("resultados_modelo_quantis_", arquivo_base, ".xlsx")
  writexl::write_xlsx(ajuste_df, nome_arquivo_excel_ajuste)
  
  # Gera e Salva o Gráfico Principal
  grafico_main <- gera_grafico_main(
    df_tidy = resultados$resultados_tidy,
    nome_modelo = nome,
    rotulos_map = rotulos,
    ordem_cana = ordem_canonica,
    color = meu_azul
  )
  nome_arquivo_grafico_pdf <- paste0("grafico_coeficientes_", arquivo_base, "_filtrado.pdf")
  ggplot2::ggsave(nome_arquivo_grafico_pdf, grafico_main, width = 20, height = 8)
  
  # Gera e Salva o Gráfico Apenas de Interações
  if (!is.null(modelo_info$interacoes)) {
    df_interacoes <- resultados$resultados_tidy %>% filter(str_detect(term, ":"))
    
    grafico_interacoes <- gera_grafico_main(
      df_tidy = df_interacoes,
      nome_modelo = paste(nome, " (Somente Interações)"),
      rotulos_map = rotulos,
      ordem_cana = ordem_canonica,
      color = meu_azul,
      filtro_termos_excluir = "NENHUM_TERMO_ASSIM_ESPERO"
    )
    
    nome_arquivo_grafico_int_pdf <- paste0("grafico_coeficientes_somente_int_", arquivo_base, ".pdf")
    ggplot2::ggsave(nome_arquivo_grafico_int_pdf, grafico_interacoes, width = 20, height = 8)
  }
  
  # Retorna o nome do modelo para visualização do progresso, se necessário
  return(nome)
}

# Parar o Cluster (MUITO IMPORTANTE!) ---
stopCluster(cl)
tempo_fim <- Sys.time()
tempo_total <- tempo_fim - tempo_inicio

cat("\n----------------------------------------------\n")
cat("PROCESSAMENTO PARALELO CONCLUÍDO.\n")
cat(paste("Modelos executados:", paste(unlist(resultados_paralelos), collapse = ", "), "\n"))
cat(paste("Tempo total gasto: ", format(tempo_total), "\n"))
cat("----------------------------------------------\n")


# Após rodar todo o código da regressão quantílica veja o seu diretório de dados para acessar as saídas da análise.


## SALVANDO O CÓDIGO--------------------------------

setwd("C:/Users/Ana Oliveira/Desktop/pnadc 2023") 
# Carregue os Pacotes
library(knitr)
library(rmarkdown)

# Defina o Nome do Seu Arquivo R (NOME EXATO)
NOME_DO_SEU_CODIGO <- "Analises Tese Junho com Seleção Amostral e correções 03-10-25.R"

# Execução

# Gerando o R Markdown (.Rmd)
# knit=FALSE para garantir que a execução não comece nesta fase.
knitr::spin(NOME_DO_SEU_CODIGO, knit = FALSE)


