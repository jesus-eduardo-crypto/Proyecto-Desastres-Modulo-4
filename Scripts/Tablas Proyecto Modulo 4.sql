--CREATE SCHEMA IF NOT EXISTS desastres;
--DROP TABLE desastres.stg_proyectos_prevencion;
--DROP TABLE desastres.stg_declaratorias_emergencia;



SELECT COUNT(*) 
FROM desastres.stg_declaratorias_desastre;

SELECT COUNT(*) 
FROM desastres.stg_declaratorias_emergencia;

SELECT COUNT(*) 
FROM desastres.stg_proyectos_prevencion;

--===================================================================================================

SELECT *
FROM desastres.stg_declaratorias_emergencia
LIMIT 3;

SELECT *
FROM desastres.stg_proyectos_prevencion
LIMIT 3;

SELECT *
FROM desastres.stg_declaratorias_desastre
LIMIT 3;


SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'desastres'
AND table_name = 'stg_declaratorias_emergencia';

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'desastres'
AND table_name = 'stg_proyectos_prevencion';

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'desastres'
AND table_name = 'stg_declaratorias_desastre';


--============================================================================================================

CREATE TABLE desastres.dim_estado (
    Id_estado SERIAL PRIMARY KEY,
    entidad_federativa VARCHAR(100) UNIQUE
);

CREATE TABLE desastres.dim_fenomeno (
    Id_fenomeno SERIAL PRIMARY KEY,
    tipo_fenomeno VARCHAR(200)
);

CREATE TABLE desastres.dim_tiempo (
    Id_tiempo SERIAL PRIMARY KEY,
    anio INTEGER UNIQUE
);

CREATE TABLE desastres.dim_programa_prevencion (
    Id_programa SERIAL PRIMARY KEY,
    nombre_proyecto TEXT,
    tipo_proyecto TEXT,
    estatus TEXT
);


--Tabla de hechos
CREATE TABLE desastres.fact_riesgo (
    Id_riesgo SERIAL PRIMARY KEY,

    Id_estado INTEGER REFERENCES desastres.dim_estado,
    Id_tiempo INTEGER REFERENCES desastres.dim_tiempo,
    Id_fenomeno INTEGER REFERENCES desastres.dim_fenomeno,

    total_desastres INTEGER,
    total_emergencias INTEGER,

    municipios_afectados INTEGER,
    poblacion_afectada NUMERIC,

    inversion_prevencion NUMERIC
);




--Indices
-- FACT TABLE

CREATE INDEX idx_fact_riesgo_tiempo
ON desastres.fact_riesgo(Id_tiempo);

CREATE INDEX idx_fact_riesgo_estado
ON desastres.fact_riesgo(Id_estado);

CREATE INDEX idx_fact_riesgo_fenomeno
ON desastres.fact_riesgo(Id_fenomeno);

CREATE INDEX idx_fact_riesgo_estado_tiempo
ON desastres.fact_riesgo(Id_estado, Id_tiempo);

CREATE INDEX idx_fact_riesgo_fenomeno_tiempo
ON desastres.fact_riesgo(Id_fenomeno, Id_tiempo);

CREATE INDEX idx_fact_riesgo_estado_fenomeno
ON desastres.fact_riesgo(Id_estado, Id_fenomeno);

CREATE INDEX idx_fact_riesgo_dashboard
ON desastres.fact_riesgo(
    Id_tiempo,
    Id_estado,
    Id_fenomeno
);



