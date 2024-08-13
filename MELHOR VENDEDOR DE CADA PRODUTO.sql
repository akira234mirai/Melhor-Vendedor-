USE sigaoficial;

DECLARE 
    @DT_INI DATE,
    @DT_FIN DATE;

SET @DT_INI = '20240701';
SET @DT_FIN = '20240728';

-- CTE para Faturamento de Notas Fiscais
WITH FaturamentoNotas AS (
    SELECT 
        C5_VEND1 AS COD_VEND, 
        RTRIM(A3_NREDUZ) AS NOME,
        RTRIM(B1_XDESCM) AS MARCA,
        ROUND(SUM(D2_VALBRUT - D2_SEGURO), 2) AS FATURAMENTO
    FROM SC5010 
    JOIN SD2010 SD2 
        ON D2_PEDIDO = C5_NUM 
        AND D2_FILIAL = C5_FILIAL 
        AND SD2.D_E_L_E_T_ = '' 
    JOIN SA3010 
        ON A3_COD = C5_VEND1 
        AND SA3010.D_E_L_E_T_ = ''
    JOIN SB1010 
        ON B1_COD = D2_COD
    WHERE SC5010.D_E_L_E_T_ = '' 
        AND C5_X_TPOPE IN ('01','09','18') 
        AND D2_TIPO = 'N'
        AND D2_EMISSAO >= @DT_INI 
        AND D2_EMISSAO <= @DT_FIN
    GROUP BY
        C5_VEND1, A3_NREDUZ, B1_XDESCM
),

-- CTE para Faturamento de Devoluções
FaturamentoDevolucoes AS (
    SELECT 
        C5_VEND1 AS COD_VEND, 
        RTRIM(A3_NREDUZ) AS NOME,
        RTRIM(B1_XDESCM) AS MARCA,
        ROUND(SUM(-D1_TOTAL), 2) AS FATURAMENTO
    FROM SD1010 
    JOIN SC5010 
        ON C5_NOTA = D1_NFORI 
        AND C5_FILIAL = D1_FILORI 
        AND SC5010.D_E_L_E_T_ = '' 
        AND C5_X_TPOPE IN ('01','09','18')
    JOIN SA3010 
        ON A3_COD = C5_VEND1 
        AND SA3010.D_E_L_E_T_ = ''
    JOIN SB1010 
        ON B1_COD = D1_COD
    WHERE SD1010.D_E_L_E_T_ = '' 
        AND D1_TIPO = 'D'
        AND D1_DTDIGIT >= @DT_INI 
        AND D1_DTDIGIT <= @DT_FIN
    GROUP BY
        C5_VEND1, A3_NREDUZ, B1_XDESCM
),

-- CTE combinada para somar faturamento de notas fiscais e subtrair devoluções
FaturamentoTotal AS (
    SELECT 
        COD_VEND,
        NOME,
        MARCA,
        SUM(FATURAMENTO) AS FATURAMENTO
    FROM (
        SELECT 
            C5_VEND1 AS COD_VEND, 
            RTRIM(A3_NREDUZ) AS NOME,
            RTRIM(B1_XDESCM) AS MARCA,
            ROUND(SUM(D2_VALBRUT - D2_SEGURO), 2) AS FATURAMENTO
        FROM SC5010 
        JOIN SD2010 SD2 
            ON D2_PEDIDO = C5_NUM 
            AND D2_FILIAL = C5_FILIAL 
            AND SD2.D_E_L_E_T_ = '' 
        JOIN SA3010 
            ON A3_COD = C5_VEND1 
            AND SA3010.D_E_L_E_T_ = ''
        JOIN SB1010 
            ON B1_COD = D2_COD
        WHERE SC5010.D_E_L_E_T_ = '' 
            AND C5_X_TPOPE IN ('01','09','18') 
            AND D2_TIPO = 'N'
            AND D2_EMISSAO >= @DT_INI 
            AND D2_EMISSAO <= @DT_FIN
        GROUP BY
            C5_VEND1, A3_NREDUZ, B1_XDESCM

        UNION ALL

        SELECT 
            C5_VEND1 AS COD_VEND, 
            RTRIM(A3_NREDUZ) AS NOME,
            RTRIM(B1_XDESCM) AS MARCA,
            ROUND(SUM(-D1_TOTAL), 2) AS FATURAMENTO
        FROM SD1010 
        JOIN SC5010 
            ON C5_NOTA = D1_NFORI 
            AND C5_FILIAL = D1_FILORI 
            AND SC5010.D_E_L_E_T_ = '' 
            AND C5_X_TPOPE IN ('01','09','18')
        JOIN SA3010 
            ON A3_COD = C5_VEND1 
            AND SA3010.D_E_L_E_T_ = ''
        JOIN SB1010 
            ON B1_COD = D1_COD
        WHERE SD1010.D_E_L_E_T_ = '' 
            AND D1_TIPO = 'D'
            AND D1_DTDIGIT >= @DT_INI 
            AND D1_DTDIGIT <= @DT_FIN
        GROUP BY
            C5_VEND1, A3_NREDUZ, B1_XDESCM
    ) AS SubQuery
    GROUP BY 
        COD_VEND, 
        NOME, 
        MARCA
),

-- CTE para selecionar o melhor faturamento por vendedor e marca
MelhorFaturamentoPorVendedor AS (
    SELECT 
        COD_VEND,
        NOME,
        MARCA,
        FATURAMENTO,
        ROW_NUMBER() OVER (PARTITION BY COD_VEND ORDER BY FATURAMENTO DESC) AS RN
    FROM FaturamentoTotal
)

-- Seleção final dos melhores faturamentos por vendedor e marca
SELECT 
    MF.COD_VEND,
    MF.NOME,
    MF.MARCA,
    MF.FATURAMENTO
FROM MelhorFaturamentoPorVendedor MF
WHERE MF.RN = 1
ORDER BY MF.NOME ;
