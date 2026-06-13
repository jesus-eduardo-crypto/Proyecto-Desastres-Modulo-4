-- =============================================================================
-- Queries Analíticas — Riesgo de Desastres Naturales en México
-- =============================================================================
-- Técnicas avanzadas utilizadas:
--   ① CTE (WITH)                  → Queries 1, 2, 5
--   ② Funciones de ventana        → Queries 1 (DENSE_RANK), 2 (LAG), 5 (NTILE)
--   ③ Funciones predefinidas      → Query 3 (COUNT FILTER), Query 4 (PERCENTILE_CONT)
--   ④ Vista analítica             → Query 5 (CREATE OR REPLACE VIEW)
-- =============================================================================

SET search_path TO desastres;


-- =============================================================================
-- QUERY 1 — Ranking compuesto de riesgo por estado
--           Técnicas: CTE + DENSE_RANK (función de ventana)
-- =============================================================================
-- Combina tres métricas en un índice único. La suma de rangos individuales
-- permite comparar estados en diferentes escalas sin normalización arbitraria.
-- El estado con MENOR índice compuesto = MAYOR riesgo acumulado.
-- Pregunta que responde: ¿Qué entidades federativas presentan mayor exposición
-- al riesgo cuando se consideran simultáneamente desastres, emergencias y
-- población afectada?
-- =============================================================================

WITH metricas AS (
    SELECT
        de.entidad_federativa,
        SUM(fr.total_desastres)        AS desastres_totales,
        SUM(fr.total_emergencias)      AS emergencias_totales,
        SUM(fr.municipios_afectados)   AS municipios_totales,
        SUM(fr.poblacion_afectada)     AS poblacion_total_afectada,
        SUM(fr.inversion_prevencion)   AS inversion_total
    FROM      desastres.fact_riesgo  fr
    JOIN      desastres.dim_estado   de USING (id_estado)
    GROUP BY  de.entidad_federativa
),
ranking AS (
    SELECT
        entidad_federativa,
        desastres_totales,
        emergencias_totales,
        municipios_totales,
        ROUND(poblacion_total_afectada, 0)          AS poblacion_total_afectada,
        ROUND(inversion_total / 1e6, 2)             AS inversion_millones_mxn,
        DENSE_RANK() OVER (ORDER BY desastres_totales        DESC) AS rank_desastres,
        DENSE_RANK() OVER (ORDER BY emergencias_totales      DESC) AS rank_emergencias,
        DENSE_RANK() OVER (ORDER BY poblacion_total_afectada DESC) AS rank_poblacion
    FROM metricas
)
SELECT
    entidad_federativa,
    desastres_totales,
    emergencias_totales,
    poblacion_total_afectada,
    inversion_millones_mxn,
    rank_desastres,
    rank_emergencias,
    rank_poblacion,
    (rank_desastres + rank_emergencias + rank_poblacion) AS indice_riesgo_compuesto
FROM  ranking
ORDER BY indice_riesgo_compuesto ASC
LIMIT 15;


-- =============================================================================
-- QUERY 2 — Tendencia interanual de desastres por estado
--           Técnicas: CTE + LAG (función de ventana)
-- =============================================================================
-- Calcula el delta año a año de declaratorias de desastre por estado.
-- Delta positivo = situación empeoró ese año.
-- Delta negativo = situación mejoró ese año.
-- Pregunta que responde: ¿En qué estados y años se registraron los mayores
-- incrementos de declaratorias de desastre respecto al año anterior?
-- =============================================================================

WITH anual AS (
    SELECT
        de.entidad_federativa,
        dt.anio,
        SUM(fr.total_desastres)    AS desastres_anio,
        SUM(fr.total_emergencias)  AS emergencias_anio,
        SUM(fr.poblacion_afectada) AS poblacion_anio
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (id_estado)
    JOIN      desastres.dim_tiempo  dt USING (id_tiempo)
    GROUP BY  de.entidad_federativa, dt.anio
),
con_lag AS (
    SELECT
        entidad_federativa,
        anio,
        desastres_anio,
        emergencias_anio,
        LAG(desastres_anio)   OVER (PARTITION BY entidad_federativa ORDER BY anio)
            AS desastres_anio_anterior,
        desastres_anio
            - LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio)
            AS delta_desastres
    FROM anual
)
SELECT
    entidad_federativa,
    anio,
    desastres_anio,
    desastres_anio_anterior,
    delta_desastres,
    CASE
        WHEN delta_desastres > 0 THEN 'Empeora'
        WHEN delta_desastres < 0 THEN 'Mejora'
        WHEN delta_desastres = 0 THEN 'Sin cambio'
        ELSE 'Primer año registrado'
    END AS tendencia
FROM  con_lag
WHERE delta_desastres IS NOT NULL
ORDER BY delta_desastres DESC NULLS LAST
LIMIT 20;


-- =============================================================================
-- QUERY 3 — Inversión preventiva vs impacto observado
--           Técnicas: COUNT FILTER (función predefinida avanzada)
-- =============================================================================
-- COUNT(*) FILTER (WHERE condición) es la forma SQL estándar de hacer un
-- conteo condicional en una sola pasada, equivalente a un CASE WHEN manual
-- pero más legible y más eficiente en el plan de ejecución.
-- Pregunta que responde: ¿Qué estados registraron desastres en períodos sin
-- inversión preventiva y cuál es la eficiencia del gasto por declaratoria?
-- =============================================================================

SELECT
    de.entidad_federativa,
    COUNT(DISTINCT dt.anio)                                             AS anios_registrados,
    SUM(fr.total_desastres)                                             AS desastres_totales,
    SUM(fr.total_emergencias)                                           AS emergencias_totales,
    ROUND(SUM(fr.inversion_prevencion) / 1e6, 2)                       AS inversion_millones,
    -- Años en que hubo desastres pero CERO inversión preventiva
    COUNT(*) FILTER (
        WHERE fr.inversion_prevencion = 0
          AND fr.total_desastres > 0
    )                                                                   AS periodos_sin_inversion,
    -- Inversión promedio por cada desastre declarado (proxy de eficiencia)
    ROUND(
        SUM(fr.inversion_prevencion)
        / NULLIF(SUM(fr.total_desastres), 0) / 1e3,
        0
    )                                                                   AS miles_pesos_por_desastre
FROM      desastres.fact_riesgo fr
JOIN      desastres.dim_estado  de USING (id_estado)
JOIN      desastres.dim_tiempo  dt USING (id_tiempo)
GROUP BY  de.entidad_federativa
HAVING    SUM(fr.total_desastres) > 0
ORDER BY  periodos_sin_inversion DESC,
          miles_pesos_por_desastre ASC NULLS LAST;


-- =============================================================================
-- QUERY 4 — Distribución estadística de población afectada por fenómeno
--           Técnicas: PERCENTILE_CONT (función predefinida de orden)
-- =============================================================================
-- PERCENTILE_CONT es una función de conjunto ordenado (ordered-set aggregate).
-- La diferencia entre la mediana (P50) y el P95 revela si el fenómeno tiene
-- colas pesadas (pocos eventos de impacto masivo) o impacto homogéneo.
-- Pregunta que responde: ¿Qué tipo de fenómeno natural genera el mayor impacto
-- en población afectada y cómo se distribuye ese impacto estadísticamente?
-- =============================================================================

SELECT
    df.tipo_fenomeno,
    COUNT(*)                                                                    AS registros,
    SUM(fr.total_desastres)                                                     AS total_desastres,
    SUM(fr.total_emergencias)                                                   AS total_emergencias,
    ROUND(AVG(fr.poblacion_afectada), 0)                                        AS promedio_pob,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fr.poblacion_afectada))  AS p25_pob,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fr.poblacion_afectada))  AS mediana_pob,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fr.poblacion_afectada))  AS p75_pob,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY fr.poblacion_afectada))  AS p95_pob
FROM      desastres.fact_riesgo  fr
JOIN      desastres.dim_fenomeno df USING (id_fenomeno)
WHERE     fr.poblacion_afectada  > 0
GROUP BY  df.tipo_fenomeno
HAVING    SUM(fr.total_desastres) >= 3
ORDER BY  total_desastres DESC;


-- =============================================================================
-- QUERY 5 — Vista analítica de vulnerabilidad con clasificación por cuartiles
--           Técnicas: CTE + NTILE (función de ventana) + Vista persistente
-- =============================================================================
-- NTILE(4) divide los estados en 4 grupos de igual tamaño según su métrica.
-- Cuartil 1 de siniestralidad + Cuartil 1 de baja inversión = FOCO ROJO.
-- La vista persiste en el schema para ser consumida directamente por el dashboard.
-- Pregunta que responde: ¿Qué estados deben ser prioritarios para programas de
-- prevención por combinar alta siniestralidad con baja inversión preventiva?
-- =============================================================================

CREATE OR REPLACE VIEW desastres.v_vulnerabilidad_estados AS
WITH base AS (
    SELECT
        de.entidad_federativa,
        SUM(fr.total_desastres)        AS total_desastres,
        SUM(fr.total_emergencias)      AS total_emergencias,
        SUM(fr.municipios_afectados)   AS total_municipios_afectados,
        SUM(fr.poblacion_afectada)     AS total_poblacion_afectada,
        SUM(fr.inversion_prevencion)   AS total_inversion_prevencion,
        COUNT(DISTINCT dt.anio)        AS anios_con_registros
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (id_estado)
    JOIN      desastres.dim_tiempo  dt USING (id_tiempo)
    GROUP BY  de.entidad_federativa
),
cuartiles AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY (total_desastres + total_emergencias) DESC)
            AS cuartil_siniestralidad,
        NTILE(4) OVER (ORDER BY total_inversion_prevencion ASC)
            AS cuartil_baja_inversion
    FROM base
)
SELECT
    entidad_federativa,
    total_desastres,
    total_emergencias,
    total_municipios_afectados,
    ROUND(total_poblacion_afectada, 0)        AS total_poblacion_afectada,
    ROUND(total_inversion_prevencion / 1e6, 2) AS inversion_millones_mxn,
    anios_con_registros,
    cuartil_siniestralidad,
    cuartil_baja_inversion,
    CASE
        WHEN cuartil_siniestralidad = 1 AND cuartil_baja_inversion = 1
            THEN 'FOCO ROJO'
        WHEN cuartil_siniestralidad = 1 AND cuartil_baja_inversion IN (2, 3)
            THEN 'Alta siniestralidad'
        WHEN cuartil_siniestralidad = 1 AND cuartil_baja_inversion = 4
            THEN 'Alta siniestralidad — bien invertido'
        WHEN cuartil_siniestralidad = 2
            THEN 'Siniestralidad moderada'
        ELSE 'Riesgo bajo'
    END AS clasificacion_prioridad
FROM cuartiles
ORDER BY cuartil_siniestralidad ASC, cuartil_baja_inversion ASC;


-- Consultar la vista
SELECT * FROM desastres.v_vulnerabilidad_estados;
