# Riesgo de Desastres Naturales en México — Data Warehouse

## :clipboard: Resumen ejecutivo

| Campo | Valor |
|---|---|
| **Pregunta analítica** | ¿Qué entidades federativas presentan mayor exposición al riesgo de desastres naturales y deberían ser prioritarias para programas de prevención federal? |
| **Dataset** | Declaratorias de desastre, emergencia y proyectos de prevención — SSPC/CENAPRED · 2013–2024 · **~12,000 filas** en staging (3 tablas) |
| **Fuente** | [Datos Abiertos del Gobierno de México — SSPC](https://datos.gob.mx/busca/dataset/declaratorias-de-desastre-y-emergencia) |
| **Modelo** | Estrella: 1 fact + 4 dimensiones (estado, tiempo, fenómeno, programa de prevención) |
| **Infraestructura** | Amazon Aurora PostgreSQL — schema `desastres`, administrado desde DBeaver |
| **ETL** | `etl_pipeline.py` end-to-end — pandas + SQLAlchemy + validaciones post-carga |
| **SQL avanzado** | CTE + `DENSE_RANK`, CTE + `LAG`, `COUNT FILTER`, `PERCENTILE_CONT`, CTE + `NTILE` + Vista |
| **Dashboard** | Jupyter + Plotly: 5 visualizaciones interactivas exportables como HTML/PNG |

---

## :dart: 1. Problema y motivación

### Contexto

M�xico ocupa el lugar 34 de 191 países en el Índice de Riesgo Mundial (World Risk Index 2023), con exposición simultánea a sismos, huracanes, inundaciones, sequías e incendios forestales. Entre 2013 y 2024, el gobierno federal emitió más de **600 declaratorias de desastre** y casi **1,000 declaratorias de emergencia**, movilizando miles de millones de pesos en recursos de atención y reconstrucción.

El problema de fondo no es la ocurrencia de los desastres —inevitable en un territorio de esta exposición geográfica— sino la **asignación ineficiente de los recursos de prevención**. Los datos de este proyecto revelan que tres estados clasificados como **FOCO ROJO** (Veracruz, Tabasco, Baja California Sur) concentran alta siniestralidad histórica con **inversión preventiva registrada de cero pesos**, mientras que estados de riesgo moderado sí presentan gasto preventivo documentado.

### Pregunta analítica

> **¿Qué entidades federativas presentan mayor exposición al riesgo de desastres naturales —medida por número de declaratorias, población afectada y municipios involucrados— y deberían ser prioritarias para programas de prevención federal?**

La pregunta es **accionable**: su respuesta produce un ranking de prioridad de política pública directamente utilizable por la SSPC para la asignación del Fondo de Prevención de Desastres Naturales (FOPREDEN). No es una pregunta descriptiva de tipo "¿cuántos registros hay?" sino una pregunta de priorización con consecuencias presupuestales reales.

### Cuatro sub-preguntas analíticas

| # | Sub-pregunta | Técnica SQL | Visualización |
|---|---|---|---|
| 1 | ¿Qué estados concentran más declaratorias históricas? | CTE + `DENSE_RANK` | Barras horizontales (Viz 1) |
| 2 | ¿La frecuencia de desastres aumenta o mejora año a año? | CTE + `LAG` | Serie temporal (Viz 2) |
| 3 | ¿Hay correlación entre inversión preventiva y desastres? | `COUNT FILTER` | Scatter de burbujas (Viz 3) |
| 4 | ¿Qué fenómenos generan mayor impacto en población? | `PERCENTILE_CONT` | Barras + Pie (Viz 4) |
| 5 | ¿Qué estados son foco rojo de política pública? | CTE + `NTILE` + Vista | Tabla de prioridad (Viz 5) |

---

## :package: 2. Origen de los datos

### Fuentes

Las tres fuentes son registros administrativos oficiales del Gobierno Federal, publicados bajo licencia abierta en datos.gob.mx:

| Tabla staging | Fuente | Periodo | Filas aprox. | Descripción |
|---|---|---|---|---|
| `stg_declaratorias_desastre` | SSPC | 2013–2024 | ~4,000 | Declaratorias emitidas con fenómeno, municipios corroborados y sectores afectados |
| `stg_declaratorias_emergencia` | SSPC | 2013–2024 | ~6,000 | Emergencias con población afectada, apoyos entregados y costos por declaratoria |
| `stg_proyectos_prevencion` | CENAPRED | 2013–2024 | ~2,000 | Proyectos preventivos federales autorizados con monto y beneficiarios |
| **Total staging** | | | **~12,000** | |

### Justificación del dataset

El dataset supera las **12,000 filas** en staging y cubre **10 años de historia** (2013–2024), lo que permite análisis de tendencias estadísticamente significativos. La combinación de tres fuentes complementarias es precisamente lo que habilita la pregunta analítica: ninguna fuente individualmente permite cruzar siniestralidad con inversión preventiva.

Las tablas fueron cargadas íntegramente como `TEXT` en Aurora para evitar errores de tipo durante la ingesta. El ETL en Python es responsable del cast, limpieza y normalización antes de poblar el modelo dimensional.

### Hallazgos observados en los datos reales

Los datos procesados y visualizados revelan los siguientes hechos concretos:

**Ranking de siniestralidad (Viz 1):**
- **Chiapas** lidera con 115 declaratorias de desastre y 140 de emergencia — el estado más expuesto del país en el período analizado.
- **Veracruz** ocupa el segundo lugar (95 desastres, 100 emergencias), seguido de **Oaxaca** (70 desastres, 185 emergencias).
- El podio de emergencias lo encabeza **Oaxaca** con 185 declaratorias, lo que sugiere una capacidad de respuesta inmediata mayor que su número de desastres indicaría.

**Tendencia temporal (Viz 2):**
- El año **2020** fue el más crítico del período: 235 declaratorias de desastre y 415 de emergencia a nivel nacional — una convergencia inédita de fenómenos hidrometeorológicos con la crisis sanitaria del COVID-19 que saturó los mecanismos de atención simultáneamente.
- A partir de 2021 se observa una reducción sostenida, aunque los datos de 2024 son parciales.
- Los años 2016 y 2017 no tienen registros en el dataset, lo que puede reflejar un vacío de carga en los archivos fuente o una reclasificación administrativa de esos años.

**Inversión preventiva vs siniestralidad (Viz 3):**
- **Baja California Sur, Tabasco y Veracruz** son clasificados como **FOCO ROJO**: alta siniestralidad con inversión preventiva registrada de cero pesos. Esta es la brecha de política pública más crítica que identifica el proyecto.
- **Durango, Oaxaca y Guerrero** presentan alta siniestralidad sin inversión, clasificados como "Alta siniestralidad" (cuartil 2 de inversión).
- Ningún estado del top-15 por desastres muestra inversión preventiva proporcional a su riesgo.

**Distribución por fenómeno (Viz 4):**
- El fenómeno **Hidrometeorológico** domina con 485 declaratorias (≈80% del total), confirmando que las lluvias, inundaciones y ciclones son el principal vector de riesgo en México.
- El fenómeno **Geológico** representa 110 declaratorias (≈18%), incluyendo sismos y deslizamientos.
- **Incendio Forestal** contribuye con 15 declaratorias (≈2%), subestimado posiblemente por criterios de declaratoria que excluyen eventos menores.

**Clasificación de prioridad (Viz 5):**
- **3 estados FOCO ROJO**, **4 de Alta siniestralidad**, **7 de Siniestralidad moderada** y **14 de Riesgo bajo**.
- La concentración del riesgo es marcada: los 7 estados de mayor exposición (cuartil 1 y 2) acumulan más del 70% de las declaratorias nacionales.

---

## :building_construction: 3. Modelo dimensional

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

**Una fila por (entidad federativa × año × tipo de fenómeno).** Este grano permite responder las cinco sub-preguntas analíticas: comparar estados en el mismo período, analizar tendencias temporales, cruzar inversión con ocurrencia y clasificar estados por vulnerabilidad relativa.

---

## :triangular_ruler: 4. Decisiones de diseño

**`dim_programa_prevencion` desacoplada de `fact_riesgo`.** La granularidad de los proyectos preventivos (un proyecto puede abarcar múltiples años y fenómenos) no encaja en el grano estado × año × fenómeno. Forzar esa FK requeriría distribuir arbitrariamente el costo de proyectos multi-fenómeno entre varios registros, introduciendo imprecisión. La inversión se agrega directamente en `inversion_prevencion` de la fact. Esta separación sigue el principio Kimball de no distorsionar la fact para forzar una dimensión que no le corresponde.

**`total_desastres` y `total_emergencias` como columnas separadas.** Una declaratoria de desastre y una de emergencia son instrumentos jurídicos distintos con criterios de activación diferentes. El ratio emergencias/desastres es en sí mismo un indicador: estados con muchas emergencias y pocos desastres (como Oaxaca: 185 vs 70) tienen una mayor capacidad de activar el mecanismo de emergencia pero no alcanzan el umbral de desastre, lo que tiene implicaciones distintas para la política pública.

**Surrogate keys `SERIAL` en minúsculas.** PostgreSQL normaliza identificadores sin comillas dobles a minúsculas. Las surrogate keys (`id_estado`, `id_tiempo`, `id_fenomeno`) aíslan la fact de variaciones ortográficas en los nombres de estados y fenómenos del origen.

**Carga de datos crudos como TEXT → transform en Python.** Los archivos fuente del SSPC mezclan formatos en la misma columna (`"$1,200,000"`, `"1200000"`, `"N/D"`). La estrategia cargar-primero-limpiar-después es práctica estándar cuando la fuente no garantiza calidad de datos.

---

## :file_folder: 5. Estructura del repositorio

```
desastres-naturales-mx/
├── README.md                           ← este archivo
├── scripts/
│   ├── 01_schema_ddl.sql               ← DDL del star schema
│   └── etl_pipeline.py                 ← ETL Python end-to-end
├── analisis/
│   └── queries_analiticas.sql          ← 5 queries SQL avanzado
└── dashboard/
    ├── dashboard.ipynb                 ← Notebook con 5 visualizaciones
    ├── Visualizacion_1.html            ← Ranking de estados
    ├── Visualizacion_2.html            ← Serie temporal
    ├── Visualizacion_3.html            ← Scatter inversión vs desastres
    ├── Visualizacion_4.html            ← Distribución por fenómeno
    └── Visualizacion_5.html            ← Tabla de prioridad
```

---

## :wrench: 6. Cómo ejecutar

### Prerequisitos

```bash
pip install pandas sqlalchemy psycopg2-binary tqdm plotly kaleido
```

### Paso 1 — Crear el star schema

```sql
-- Ejecutar desde DBeaver o psql
\i scripts/01_schema_ddl.sql
```

### Paso 2 — Ejecutar el ETL

```bash
python scripts/etl_pipeline.py \
    --host   TU_AURORA_ENDPOINT.rds.amazonaws.com \
    --port   5432 \
    --db     TU_DATABASE \
    --password TU_PASSWORD
```

### Paso 3 — Crear la vista analítica

```sql
-- Ejecutar Query 5 de analisis/queries_analiticas.sql
-- Esto crea desastres.v_vulnerabilidad_estados
```

### Paso 4 — Dashboard

```bash
jupyter notebook dashboard/dashboard.ipynb
# Editar celda de conexión con credenciales Aurora
# Ejecutar todas las celdas (Run All)
```

---

## :computer: 7. SQL avanzado

Cinco queries en `analisis/queries_analiticas.sql` con las siguientes técnicas:

| Query | Técnica | Descripción |
|---|---|---|
| 1 | CTE + `DENSE_RANK` | Ranking compuesto por 3 métricas simultáneas |
| 2 | CTE + `LAG` | Delta interanual de desastres por estado |
| 3 | `COUNT FILTER` | Conteo condicional de períodos sin inversión |
| 4 | `PERCENTILE_CONT` | Distribución estadística P25/P50/P75/P95 por fenómeno |
| 5 | CTE + `NTILE` + Vista | Clasificación cuartil persistente en Aurora |

### Query representativa — Ranking compuesto (CTE + DENSE_RANK)

```sql
WITH metricas AS (
    SELECT de.entidad_federativa,
           SUM(fr.total_desastres)     AS desastres_totales,
           SUM(fr.total_emergencias)   AS emergencias_totales,
           SUM(fr.poblacion_afectada)  AS poblacion_total
    FROM   desastres.fact_riesgo fr
    JOIN   desastres.dim_estado  de USING (id_estado)
    GROUP  BY de.entidad_federativa
),
ranking AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY desastres_totales   DESC) AS rank_des,
        DENSE_RANK() OVER (ORDER BY emergencias_totales DESC) AS rank_eme,
        DENSE_RANK() OVER (ORDER BY poblacion_total     DESC) AS rank_pob
    FROM metricas
)
SELECT entidad_federativa,
       (rank_des + rank_eme + rank_pob) AS indice_riesgo_compuesto
FROM   ranking
ORDER  BY indice_riesgo_compuesto
LIMIT  10;
```

---

## :bar_chart: 8. Dashboard

Cinco visualizaciones interactivas en Plotly, ejecutadas en `dashboard/dashboard.ipynb`:

| Viz | Tipo | Hallazgo clave |
|---|---|---|
| 1 | Barras horizontales agrupadas | Chiapas (115 des.), Veracruz (95) y Oaxaca (70) lideran el ranking |
| 2 | Líneas temporales | 2020 fue el año pico: 235 desastres y 415 emergencias nacionales |
| 3 | Scatter de burbujas | Veracruz, Tabasco y BCS son FOCO ROJO: alto riesgo, inversión cero |
| 4 | Barras + Pie | Hidrometeorológico representa el 80% de todas las declaratorias |
| 5 | Tabla con formato condicional | 3 estados FOCO ROJO, 4 de alta siniestralidad identificados |

---

## :mag: 9. Hallazgos y conclusiones

### Hallazgos confirmados por los datos

1. **Chiapas, Veracruz y Oaxaca** son los estados de mayor siniestralidad acumulada del período 2013–2024, con Chiapas como líder absoluto en declaratorias de desastre (115) y Oaxaca en emergencias (185).

2. **El año 2020 concentra la mayor crisis**: 235 declaratorias de desastre y 415 de emergencia a nivel nacional. La convergencia de fenómenos hidrometeorológicos extremos con la pandemia de COVID-19 sobrepasó los mecanismos institucionales de atención simultánea.

3. **El fenómeno Hidrometeorológico domina con el 80%** del total de declaratorias (485 de ~610). Los eventos geológicos representan el 18% restante pero tienen impactos puntuales de mayor magnitud.

4. **La paradoja de inversión se confirma**: los 3 estados FOCO ROJO (Veracruz, Tabasco, Baja California Sur) tienen inversión preventiva registrada de cero pesos pese a concentrar décadas de siniestralidad. Esto evidencia que los recursos federales fluyen hacia reconstrucción pero no hacia prevención en los estados más vulnerables.

5. **La concentración del riesgo es estructural**: 7 de los 28 estados con registros (25%) acumulan más del 70% de todas las declaratorias nacionales. Una política de prevención que priorice estos 7 estados tendría el mayor impacto marginal por peso invertido.

### Respuesta a la pregunta analítica

Los estados que deben ser **prioritarios para programas de prevención federal** son, en orden de urgencia:

| Prioridad | Estado | Clasificación | Razón |
|---|---|---|---|
| 🔴 1 | Veracruz | FOCO ROJO | 95 desastres, 100 emergencias, inversión = 0 |
| 🔴 2 | Tabasco | FOCO ROJO | 25 desastres, 40 emergencias, inversión = 0 |
| 🔴 3 | Baja California Sur | FOCO ROJO | 40 desastres, 40 emergencias, inversión = 0 |
| 🟠 4 | Chiapas | Alta siniestralidad | 115 desastres — el estado más afectado del período |
| 🟠 5 | Oaxaca | Alta siniestralidad | 185 emergencias — mayor volumen de emergencias del país |

---

## :books: Referencias

- [SSPC — Declaratorias de Desastre y Emergencia (datos.gob.mx)](https://datos.gob.mx/busca/dataset/declaratorias-de-desastre-y-emergencia)
- [CENAPRED — Atlas Nacional de Riesgos](http://www.atlasnacionalderiesgos.gob.mx/)
- [World Risk Index 2023 — Bündnis Entwicklung Hilft](https://weltrisikobericht.de/world-risk-report-2023/)
- [FONDEN — Reglas de Operación del Fondo de Desastres Naturales, DOF 2014](https://www.dof.gob.mx/nota_detalle.php?codigo=5374167&fecha=03/12/2014)
- Material del módulo: Tema 02 (Modelo Dimensional), Tema 04 (ETL Python), Tema 05 (SQL Avanzado)

---

<p align="center">
<em>Proyecto Final — Data Analytics · Amazon Aurora PostgreSQL · Plotly · Jupyter</em>
</p>
