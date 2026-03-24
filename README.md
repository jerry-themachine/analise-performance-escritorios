# 📊 Análise de Performance e Risco Operacional

## 🎯 Objetivo

Avaliar a performance e o risco de escritórios jurídicos com base em indicadores operacionais e financeiros.

## 🧠 Metodologia

O projeto foi estruturado em camadas utilizando CTEs:

* **base** → tratamento inicial dos dados
* **anomalias** → identificação de inconsistências
* **scores** → cálculo de indicadores
* **scores_final** → consolidação de métricas
* **alertas_por_escritorio** → análise de qualidade

## 📊 Indicadores Criados

* Taxa de sucesso (%)
* Tempo médio de processos
* Risco financeiro (valor ativo)
* Ticket médio
* Score final (tempo + taxa + risco)

## 🚨 Sistema de Alertas

* Saudável
* Atenção
* Crítico

## 🧩 Tecnologias

* SQL Server
* T-SQL
* Modelagem Analítica

## 💡 Resultado

Identificação de escritórios com baixa performance e alto risco, permitindo direcionamento estratégico para tomada de decisão.

## 🚀 Próximos Passos

* Integração com Power BI
* Automação de alertas por e-mail
* Pipeline de ETL para dados em produção

