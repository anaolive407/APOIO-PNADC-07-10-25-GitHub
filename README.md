--------------------------------------------------------------------------------
    Fatores Sociodemográficos e Ocupacionais Determinantes dos Salários 
          nas Atividades Características do Turismo no Brasil
--------------------------------------------------------------------------------

Autor(a): Ana Oliveira 
Data da Última Atualização: 05/10/2025
Contato: [anaolive@usp.br]

--------------------------------------------------------------------------------
1. DESCRIÇÃO GERAL
--------------------------------------------------------------------------------

Este projeto constitui a análise de dados para uma tese, utilizando os microdados da Pesquisa Nacional por Amostra de Domicílios Contínua (PNADc) do IBGE para o período de 2016 a 2024.

O **objetivo principal** é Analisar os salários no mercado de trabalho das ACTs no Brasil.

As técnicas estatísticas centrais aplicadas são:
* **Propensity Score Matching (PSM)
* **Decomposição de Oaxaca-Blinder
* **Regressão Quantílica

--------------------------------------------------------------------------------
2. FONTES DE DADOS E ARQUIVOS DE APOIO
--------------------------------------------------------------------------------

### 2.1. DADOS BRUTOS
Os microdados brutos do respectivo período (2016-2024) devem ser baixados do portal do IBGE e colocados na pasta de trabalho.
* **Link:** https://www.ibge.gov.br/estatisticas/sociais/trabalho/2511-np-pnad-continua/30980-pnadc-divulgacao-pnadc4.html?=&t=microdados
* **Caminho no site:** IBGE -> Microdados -> Microdados da Divulgação Trimestral.

### 2.2. ARQUIVOS DE APOIO
Os seguintes arquivos de suporte são necessários e devem estar na pasta de trabalho:
* `deflator_PNADC_*.xlsx`: Planilha oficial com os deflatores para correção monetária.
* `dicionario_PNADC_*.xlsx`: Dicionário de variáveis da PNADc.
* `input_PNADC_trimestral.txt`: Arquivo de layout para leitura dos microdados.
* `cnae_mapping.rds` e `nomes_ocupacao.rds`: Arquivos RDS com mapeamentos de códigos para descrições de atividades e ocupações.
* `pnad_auditoria_amostra_estratificada_limpa.rds`: Base de dados amostral e estratificada (reduzida) criada para auditar o funcionamento das análises econométricas (PSM, Oaxaca-Blinder, Regressão Quantílica). Atenção: Devido ao tamanho reduzido, os resultados replicados não serão idênticos aos da tese, mas devem apresentar o mesmo comportamento e direção.
* `pnad_final_21_06_25.rds`: Caso queira acessar essa base, por favor solicite por e-mail. 

--------------------------------------------------------------------------------
3. CONFIGURAÇÃO E EXECUÇÃO DO SCRIPT
--------------------------------------------------------------------------------

### 3.1. Pré-requisitos
* R (versão 4.0 ou superior) e RStudio.
* Pacotes R:
| 	Categoria 		| 				Pacotes				   |
|				|								   |
| Manipulação e Ambiente 	| tidyverse, dplyr, tidyr, stringr, rlang, purrr, knitr, rmarkdown |
| Dados Amostrais (PNADc) 	| PNADcIBGE, survey, srvyr 					   |
| Tratamento e Dummies 		| fastDummies 							   |
| Relatório e Tabelas 		| writexl, openxlsx, readxl, tableone, broom, forcats 		   |
| Econometria e Testes 		| Matching, oaxaca, quantreg, nortest, car, lmtest 		   |
| Otimização (Paralelização) 	| doParallel, foreach						   |

### 3.2. Estrutura e Ordem de Execução
O projeto está contido em um único script. **A única ação manual obrigatória é alterar a linha `setwd("...")` no início do código** para o caminho da sua pasta de projeto.

O script segue a seguinte ordem lógica:

**BLOCO 1: PREPARAÇÃO E LIMPEZA DOS DADOS**
* `CARREGANDO AS BASES DE DADOS`: Lê os microdados brutos de 2016-2024, aplica filtros iniciais (somente ocupados), adiciona deflator/dicionário e salva uma base consolidada (`pnad_final_21_06_25.rds`).
* `VERIFICANDO E FILTRANDO A BASE DE DADOS`: Aplica filtros de escopo da tese (setor privado, idade >= 14) e realiza análises exploratórias.
* `VERIFICANDO E ELIMINANDO OUTLIERS`: Identifica e remove valores extremos de salário por hora e horas trabalhadas para evitar distorções.
* `TRANSFORMANDO VARIÁVEIS`: Etapa de adaptação de variáveis. Cria as colunas que serão usadas nos modelos, como níveis de escolaridade, `turismo_dummy` e a variável `Pandemia`. Permite que a variáveis sejam binárias na etapa posterior.
* `INCORPORANDO DESENHO AMOSTRAL COMPLEXO`: Cria o objeto `srvyr` (`pnad_Filtrada_srvyr`) que considera os pesos amostrais da PNADC, garantindo a validade estatística dos resultados.

3.3. Ponto de Auditoria para Análises Centrais
As análises estatísticas e econométricas podem ser auditadas utilizando a base amostral criada na etapa de preparação (pnad_auditoria_amostra_estratificada_limpa.rds).

Para iniciar a validação dos resultados, o ponto de partida no script é a marcação:

Linha 1176: # ANÁLISES TESE ANA - 2025 / ## ABRINDO BASE AUDITÁVEL -------------------------------------

**BLOCO 2: ANÁLISES E MODELAGEM**
* `ANÁLISES DESCRITIVAS`: Gera tabelas e gráficos ponderados que comparam o perfil dos trabalhadores das ACTs versus os demais.
* `ANÁLISE DE MATCHING`: Implementa o Propensity Score Matching. Esta seção está subdividida em três abordagens para testar a robustez dos resultados:
    * `### Análise de Matching com Ano e Trimestre`
    * `### Análise de Matching sem Trimestre (apenas por Ano)`
    * `### Análise de Matching com Períodos Pandemia`
    * Ao final, compara ajustes dos três modelos de matching.

* `DECOMPOSIÇÃO DE OAXACA BLINDER`: Realiza a decomposição dos diferenciais de salários. A análise é executada em duas subseções:
    * `### Decomposição por Gênero`
    * `### Decomposição por Raça`

* `REGRESSÃO QUANTÍLICA`: Para cada um dos seguintes modelos, a análise é rodada em loop para os cinco quantis definidos (0.10,0.25,0.50,0.75,0.90):

    * `### Modelo Principal: O modelo base é executado.
    * `### Modelo Alternativo Pandemia: O modelo de robustez é executado, incluindo a variável Pandemia.
    * `### Adições Interações + Modelo Principal: Uma série de modelos é executada em loop, adicionando e testando diferentes termos de interação por vez.

--------------------------------------------------------------------------------
4. SAÍDAS E RESULTADOS
--------------------------------------------------------------------------------

O script foi elaborado para ser totalmente reprodutível. Ao ser executado, ele gera automaticamente todos os resultados no diretório de trabalho definido:
* **Tabelas de dados e resultados** são salvas em formato **Excel (`.xlsx`)**.
* **Gráficos e visualizações** são salvos como arquivos **PDF** ou **PNG**.
