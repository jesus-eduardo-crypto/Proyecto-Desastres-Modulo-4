# Riesgo de Desastres Naturales en México — Data Warehouse

## :clipboard: Resumen ejecutivo

| Campo | Valor |
|---|---|
| **Pregunta analítica** | ¿Qué entidades federativas presentan mayor exposición al riesgo de desastres naturales y deberían ser prioritarias para programas de prevención? |
| **Dataset** | Declaratorias de desastre, declaratorias de emergencia y proyectos de prevención — SSPC/CENAPRED, cobertura histórica nacional (~32 estados, múltiples años) |
| **Fuente** | [Datos Abiertos del Gobierno de México — SSPC](https://datos.gob.mx/busca/dataset/declaratorias-de-desastre-y-emergencia) |
| **Modelo** | Estrella con 1 fact + 4 dimensiones (estado, tiempo, fenómeno, programa de prevención) |
| **Infraestructura** | Amazon Aurora PostgreSQL — schema `desastres`, administrado desde DBeaver |
| **ETL** | `etl_pipeline.py` end-to-end con pandas + SQLAlchemy + validaciones post-carga |
| **SQL avanzado** | CTEs anidados, window functions (DENSE_RANK, LAG, NTILE), COUNT FILTER, PERCENTILE_CONT |
| **Dashboard** | Power BI: mapa choropleth, ranking de estados, serie temporal, scatter inversión vs desastres, KPI de población afectada |

---

## :dart: Problema y motivación

México es uno de los países con mayor exposición a fenómenos naturales en el mundo. Su posición geográfica lo expone simultáneamente a sismos, huracanes, inundaciones, sequías e incendios forestales. Sin embargo, los recursos federales para prevención y atención de emergencias son finitos, lo que obliga a las autoridades a priorizar.

El problema concreto que resuelve este proyecto es la **ausencia de una visión integrada** que cruce tres fuentes de información complementarias:
- El **historial de declaratorias de desastre** (¿dónde y cuándo ocurrieron eventos graves?).
- Las **declaratorias de emergencia** con datos de población afectada y costos (¿cuál fue el impacto humano y económico?).
- Los **proyectos de prevención financiados** (¿cuánto se ha invertido por estado y tipo de fenómeno?).

Sin esa visión integrada, es imposible responder preguntas como: *¿Los estados con más desastres reciben más inversión preventiva?* o *¿Hay estados con alta siniestralidad y baja inversión que debería atenderse urgentemente?*

Este proyecto responde cuatro preguntas analíticas concretas:

1. **¿Qué estados concentran el mayor número de declaratorias de desastre y emergencia históricamente?**
2. **¿Qué fenómenos naturales son los más frecuentes y cuál es su distribución geográfica?**
3. **¿Existe correlación entre la inversión preventiva y la reducción de desastres declarados?**
4. **¿Qué estados tienen alta siniestralidad y baja inversión preventiva (focos rojos de política pública)?**

---

## :package: Origen de los datos

Las tres fuentes de datos son registros administrativos publicados por la **Secretaría de Seguridad y Protección Ciudadana (SSPC)** y el **Centro Nacional de Prevención de Desastres (CENAPRED)**:

| Tabla staging | Descripción | Registros aprox. |
|---|---|---|
| `stg_declaratorias_desastre` | Declaratorias de desastre naturales con municipios corroborados | ~4 000 |
| `stg_declaratorias_emergencia` | Emergencias con población afectada, apoyos y costos | ~6 000 |
| `stg_proyectos_prevencion` | Proyectos preventivos federales con montos autorizados | ~2 000 |

Las tablas staging ya fueron cargadas en Aurora PostgreSQL con todas las columnas como `TEXT` para evitar errores de tipo durante la ingesta. El ETL es responsable de hacer el cast y la limpieza.

### Flujo end-to-end

```
        ┌──────────────────────────────────────────────┐
        │  Fuente: SSPC / CENAPRED                     │
        │  (datos.gob.mx — archivos CSV/XLSX)          │
        │                                              │
        │  • stg_declaratorias_desastre                │
        │  • stg_declaratorias_emergencia              │
        │  • stg_proyectos_prevencion                  │
        │                                              │
        │  Cargadas como TEXT en Aurora (staging)      │
        └──────────────────┬───────────────────────────┘
                           │  SELECT * FROM stg_*
                           ▼
        ┌──────────────────────────────────────────────┐
        │  ETL Python — etl_pipeline.py                │
        │                                              │
        │  Extract:   pd.read_sql desde staging        │
        │  Transform: limpieza de nulos, cast de       │
        │             tipos, normalización de estados, │
        │             deduplicación, agregación por    │
        │             (estado × año × fenómeno)        │
        │  Load:      dims primero, luego fact         │
        │             con surrogate keys resueltos     │
        └──────────────────┬───────────────────────────┘
                           │  INSERT / upsert
                           ▼
        ┌──────────────────────────────────────────────┐
        │  Amazon Aurora PostgreSQL                    │
        │  Schema: desastres                           │
        │                                              │
        │  • dim_estado                                │
        │  • dim_tiempo                                │
        │  • dim_fenomeno                              │
        │  • dim_programa_prevencion                   │
        │  • fact_riesgo                               │
        └──────────────────┬───────────────────────────┘
                           │  SELECT
                           ▼
        ┌──────────────────────────────────────────────┐
        │  Power BI Desktop                            │
        │  (DirectQuery o Import mode)                 │
        │  5 visualizaciones que responden             │
        │  la pregunta analítica principal             │
        └──────────────────────────────────────────────┘
```

### Por qué los datos están en staging como TEXT

Los archivos originales del SSPC mezclan formatos inconsistentes dentro de la misma columna: montos como `"$1,200,000.00"`, `"1200000"` y `"N/D"` coexisten en la misma columna `costo_total_declaratoria`. Intentar declarar `NUMERIC` al momento de la carga masiva provocaría errores en cualquier valor mal formateado. La estrategia **cargar-primero-limpiar-después** (ELT parcial) es la práctica estándar en Data Engineering cuando la fuente no garantiza calidad de datos.

---

## :file_folder: Estructura del repositorio

```
desastres-naturales-mx/
├── README.md                           ← este archivo
├── scripts/
│   ├── 01_schema_ddl.sql               ← creación de dims y fact (star schema)
│   └── etl_pipeline.py                 ← ETL Python end-to-end
├── analisis/
│   └── queries_analiticas.sql          ← 5 queries con SQL avanzado
└── dashboard/
    └── desastres_dashboard.pbix        ← Power BI (ver sección Dashboard)
```

---

## :wrench: Cómo ejecutar

### 1. Prerequisito: staging tables pobladas

Las tres tablas `stg_*` deben estar cargadas en Aurora antes de correr el ETL. Si están vacías, cárgalas desde los CSVs originales del SSPC usando DBeaver o el Import Wizard de Aurora.

### 2. Crear el star schema (si no existe)

Desde DBeaver o psql:

```sql
-- Ejecutar el DDL completo del star schema
\i scripts/01_schema_ddl.sql
```

### 3. Instalar dependencias Python

```bash
pip install pandas sqlalchemy psycopg2-binary tqdm
```

### 4. Ejecutar el ETL

```bash
python scripts/etl_pipeline.py \
    --host   TU_AURORA_ENDPOINT.rds.amazonaws.com \
    --port   5432 \
    --db     TU_DATABASE \
    --password TU_PASSWORD
```

El script reporta progreso en cada etapa (extract, transform, load de cada tabla) y al final ejecuta validaciones post-carga con `COUNT(*)` y chequeos de integridad referencial.

### 5. Conectar Power BI

1. Abrir `dashboard/desastres_dashboard.pbix`
2. En **Transformar datos → Configuración de origen de datos**, actualizar host y credenciales Aurora.
3. Hacer clic en **Actualizar** para recargar todas las visualizaciones.

---

## :building_construction: Modelo dimensional

### Esquema estrella

```
                          ┌───────────────────────┐
                          │      dim_tiempo        │
                          │                        │
                          │  Id_tiempo   PK        │
                          │  anio        INTEGER   │
                          └───────────┬────────────┘
                                      │
                                      │
┌──────────────────┐        ┌─────────┴──────────────────────┐        ┌─────────────────────┐
│   dim_estado     │        │         fact_riesgo             │        │    dim_fenomeno      │
│                  │        │                                 │        │                     │
│ Id_estado   PK   │◄───────│ Id_riesgo            PK        │───────►│ Id_fenomeno   PK    │
│ entidad_feder.   │        │ Id_estado            FK        │        │ tipo_fenomeno       │
└──────────────────┘        │ Id_tiempo            FK        │        └─────────────────────┘
                            │ Id_fenomeno          FK        │
                            │                                │
                            │ total_desastres     INTEGER    │
                            │ total_emergencias   INTEGER    │
                            │ municipios_afect.   INTEGER    │
                            │ poblacion_afectada  NUMERIC    │
                            │ inversion_prev.     NUMERIC    │
                            └─────────────────────────────────┘

        ┌────────────────────────────────┐
        │     dim_programa_prevencion    │
        │                               │
        │  Id_programa      PK          │
        │  nombre_proyecto  TEXT        │
        │  tipo_proyecto    TEXT        │
        │  estatus          TEXT        │
        └────────────────────────────────┘
        (dimensión complementaria, no FK en fact_riesgo;
         se relaciona analíticamente por estado + año)
```

### Grano de la fact

**Una fila por (entidad federativa × año × tipo de fenómeno).** Este grano permite responder todas las preguntas del negocio:
- Comparar estados entre sí en el mismo año y por el mismo tipo de fenómeno.
- Analizar tendencias temporales por estado y fenómeno.
- Cruzar inversión preventiva (agregada por estado × año × fenómeno) con el número de eventos ocurridos.

---

## :triangular_ruler: Decisiones de diseño

**`dim_programa_prevencion` sin FK en `fact_riesgo`.**
La granularidad de los proyectos preventivos (un proyecto puede abarcar múltiples años y fenómenos simultáneamente) no encaja directamente en el grano `estado × año × fenómeno` de la fact. Forzar esa relación requeriría distribuir proporcional o arbitrariamente el costo de un proyecto multi-fenómeno entre varios registros de la fact, lo cual introduciría imprecisión. La decisión fue: (a) cargar la inversión preventiva **agregada por (estado × año × fenómeno)** directamente en la columna `inversion_prevencion` de `fact_riesgo`, y (b) conservar `dim_programa_prevencion` como dimensión independiente para análisis de portafolio de proyectos. Esta separación sigue el principio Kimball de *no distorsionar la fact para forzar una dimensión que no le corresponde*.

**`dim_fenomeno` sin atributos de jerarquía.**
El catálogo del SSPC no distingue sistemáticamente entre tipo de fenómeno (e.g., "Hidrometeorológico") y amenaza específica (e.g., "Huracán", "Tormenta tropical"). En lugar de inventar una jerarquía que el origen no soporta, la dimensión queda plana con `tipo_fenomeno`. Si en futuras iteraciones el catálogo se estandariza, se puede agregar una columna `categoria_fenomeno` sin alterar la fact.

**Columnas `total_desastres` y `total_emergencias` separadas.**
Aunque ambas fuentes describen eventos adversos, una declaratoria de desastre y una declaratoria de emergencia son instrumentos jurídicos distintos con criterios de activación diferentes. Agregarlas en un solo campo eliminaría esa distinción. Mantenerlas separadas permite analizar el *ratio* emergencias/desastres como indicador de la capacidad de respuesta inmediata de cada estado.

**Surrogate keys (`SERIAL`) en lugar de claves naturales.**
Los nombres de estados y fenómenos en los datos originales tienen variaciones ortográficas (tildes, mayúsculas, abreviaciones). Las surrogate keys aíslan la fact de esas inconsistencias: si mañana el ETL normaliza "VERACRUZ" y "Veracruz" al mismo registro de `dim_estado`, las FK en la fact no cambian.

**Carga de datos crudos como TEXT → transform en Python, no en SQL.**
PostgreSQL es excelente para análisis pero no para transformaciones imperativas complejas (regex sobre múltiples columnas, lógica de deduplicación condicional). El equipo de Data Engineering puede versionar, testear y depurar Python mucho más rápido que stored procedures equivalentes.

---

## :computer: SQL avanzado

Cinco queries en [`analisis/queries_analiticas.sql`](analisis/queries_analiticas.sql) que responden directamente las preguntas del negocio con técnicas avanzadas:

### 1. Ranking compuesto de riesgo por estado (CTE + DENSE_RANK)

Combina desastres, emergencias y población afectada en un índice único para identificar los estados más expuestos.

```sql
WITH metricas AS (
    SELECT
        de.entidad_federativa,
        SUM(fr.total_desastres)       AS desastres_totales,
        SUM(fr.total_emergencias)     AS emergencias_totales,
        SUM(fr.poblacion_afectada)    AS poblacion_total_afectada
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (Id_estado)
    GROUP BY  de.entidad_federativa
),
ranking AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY desastres_totales    DESC) AS rank_desastres,
        DENSE_RANK() OVER (ORDER BY emergencias_totales  DESC) AS rank_emergencias,
        DENSE_RANK() OVER (ORDER BY poblacion_total_afectada DESC) AS rank_poblacion
    FROM metricas
)
SELECT
    entidad_federativa,
    desastres_totales,
    emergencias_totales,
    poblacion_total_afectada,
    (rank_desastres + rank_emergencias + rank_poblacion) AS indice_riesgo_compuesto
FROM ranking
ORDER BY indice_riesgo_compuesto
LIMIT 10;
```

### 2. Tendencia interanual con variación (CTE + LAG)

Calcula el delta año a año de desastres por estado para identificar si la situación empeora o mejora.

```sql
WITH anual AS (
    SELECT
        de.entidad_federativa,
        dt.anio,
        SUM(fr.total_desastres) AS desastres_anio
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (Id_estado)
    JOIN      desastres.dim_tiempo  dt USING (Id_tiempo)
    GROUP BY  de.entidad_federativa, dt.anio
)
SELECT
    entidad_federativa,
    anio,
    desastres_anio,
    LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) AS anio_anterior,
    desastres_anio
        - LAG(desastres_anio) OVER (PARTITION BY entidad_federativa ORDER BY anio) AS delta
FROM anual
ORDER BY delta DESC NULLS LAST
LIMIT 15;
```

### 3. Inversión preventiva vs impacto observado (agregación con FILTER)

```sql
SELECT
    de.entidad_federativa,
    SUM(fr.total_desastres)                                         AS desastres,
    SUM(fr.inversion_prevencion)                                    AS inversion_total,
    COUNT(*) FILTER (WHERE fr.inversion_prevencion = 0)             AS anios_sin_inversion,
    ROUND(SUM(fr.inversion_prevencion) /
          NULLIF(SUM(fr.total_desastres), 0), 0)                    AS inversion_por_desastre
FROM      desastres.fact_riesgo fr
JOIN      desastres.dim_estado  de USING (Id_estado)
GROUP BY  de.entidad_federativa
ORDER BY  inversion_por_desastre ASC NULLS LAST;
```

### 4. Fenómenos más frecuentes con percentil de población afectada

```sql
SELECT
    df.tipo_fenomeno,
    COUNT(*)                                                                     AS registros,
    SUM(fr.total_desastres)                                                      AS total_desastres,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fr.poblacion_afectada)          AS mediana_pob,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY fr.poblacion_afectada)          AS p95_pob
FROM      desastres.fact_riesgo fr
JOIN      desastres.dim_fenomeno df USING (Id_fenomeno)
GROUP BY  df.tipo_fenomeno
HAVING    SUM(fr.total_desastres) > 5
ORDER BY  total_desastres DESC;
```

### 5. Clasificación cuartil de vulnerabilidad y vista analítica

Segmenta los estados en cuartiles de vulnerabilidad para identificar prioridades de política pública.

```sql
CREATE OR REPLACE VIEW desastres.v_vulnerabilidad_estados AS
WITH base AS (
    SELECT
        de.entidad_federativa,
        SUM(fr.total_desastres)     AS desastres,
        SUM(fr.total_emergencias)   AS emergencias,
        SUM(fr.poblacion_afectada)  AS poblacion_afectada,
        SUM(fr.inversion_prevencion) AS inversion
    FROM      desastres.fact_riesgo fr
    JOIN      desastres.dim_estado  de USING (Id_estado)
    GROUP BY  de.entidad_federativa
)
SELECT
    entidad_federativa,
    desastres,
    emergencias,
    poblacion_afectada,
    inversion,
    NTILE(4) OVER (ORDER BY (desastres + emergencias) DESC)          AS cuartil_siniestralidad,
    NTILE(4) OVER (ORDER BY inversion ASC)                           AS cuartil_baja_inversion,
    CASE
        WHEN NTILE(4) OVER (ORDER BY (desastres + emergencias) DESC) = 1
         AND NTILE(4) OVER (ORDER BY inversion ASC) = 1
        THEN 'FOCO ROJO — Alta siniestralidad y baja inversión'
        WHEN NTILE(4) OVER (ORDER BY (desastres + emergencias) DESC) = 1
        THEN 'Alta siniestralidad — inversión media/alta'
        ELSE 'Riesgo moderado'
    END AS clasificacion_prioridad
FROM base;

SELECT * FROM desastres.v_vulnerabilidad_estados
ORDER BY cuartil_siniestralidad, cuartil_baja_inversion;
```

---

## :bar_chart: Dashboard en Power BI

### Tablas a importar

Conectar Power BI a Aurora PostgreSQL e importar (modo Import para mejor rendimiento):

| Tabla | Uso |
|---|---|
| `desastres.fact_riesgo` | Tabla central de métricas |
| `desastres.dim_estado` | Etiquetas de estados, necesario para el mapa |
| `desastres.dim_tiempo` | Eje temporal de la serie |
| `desastres.dim_fenomeno` | Filtro por tipo de fenómeno |
| `desastres.v_vulnerabilidad_estados` | Vista precalculada para el KPI y el mapa choropleth |

### Relaciones en el modelo Power BI

```
dim_estado[Id_estado]         → fact_riesgo[Id_estado]         (1:N)
dim_tiempo[Id_tiempo]         → fact_riesgo[Id_tiempo]          (1:N)
dim_fenomeno[Id_fenomeno]     → fact_riesgo[Id_fenomeno]        (1:N)
```

### Medidas DAX recomendadas

```dax
Total Desastres        = SUM(fact_riesgo[total_desastres])
Total Emergencias      = SUM(fact_riesgo[total_emergencias])
Población Afectada     = SUM(fact_riesgo[poblacion_afectada])
Inversión Preventiva   = SUM(fact_riesgo[inversion_prevencion])
Índice Riesgo          = [Total Desastres] + [Total Emergencias]

Inversión por Desastre =
    DIVIDE([Inversión Preventiva], [Total Desastres], 0)

% Población Afectada vs Nacional =
    DIVIDE(
        SUM(fact_riesgo[poblacion_afectada]),
        CALCULATE(SUM(fact_riesgo[poblacion_afectada]), ALL(dim_estado))
    )
```

### Visualizaciones propuestas

**1. Mapa choropleth — Índice de riesgo por entidad federativa**
- Tipo: *Mapa de formas* (Shape Map) con el mapa de México por estado.
- Campo de ubicación: `dim_estado[entidad_federativa]`.
- Saturación de color: medida `[Índice Riesgo]`.
- Tooltip: `[Total Desastres]`, `[Población Afectada]`, `[Inversión Preventiva]`.
- Filtro de página: `dim_tiempo[anio]` (segmentación por año o rango).

**2. Ranking de estados por desastres (barras horizontales)**
- Tipo: *Gráfico de barras agrupadas*.
- Eje Y: `dim_estado[entidad_federativa]` ordenado descendente por `[Total Desastres]`.
- Valores: `[Total Desastres]` y `[Total Emergencias]` en barras apiladas.
- Filtro: Top N = 15 estados por `[Índice Riesgo]`.

**3. Serie temporal de eventos por año**
- Tipo: *Gráfico de líneas*.
- Eje X: `dim_tiempo[anio]`.
- Valores: `[Total Desastres]` (línea azul), `[Total Emergencias]` (línea naranja).
- Segmentación: `dim_fenomeno[tipo_fenomeno]` para filtrar por tipo de fenómeno.

**4. Scatter — Inversión preventiva vs cantidad de desastres**
- Tipo: *Gráfico de dispersión*.
- Eje X: `[Inversión Preventiva]` (escala logarítmica recomendada).
- Eje Y: `[Total Desastres]`.
- Tamaño de burbuja: `[Población Afectada]`.
- Etiqueta de datos: `dim_estado[entidad_federativa]`.
- Interpretación: estados en el cuadrante *alta siniestralidad + baja inversión* son los focos rojos.

**5. KPI — Población afectada total y clasificación de prioridad**
- Tipo: *Tarjeta* para el total nacional.
- Tipo: *Tabla* con columnas `entidad_federativa`, `clasificacion_prioridad`, `desastres`, `inversion` desde `v_vulnerabilidad_estados`.
- Formato condicional en `clasificacion_prioridad`: rojo para "FOCO ROJO", amarillo para "Alta siniestralidad".

---

## :mag: Hallazgos esperados

Con base en el contexto histórico de desastres naturales en México, las queries deberían revelar:

1. **Guerrero, Oaxaca, Veracruz y Tabasco** concentran históricamente el mayor número de declaratorias. Su exposición a huracanes del Pacífico y del Golfo, combinada con sismos en el caso de Guerrero y Oaxaca, los convierte en los estados de mayor siniestralidad acumulada.

2. **Los fenómenos hidrometeorológicos** (lluvias, inundaciones, ciclones) representan la mayoría de las declaratorias — se estima que más del 70 % del total histórico corresponde a este tipo. Los fenómenos geológicos (sismos, deslizamientos) son menos frecuentes pero de mayor impacto puntual.

3. **La relación inversión preventiva vs ocurrencia** puede mostrar una paradoja aparente: los estados con más desastres tienden a recibir más recursos de reconstrucción pero no necesariamente más recursos de prevención. Si las queries confirman esta hipótesis, el hallazgo sería el argumento central de política pública del proyecto.

4. **Tabasco** es candidato a presentar la mayor población afectada acumulada debido a las inundaciones sistemáticas de la cuenca del río Grijalva, que en eventos como los de 2007 y 2020 llegaron a afectar a más de un millón de personas en un solo evento.

5. **La tendencia temporal (LAG)** probablemente mostrará incrementos en la frecuencia de desastres a partir de 2010, consistente con la literatura sobre intensificación de eventos extremos asociada al cambio climático.

---

## :books: Referencias

- [Datos Abiertos SSPC — Declaratorias de Desastre y Emergencia](https://datos.gob.mx/busca/dataset/declaratorias-de-desastre-y-emergencia)
- [CENAPRED — Atlas Nacional de Riesgos](http://www.atlasnacionalderiesgos.gob.mx/)
- [FONDEN — Reglas de Operación del Fondo de Desastres Naturales](https://www.dof.gob.mx/nota_detalle.php?codigo=5374167&fecha=03/12/2014)
- [OCDE (2013) — Estudio de la gestión de riesgos en México](https://doi.org/10.1787/9789264200661-es)
- Material del módulo: Tema 02 (Modelo Dimensional), Tema 04 (ETL Python), Tema 05 (SQL Avanzado)

---

<p align="center">
<em>Proyecto Final — Data Analytics · Amazon Aurora PostgreSQL · Power BI</em>
</p>
