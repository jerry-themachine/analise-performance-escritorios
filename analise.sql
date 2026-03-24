WITH 
-- CTE BASE	 
	 base AS (
		SELECT p.id_escritorio AS ID,
			   e.nome AS ESCRITORIO,
			   CASE
				   WHEN p.status = 'ativo' THEN 1
				   ELSE 0
			   END AS FLAG_ATIVO,
			   CASE
				   WHEN p.status = 'ativo' THEN p.valor
				   ELSE 0
			   END AS VALOR_ATIVO,	
			   CASE
				   WHEN p.status = 'ganho' THEN 1
				   ELSE 0
			   END AS FLAG_GANHO,
			   CASE
				   WHEN p.status IN ('ganho','perdido') THEN 1
				   ELSE 0
			   END AS FLAG_FINALIZADO,
			   CASE 
				   WHEN p.status IN ('ganho','perdido') THEN DATEDIFF(DAY, p.data_abertura, p.data_fechamento)
				   ELSE NULL
			   END AS TEMPO_PROCESSO

		FROM processos AS p
		JOIN escritorios AS e
		ON e.id_escritorio = p.id_escritorio
			),

-- CTE ANOMALIAS     
	 anomalias AS(
		SELECT id_processo,
		'VALOR_ALTO' AS TIPO_ALERTA,
		'Processo com valor acima de 1500' AS DESCRICAO
		FROM processos
		WHERE valor > 150000
		UNION ALL
		SELECT id_processo,
		'TEMPO_ALTO',
		'Processo com duracao acima de 365 dias'
		FROM processos 
		WHERE status COLLATE SQL_Latin1_General_CP1_CI_AS IN ('ganho', 'perdido')
		AND DATEDIFF(DAY, data_abertura, data_fechamento) > 365
		UNION ALL 
		SELECT id_processo,
		'PROCESSO_ANTIGO', 
		'Processo ativo muito antigo'
		FROM processos
		WHERE status COLLATE SQL_Latin1_General_CP1_CI_AS = 'ativo'
		AND data_abertura < '2023-01-01'
				 ),

-- CTE SCORES
	 scores AS (
SELECT ID,
	   ESCRITORIO,
	   SUM(FLAG_ATIVO) AS QTDE_PROCESSOS_ATIVOS,
	   SUM(VALOR_ATIVO) AS RISCO_TOTAL_ATIVO,
	   CAST(
			ROUND(
				  AVG(SUM(VALOR_ATIVO)) OVER(),
				  2) AS DECIMAL(10,2)) AS RISCO_MEDIO_GERAL,
	   RANK() OVER(ORDER BY SUM(VALOR_ATIVO) DESC) AS RANKING_RISCO,
	   CAST(
		    ROUND(
				  SUM(VALOR_ATIVO) / NULLIF(SUM(FLAG_ATIVO), 0),
				  2) AS DECIMAL(10,2)) AS TICKET_MEDIO,	  
	  CAST(
		   ROUND(
				 SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0),
				 2) AS DECIMAL(10,0)) AS TAXA_SUCESSO,
	  CAST(
		   ROUND(AVG(TEMPO_PROCESSO), 
		   2) AS DECIMAL(10,2)) AS TEMPO_MEDIO_PROCESSO,
	   CASE
		   WHEN AVG(TEMPO_PROCESSO) >= 120 AND SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) < 60 THEN 'Gargalo'
		   WHEN AVG(TEMPO_PROCESSO) <= 120 AND SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) >= 60 THEN 'Eficiente'		   
		   ELSE 'Normal'
	   END AS CLASSIFICACAO_OPERACIONAL,
	   CASE
		   WHEN SUM(VALOR_ATIVO) >= AVG(SUM(VALOR_ATIVO)) OVER() AND SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) < 50 THEN 'Arriscado'
		   WHEN SUM(VALOR_ATIVO) >= AVG(SUM(VALOR_ATIVO)) OVER() AND SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) >= 50 THEN 'Rentável'
		   ELSE 'Moderado'
	   END AS CLASSIFICACAO_FINANCEIRA,
	   CASE
		   WHEN SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) >= 70 THEN 3
		   WHEN SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) >=50 AND SUM(FLAG_GANHO) * 100.0 / NULLIF(SUM(FLAG_FINALIZADO), 0) <70 THEN 2
		   ELSE 1
	   END SCORE_TAXA,
	   CASE
		   WHEN AVG(TEMPO_PROCESSO) < 120 THEN 3
		   WHEN AVG(TEMPO_PROCESSO) >= 120 AND AVG(TEMPO_PROCESSO) <= 180 THEN 2
		   ELSE 1
	   END SCORE_TEMPO,
	   CASE
		   WHEN SUM(VALOR_ATIVO) < AVG(SUM(VALOR_ATIVO)) OVER() THEN 3
		   ELSE 1
	   END SCORE_RISCO
FROM base 
GROUP BY ESCRITORIO, ID
                ),

	  scores_final AS (
         SELECT *,
                (SCORE_TAXA + SCORE_TEMPO + SCORE_RISCO) AS SCORE_FINAL
         FROM scores
					  ),

-- CTE ALERTAS POR ESCRITORIO				
	 alerta_por_escritorios AS(
SELECT p.id_escritorio AS ID_ESCRITORIO,
	   e.nome AS ESCRITORIO,
	   COUNT(*) AS QTDE_ALERTAS
FROM anomalias a 
JOIN processos p
ON a.id_processo = p.id_processo
JOIN escritorios e
ON e.id_escritorio = p.id_escritorio
GROUP BY p.id_escritorio, e.nome
	   
							 )
-- CONSULTA SCORES
/*SELECT *,
		(SCORE_TAXA + SCORE_TEMPO + SCORE_RISCO) AS SCORE_FINAL,
		CASE
			WHEN CLASSIFICACAO_OPERACIONAL = 'Gargalo' AND CLASSIFICACAO_FINANCEIRA = 'Arriscado' THEN 'CRITICO'
			WHEN CLASSIFICACAO_OPERACIONAL = 'Gargalo' OR CLASSIFICACAO_FINANCEIRA = 'Arriscado' THEN 'ATENCAO'
			ELSE 'OK'
		END ALERTA
FROM scores*/

-- CONSULTA ALERTAS POR PROCESSOS
/*SELECT TIPO_ALERTA, COUNT(*) AS QTDE_ALERTAS
FROM anomalias
GROUP BY TIPO_ALERTA */

-- CONSULTAS ALERTAS POR ESCRITÓRIO
/*SELECT e.nome, COUNT(*) AS QTDE_ALERTAS
FROM anomalias a
JOIN processos p
ON p.id_processo = a.id_processo
JOIN escritorios e
ON e.id_escritorio = p.id_escritorio
GROUP BY e.nome */

SELECT s.ESCRITORIO,
	   s.SCORE_FINAL,
	   ISNULL(a.QTDE_ALERTAS, 0) AS QTDE_ALERTAS,	  
	   CASE 
	       WHEN QTDE_ALERTAS = 0 THEN 'Saudável'
	       WHEN QTDE_ALERTAS <= 3 THEN 'Atenção'
	       ELSE 'Crítico'
	   END AS CLASSIFICACAO_ALERTAS
FROM scores_final s
LEFT JOIN alerta_por_escritorios a
ON s.ID = a.ID_ESCRITORIO
