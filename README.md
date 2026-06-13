# 🌋 Riesgo de Desastres Naturales en México — Data Warehouse

![Status](https://img.shields.io/badge/Status-Completado-brightgreen)
![DB](https://img.shields.io/badge/DB-Amazon%20Aurora%20PostgreSQL-orange)
![Python](https://img.shields.io/badge/Python-3.10%2B-blue)
![License](https://img.shields.io/badge/Licencia-Datos%20Abiertos%20MX-lightgrey)
![Fuente](https://img.shields.io/badge/Fuente-SSPC%20%2F%20CNPC-red)

> **Proyecto Final — Data Analytics** · Amazon Aurora PostgreSQL · Plotly · Jupyter

---

## 📋 Resumen ejecutivo

| Campo | Valor |
|---|---|
| **Pregunta analítica** | ¿Qué entidades federativas presentan mayor exposición al riesgo de desastres naturales y deberían ser prioritarias para programas de prevención federal? |
| **Dataset** | Declaratorias de desastre, emergencia y proyectos de prevención — SSPC/CNPC · 2013–2024 · **~12,000 filas** en staging (3 tablas) |
| **Fuente oficial** | [Gestión de Riesgos — datos.gob.mx](https://datos.gob.mx/dataset/gestion_riesgos) |
| **Modelo** | Estrella: 1 fact + 4 dimensiones (estado, tiempo, fenómeno, programa de prevención) |
| **Infraestructura** | Amazon Aurora PostgreSQL — schema `desastres`, administrado desde DBeaver |
| **ETL** | `etl_pipeline.py` end-to-end — pandas + SQLAlchemy + validaciones post-carga |
| **SQL avanzado** | CTE + `DENSE_RANK`, CTE + `LAG`, `COUNT FILTER`, `PERCENTILE_CONT`, CTE + `NTILE` + Vista |
| **Dashboard** | Jupyter + Plotly: 5 visualizaciones interactivas exportables como HTML/PNG |

---

## 🎯 1. Problema y motivación

### Contexto

México ocupa el lugar **34 de 191 países** en el Índice de Riesgo Mundial (World Risk Index 2023), con exposición simultánea a sismos, huracanes, inundaciones, sequías e incendios forestales. Entre 2013 y 2024, la Coordinación Nacional de Protección Civil (CNPC) emitió más de **600 declaratorias de desastre** y casi **1,000 declaratorias de emergencia**, movilizando miles de millones de pesos en recursos de atención y reconstrucción.

El problema de fondo no es la ocurrencia de los desastres —inevitable en un territorio de esta exposición geográfica— sino la **asignación ineficiente de los recursos de prevención**. Los datos de este proyecto revelan que tres estados clasificados como **FOCO ROJO** (Veracruz, Tabasco, Baja California Sur) concentran alta siniestralidad histórica con **inversión preventiva registrada de cero pesos**, mientras que estados de riesgo moderado sí presentan gasto preventivo documentado.

### Pregunta analítica

> **¿Qué entidades federativas presentan mayor exposición al riesgo de desastres naturales —medida por número de declaratorias, población afectada y municipios involucrados— y deberían ser prioritarias para programas de prevención federal?**

### Sub-preguntas analíticas

| # | Sub-pregunta | Técnica SQL | Visualización |
|---|---|---|---|
| 1 | ¿Qué estados concentran más declaratorias históricas? | CTE + `DENSE_RANK` | Barras horizontales (Viz 1) |
| 2 | ¿La frecuencia de desastres aumenta o mejora año a año? | CTE + `LAG` | Serie temporal (Viz 2) |
| 3 | ¿Hay correlación entre inversión preventiva y desastres? | `COUNT FILTER` | Scatter de burbujas (Viz 3) |
| 4 | ¿Qué fenómenos generan mayor impacto en población? | `PERCENTILE_CONT` | Barras + Pie (Viz 4) |
| 5 | ¿Qué estados son foco rojo de política pública? | CTE + `NTILE` + Vista | Tabla de prioridad (Viz 5) |

---

## 📦 2. Origen de los datos

### Fuentes

Las tres fuentes son registros administrativos oficiales publicados por la **Secretaría de Seguridad y Protección Ciudadana (SSPC)** a través de la **Coordinación Nacional de Protección Civil (CNPC)**, bajo licencia abierta en [datos.gob.mx/dataset/gestion_riesgos](https://datos.gob.mx/dataset/gestion_riesgos). El dataset se actualiza trimestralmente.

| Tabla staging | Fuente | Periodo | Filas aprox. | Descripción |
|---|---|---|---|---|
| `stg_declaratorias_desastre` | SSPC / CNPC | 2013–2024 | ~4,000 | Declaratorias emitidas con fenómeno, municipios corroborados y sectores afectados |
| `stg_declaratorias_emergencia` | SSPC / CNPC | 2013–2024 | ~6,000 | Emergencias con población afectada, apoyos entregados y costos por declaratoria |
| `stg_proyectos_prevencion` | SSPC / CNPC | 2013–2024 | ~2,000 | Proyectos preventivos federales autorizados con monto y beneficiarios |
| **Total staging** | | | **~12,000** | |

### Justificación del dataset

El dataset supera las **12,000 filas** en staging y cubre **10 años de historia** (2013–2024), lo que permite análisis de tendencias estadísticamente significativos. La combinación de tres fuentes complementarias es lo que habilita la pregunta analítica: ninguna fuente individualmente permite cruzar siniestralidad con inversión preventiva.

Las tablas fueron cargadas íntegramente como `TEXT` en Aurora para evitar errores de tipo durante la ingesta. El ETL en Python es responsable del cast, limpieza y normalización antes de poblar el modelo dimensional.

> ⚠️ Los archivos fuente mezclan formatos dentro de la misma columna: montos como `"$1,200,000.00"`, `"1200000"` y `"N/D"` coexisten en `costo_total_declaratoria`. La estrategia **cargar-primero-limpiar-después** es la práctica estándar en Data Engineering cuando la fuente no garantiza calidad de datos.

### Hallazgos observados en los datos reales

**📊 Ranking de siniestralidad (Viz 1):**
- **Chiapas** lidera con 115 declaratorias de desastre y 140 de emergencia — el estado más expuesto del país en el período analizado.
- **Veracruz** ocupa el segundo lugar (95 desastres, 100 emergencias), seguido de **Oaxaca** (70 desastres, 185 emergencias).
- El podio de emergencias lo encabeza **Oaxaca** con 185 declaratorias, lo que sugiere una capacidad de respuesta inmediata mayor que su número de desastres indicaría.

**📈 Tendencia temporal (Viz 2):**
- El año **2020** fue el más crítico del período: 235 declaratorias de desastre y 415 de emergencia a nivel nacional — convergencia de fenómenos hidrometeorológicos extremos con la crisis sanitaria del COVID-19.
- A partir de 2021 se observa una reducción sostenida, aunque los datos de 2024 son parciales.
- Los años 2016 y 2017 no tienen registros en el dataset, posiblemente por vacío de carga en los archivos fuente o reclasificación administrativa.

**🔵 Inversión preventiva vs siniestralidad (Viz 3):**
- **Baja California Sur, Tabasco y Veracruz** son clasificados como **FOCO ROJO**: alta siniestralidad con inversión preventiva registrada de cero pesos.
- **Durango, Oaxaca y Guerrero** presentan alta siniestralidad sin inversión, clasificados como "Alta siniestralidad".
- Ningún estado del top-15 por desastres muestra inversión preventiva proporcional a su riesgo.

**🌀 Distribución por fenómeno (Viz 4):**
- El fenómeno **Hidrometeorológico** domina con 485 declaratorias (≈80% del total).
- El fenómeno **Geológico** representa 110 declaratorias (≈18%), incluyendo sismos y deslizamientos.
- **Incendio Forestal** contribuye con 15 declaratorias (≈2%).

**🗂️ Clasificación de prioridad (Viz 5):**
- **3 estados FOCO ROJO**, **4 de Alta siniestralidad**, **7 de Siniestralidad moderada** y **14 de Riesgo bajo**.
- Los 7 estados de mayor exposición (cuartiles 1 y 2) acumulan más del **70% de las declaratorias nacionales**.

---

## 🏗️ 3. Modelo dimensional

### Esquema estrella

```
                          ┌──────────────────────┐
                          │      dim_tiempo       │
                          │  id_tiempo   PK       │
                          │  anio        INTEGER  │
                          └───────────┬───────────┘
                                      │
┌─────────────────────┐    ┌──────────┴─────────────────────────┐    ┌──────────────────────┐
│     dim_estado      │    │           fact_riesgo               │    │    dim_fenomeno       │
│  id_estado    PK    │◄───│  id_riesgo            PK           │───►│  id_fenomeno   PK    │
│  entidad_feder.     │    │  id_estado            FK           │    │  tipo_fenomeno       │
└─────────────────────┘    │  id_tiempo            FK           │    └──────────────────────┘
                           │  id_fenomeno          FK           │
                           │  total_desastres     INTEGER       │
                           │  total_emergencias   INTEGER       │
                           │  municipios_afect.   INTEGER       │
                           │  poblacion_afectada  NUMERIC       │
                           │  inversion_prev.     NUMERIC       │
                           └─────────────────────────────────────┘

        ┌─────────────────────────────────┐
        │    dim_programa_prevencion      │
        │  id_programa      PK            │
        │  nombre_proyecto  TEXT          │
        │  tipo_proyecto    TEXT          │
        │  estatus          TEXT          │
        └─────────────────────────────────┘
        (dimensión complementaria — inversion_prevencion
         se agrega directamente en fact_riesgo)
```

### Grano de la fact

**Una fila por `(entidad federativa × año × tipo de fenómeno)`.** Este grano permite responder las cinco sub-preguntas: comparar estados en el mismo período, analizar tendencias temporales, cruzar inversión con ocurrencia y clasificar estados por vulnerabilidad relativa.

---

## 📐 4. Decisiones de diseño

**`dim_programa_prevencion` desacoplada de `fact_riesgo`.**
La granularidad de los proyectos preventivos (un proyecto puede abarcar múltiples años y fenómenos) no encaja en el grano estado × año × fenómeno. Forzar esa FK requeriría distribuir arbitrariamente el costo entre varios registros. La inversión se agrega directamente en `inversion_prevencion` de la fact, siguiendo el principio Kimball de *no distorsionar la fact para forzar una dimensión que no le corresponde*.

**`total_desastres` y `total_emergencias` como columnas separadas.**
Una declaratoria de desastre y una de emergencia son instrumentos jurídicos distintos con criterios de activación diferentes. El ratio emergencias/desastres es en sí mismo un indicador analítico: Oaxaca (185 emergencias vs 70 desastres) sugiere alta capacidad de activar el mecanismo de emergencia sin alcanzar el umbral de desastre.

**`dim_fenomeno` sin jerarquía.**
El catálogo de la CNPC no distingue sistemáticamente entre tipo de fenómeno (e.g., "Hidrometeorológico") y amenaza específica (e.g., "Huracán"). La dimensión queda plana para no inventar una jerarquía que el origen no soporta.

**Surrogate keys `SERIAL` en minúsculas.**
PostgreSQL normaliza identificadores sin comillas dobles a minúsculas. Las surrogate keys (`id_estado`, `id_tiempo`, `id_fenomeno`) aíslan la fact de variaciones ortográficas en los datos fuente.

**Carga de datos crudos como `TEXT` → transform en Python.**
Los archivos fuente del SSPC mezclan formatos en la misma columna. La estrategia cargar-primero-limpiar-después es práctica estándar cuando la fuente no garantiza calidad de datos.

---

## 📁 5. Estructura del repositorio

```
desastres-naturales-mx/
├── README.md                           ← este archivo
├── scripts/
│   ├── 01_schema_ddl.sql               ← DDL del star schema
│   └── etl_pipeline.py                 ← ETL Python end-to-end
├── analisis/
│   └── queries_analiticas.sql          ← 5 queries SQL avanzado
└── dashboard/
    ├── dashboard.ipynb                 ← Notebook con 5 visualizaciones Plotly
    ├── Visualizacion_1.html            ← Ranking de estados (exportada)
    ├── Visualizacion_2.html            ← Serie temporal (exportada)
    ├── Visualizacion_3.html            ← Scatter inversión vs desastres (exportada)
    ├── Visualizacion_4.html            ← Distribución por fenómeno (exportada)
    └── Visualizacion_5.html            ← Tabla de prioridad (exportada)
```

---

## ⚙️ 6. Cómo ejecutar

### Prerequisitos

```bash
pip install pandas sqlalchemy psycopg2-binary tqdm plotly kaleido
```

### Paso 1 — Staging tables pobladas

Las tres tablas `stg_*` deben estar cargadas en Aurora antes de correr el ETL. Cárgalas desde los CSVs del dataset [Gestión de Riesgos](https://datos.gob.mx/dataset/gestion_riesgos) usando DBeaver o el Import Wizard de Aurora.

### Paso 2 — Crear el star schema

```sql
-- Ejecutar desde DBeaver o psql
\i scripts/01_schema_ddl.sql
```

### Paso 3 — Ejecutar el ETL

```bash
python scripts/etl_pipeline.py \
    --host   TU_AURORA_ENDPOINT.rds.amazonaws.com \
    --port   5432 \
    --db     TU_DATABASE \
    --password TU_PASSWORD
```

El script reporta progreso en cada etapa y ejecuta validaciones post-carga: chequeos de FK nulas, valores negativos y resumen de totales.

### Paso 4 — Crear la vista analítica

```sql
-- Ejecutar Query 5 de analisis/queries_analiticas.sql
-- Crea: desastres.v_vulnerabilidad_estados
```

### Paso 5 — Ejecutar el dashboard

```bash
jupyter notebook dashboard/dashboard.ipynb
# 1. Editar la celda de configuración con host y password de Aurora
# 2. Kernel → Restart & Run All
# 3. Las visualizaciones ya están exportadas en dashboard/Visualizacion_*.html
```

---

## 💻 7. SQL avanzado

Cinco queries en `analisis/queries_analiticas.sql` que cubren las técnicas avanzadas del módulo:

| Query | Técnica | Pregunta que responde |
|---|---|---|
| 1 | CTE + `DENSE_RANK` | Ranking compuesto por 3 métricas simultáneas |
| 2 | CTE + `LAG` | Delta interanual — ¿la situación mejora o empeora? |
| 3 | `COUNT FILTER` | Períodos con desastres sin inversión preventiva |
| 4 | `PERCENTILE_CONT` | Distribución estadística P25/P50/P75/P95 por fenómeno |
| 5 | CTE + `NTILE` + Vista | Clasificación cuartil persistente en Aurora |

### Query 1 — Ranking compuesto de riesgo (CTE + DENSE_RANK)

```sql
WITH metricas AS (
    SELECT
        de.entidad_federativa,
        SUM(fr.total_desastres)      AS desastres_totales,
        SUM(fr.total_emergencias)    AS emergencias_totales,
        SUM(fr.poblacion_afectada)   AS poblacion_total_afectada
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (id_estado)
    GROUP BY  de.entidad_federativa
),
ranking AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY desastres_totales        DESC) AS rank_desastres,
        DENSE_RANK() OVER (ORDER BY emergencias_totales      DESC) AS rank_emergencias,
        DENSE_RANK() OVER (ORDER BY poblacion_total_afectada DESC) AS rank_poblacion
    FROM metricas
)
SELECT
    entidad_federativa,
    desastres_totales,
    emergencias_totales,
    (rank_desastres + rank_emergencias + rank_poblacion) AS indice_riesgo_compuesto
FROM  ranking
ORDER BY indice_riesgo_compuesto
LIMIT 10;
```

### Query 2 — Tendencia interanual (CTE + LAG)

```sql
WITH anual AS (
    SELECT
        de.entidad_federativa,
        dt.anio,
        SUM(fr.total_desastres) AS desastres_anio
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (id_estado)
    JOIN      desastres.dim_tiempo  dt USING (id_tiempo)
    GROUP BY  de.entidad_federativa, dt.anio
)
SELECT
    entidad_federativa,
    anio,
    desastres_anio,
    LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) AS anio_anterior,
    desastres_anio
        - LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) AS delta,
    CASE
        WHEN desastres_anio
             - LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) > 0
        THEN 'Empeora'
        WHEN desastres_anio
             - LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) < 0
        THEN 'Mejora'
        ELSE 'Sin cambio'
    END AS tendencia
FROM  anual
WHERE desastres_anio IS NOT NULL
ORDER BY delta DESC NULLS LAST
LIMIT 15;
```

### Query 3 — Inversión vs impacto (COUNT FILTER)

```sql
SELECT
    de.entidad_federativa,
    SUM(fr.total_desastres)                                          AS desastres,
    ROUND(SUM(fr.inversion_prevencion) / 1e6, 2)                    AS inversion_millones,
    -- Períodos con desastres pero CERO inversión
    COUNT(*) FILTER (WHERE fr.inversion_prevencion = 0
                       AND fr.total_desastres > 0)                   AS periodos_sin_inversion,
    ROUND(SUM(fr.inversion_prevencion)
          / NULLIF(SUM(fr.total_desastres), 0) / 1e3, 0)            AS miles_pesos_por_desastre
FROM      desastres.fact_riesgo fr
JOIN      desastres.dim_estado  de USING (id_estado)
GROUP BY  de.entidad_federativa
HAVING    SUM(fr.total_desastres) > 0
ORDER BY  periodos_sin_inversion DESC, miles_pesos_por_desastre ASC NULLS LAST;
```

### Query 4 — Distribución estadística por fenómeno (PERCENTILE_CONT)

```sql
SELECT
    df.tipo_fenomeno,
    COUNT(*)                                                                    AS registros,
    SUM(fr.total_desastres)                                                     AS total_desastres,
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
```

### Query 5 — Vista analítica de vulnerabilidad (CTE + NTILE)

```sql
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
    SELECT *,
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
    ROUND(total_poblacion_afectada, 0)         AS total_poblacion_afectada,
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
ORDER BY cuartil_siniestralidad, cuartil_baja_inversion;

-- Consultar la vista
SELECT * FROM desastres.v_vulnerabilidad_estados;
```

---

## 📊 8. Dashboard

Cinco visualizaciones interactivas en Plotly, ejecutadas en `dashboard/dashboard.ipynb` y exportadas como HTML independientes:

| Viz | Tipo | Hallazgo clave |
|---|---|---|
| [Viz 1](dashboard/Visualizacion_1.html) | Barras horizontales agrupadas | Chiapas (115 des.), Veracruz (95) y Oaxaca (70) lideran el ranking |
| [Viz 2](dashboard/Visualizacion_2.html) | Líneas temporales | 2020 fue el año pico: 235 desastres y 415 emergencias nacionales |
| [Viz 3](dashboard/Visualizacion_3.html) | Scatter de burbujas | Veracruz, Tabasco y BCS son FOCO ROJO: alto riesgo, inversión = $0 |
| [Viz 4](dashboard/Visualizacion_4.html) | Barras + Pie | Hidrometeorológico representa el 80% de todas las declaratorias |
| [Viz 5](dashboard/Visualizacion_5.html) | Tabla `go.Table` Plotly | 3 estados FOCO ROJO, 4 de Alta siniestralidad identificados |

---

## 🔍 9. Hallazgos y conclusiones

### Hallazgos confirmados por los datos

1. **Chiapas, Veracruz y Oaxaca** son los estados de mayor siniestralidad acumulada del período 2013–2024. Chiapas lidera con 115 declaratorias de desastre y Oaxaca encabeza las emergencias con 185.

2. **El año 2020 concentra la mayor crisis**: 235 declaratorias de desastre y 415 de emergencia a nivel nacional. La convergencia de fenómenos hidrometeorológicos extremos con la pandemia de COVID-19 sobrepasó los mecanismos institucionales de atención simultánea.

3. **El fenómeno Hidrometeorológico domina con el 80%** del total de declaratorias (485 de ~610). Los eventos geológicos representan el 18% restante pero tienen impactos puntuales de mayor magnitud.

4. **La paradoja de inversión se confirma**: los 3 estados FOCO ROJO (Veracruz, Tabasco, Baja California Sur) tienen inversión preventiva registrada de **cero pesos** pese a concentrar décadas de siniestralidad. Los recursos federales fluyen hacia reconstrucción pero no hacia prevención en los estados más vulnerables.

5. **La concentración del riesgo es estructural**: 7 de los 28 estados con registros (25%) acumulan más del 70% de todas las declaratorias nacionales.

### Respuesta a la pregunta analítica

Los estados **prioritarios para programas de prevención federal**, en orden de urgencia:

| Prioridad | Estado | Clasificación | Fundamento |
|---|---|---|---|
| 🔴 1 | Veracruz | FOCO ROJO | 95 desastres · 100 emergencias · inversión = $0 |
| 🔴 2 | Tabasco | FOCO ROJO | 25 desastres · 40 emergencias · inversión = $0 |
| 🔴 3 | Baja California Sur | FOCO ROJO | 40 desastres · 40 emergencias · inversión = $0 |
| 🟠 4 | Chiapas | Alta siniestralidad | 115 desastres — mayor siniestralidad del período |
| 🟠 5 | Oaxaca | Alta siniestralidad | 185 emergencias — mayor volumen de emergencias del país |

---

## 📚 Referencias

- [Gestión de Riesgos — datos.gob.mx (SSPC / CNPC)](https://datos.gob.mx/dataset/gestion_riesgos)
- [CENAPRED — Atlas Nacional de Riesgos](http://www.atlasnacionalderiesgos.gob.mx/)
- [World Risk Index 2023 — Bündnis Entwicklung Hilft](https://weltrisikobericht.de/world-risk-report-2023/)
- [FONDEN — Reglas de Operación del Fondo de Desastres Naturales, DOF 2014](https://www.dof.gob.mx/nota_detalle.php?codigo=5374167&fecha=03/12/2014)
- [Auditoría Superior de la Federación — Gestión de Desastres en México: fase de prevención (2024)](https://www.asf.gob.mx/uploads/6485_Centro_de_Estudios_de_la_ASF/241128_Analisis_Prevencion_01.pdf)
- Material del módulo: Tema 02 (Modelo Dimensional), Tema 04 (ETL Python), Tema 05 (SQL Avanzado)

---

<p align="center">
  <em>Proyecto Final — Data Analytics · Amazon Aurora PostgreSQL · Plotly · Jupyter</em><br/>
  <sub>Datos: SSPC / Coordinación Nacional de Protección Civil · <a href="https://datos.gob.mx/dataset/gestion_riesgos">datos.gob.mx/dataset/gestion_riesgos</a></sub>
</p>
