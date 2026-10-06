-- =====================================================================
-- Sistema de detección y notificación de objetos personales abandonados
-- Trabajo de Grado I - Corte 2 (Diseño) - Esquema de la base de datos
-- Motor: SQLite 3 (>= 3.35). Ejecutar con foreign_keys activado.
-- Trazabilidad: HU-xx / RNF-xx según el documento del corte 1.
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- Seguridad: perfiles de acceso (RNF-05, RNF-04)
-- SQLite no tiene usuarios/roles nativos; los perfiles se modelan aquí
-- y los aplica la capa de servicios. El archivo .db se protege con
-- permisos del sistema operativo (ver registro de decisiones).
-- ---------------------------------------------------------------------
CREATE TABLE rol (
    id          INTEGER PRIMARY KEY,
    nombre      TEXT NOT NULL UNIQUE
                CHECK (nombre IN ('administrador','seguridad','servicio_deteccion')),
    descripcion TEXT NOT NULL
);

CREATE TABLE permiso (
    rol_id  INTEGER NOT NULL REFERENCES rol(id) ON DELETE CASCADE,
    recurso TEXT NOT NULL
            CHECK (recurso IN ('usuario','zona','camara','configuracion','evento',
                               'notificacion','auditoria','evaluacion_modelo','dataset_imagen')),
    accion  TEXT NOT NULL CHECK (accion IN ('leer','crear','actualizar','eliminar')),
    PRIMARY KEY (rol_id, recurso, accion)
);

CREATE TABLE usuario (
    id                INTEGER PRIMARY KEY,
    nombre            TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    correo            TEXT NOT NULL UNIQUE CHECK (correo LIKE '%_@_%._%'),
    hash_contrasena   TEXT NOT NULL CHECK (hash_contrasena LIKE 'pbkdf2_sha256$%'),
    rol_id            INTEGER NOT NULL REFERENCES rol(id),
    activo            INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1)),
    intentos_fallidos INTEGER NOT NULL DEFAULT 0 CHECK (intentos_fallidos >= 0),
    creado_en         TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Infraestructura de captura (HU-04, RNF-07)
-- ---------------------------------------------------------------------
CREATE TABLE zona (
    id          INTEGER PRIMARY KEY,
    nombre      TEXT NOT NULL UNIQUE CHECK (length(trim(nombre)) > 0),
    descripcion TEXT,
    activa      INTEGER NOT NULL DEFAULT 1 CHECK (activa IN (0,1))
);

CREATE TABLE camara (
    id              INTEGER PRIMARY KEY,
    zona_id         INTEGER NOT NULL REFERENCES zona(id),
    nombre          TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    -- Nombre de la variable de entorno que guarda la URL RTSP con credenciales.
    -- Las credenciales NUNCA se almacenan en la base de datos.
    referencia_rtsp TEXT NOT NULL CHECK (referencia_rtsp NOT LIKE 'rtsp://%'),
    resolucion      TEXT NOT NULL DEFAULT '1920x1080',
    activa          INTEGER NOT NULL DEFAULT 1 CHECK (activa IN (0,1)),
    UNIQUE (zona_id, nombre)
);

CREATE TABLE configuracion (
    id                      INTEGER PRIMARY KEY,
    zona_id                 INTEGER NOT NULL UNIQUE REFERENCES zona(id),
    tiempo_abandono_s       INTEGER NOT NULL DEFAULT 60
                            CHECK (tiempo_abandono_s BETWEEN 5 AND 3600),
    confianza_minima        REAL NOT NULL DEFAULT 0.50
                            CHECK (confianza_minima > 0 AND confianza_minima <= 1),
    distancia_persona_px    INTEGER NOT NULL DEFAULT 150 CHECK (distancia_persona_px > 0),
    -- RNF-04: las imágenes de alerta se conservan 8 días como máximo
    retencion_imagenes_dias INTEGER NOT NULL DEFAULT 8
                            CHECK (retencion_imagenes_dias BETWEEN 1 AND 8),
    actualizado_por         INTEGER REFERENCES usuario(id),
    actualizado_en          TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Detección, eventos y alertas (HU-01, HU-02, HU-03, HU-05, HU-06)
-- ---------------------------------------------------------------------
CREATE TABLE clase_objeto (
    id             INTEGER PRIMARY KEY,
    nombre         TEXT NOT NULL UNIQUE CHECK (nombre IN ('maletin','portatil')),
    nombre_mostrar TEXT NOT NULL
);

CREATE TABLE evento (
    id               INTEGER PRIMARY KEY,
    camara_id        INTEGER NOT NULL REFERENCES camara(id),
    clase_id         INTEGER NOT NULL REFERENCES clase_objeto(id),
    track_id         INTEGER NOT NULL CHECK (track_id >= 0),
    confianza        REAL NOT NULL CHECK (confianza > 0 AND confianza <= 1),
    detectado_en     TEXT NOT NULL,   -- instante en que el objeto queda estático
    confirmado_en    TEXT NOT NULL,   -- instante en que se cumple el umbral de abandono
    ruta_imagen      TEXT,            -- NULL cuando la imagen fue purgada (RNF-04)
    imagen_expira_en TEXT,
    estado           TEXT NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente','atendida','falso_positivo')),
    atendido_por     INTEGER REFERENCES usuario(id),
    atendido_en      TEXT,
    CHECK (confirmado_en >= detectado_en),
    CHECK (atendido_en IS NULL OR atendido_en >= confirmado_en),
    CHECK ((estado = 'pendiente' AND atendido_por IS NULL AND atendido_en IS NULL)
        OR (estado <> 'pendiente' AND atendido_por IS NOT NULL AND atendido_en IS NOT NULL)),
    -- HU-02: una sola alerta por objeto
    UNIQUE (camara_id, track_id, detectado_en)
);

CREATE TABLE notificacion (
    id         INTEGER PRIMARY KEY,
    evento_id  INTEGER NOT NULL REFERENCES evento(id) ON DELETE CASCADE,
    canal      TEXT NOT NULL CHECK (canal IN ('panel','telegram','correo')),
    enviada_en TEXT NOT NULL,
    exitosa    INTEGER NOT NULL CHECK (exitosa IN (0,1)),
    detalle    TEXT
);

-- ---------------------------------------------------------------------
-- Auditoría inmutable (RNF-05)
-- ---------------------------------------------------------------------
CREATE TABLE auditoria (
    id         INTEGER PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuario(id),
    accion     TEXT NOT NULL
               CHECK (accion IN ('crear','actualizar','eliminar','login_ok','login_fallido')),
    entidad    TEXT NOT NULL,
    entidad_id INTEGER,
    detalle    TEXT,
    fecha      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Dataset y evaluación (HU-07, RNF-03, S-03)
-- ---------------------------------------------------------------------
CREATE TABLE dataset_imagen (
    id                    INTEGER PRIMARY KEY,
    ruta                  TEXT NOT NULL UNIQUE,
    particion             TEXT NOT NULL CHECK (particion IN ('entrenamiento','validacion','prueba')),
    condicion             TEXT NOT NULL DEFAULT 'normal'
                          CHECK (condicion IN ('normal','sombra','oclusion','contraluz')),
    contiene_maletin      INTEGER NOT NULL DEFAULT 0 CHECK (contiene_maletin IN (0,1)),
    contiene_portatil     INTEGER NOT NULL DEFAULT 0 CHECK (contiene_portatil IN (0,1)),
    consentimiento_ref    TEXT NOT NULL CHECK (length(trim(consentimiento_ref)) > 0),
    -- S-03 / RNF-04: no se admiten rostros identificables en el dataset
    rostro_identificable  INTEGER NOT NULL DEFAULT 0 CHECK (rostro_identificable = 0),
    capturada_en          TEXT NOT NULL,
    CHECK (contiene_maletin = 1 OR contiene_portatil = 1)
);

CREATE TABLE evaluacion_modelo (
    id              INTEGER PRIMARY KEY,
    modelo_version  TEXT NOT NULL CHECK (length(trim(modelo_version)) > 0),
    conjunto        TEXT NOT NULL CHECK (conjunto IN ('validacion','prueba')),
    map50           REAL NOT NULL CHECK (map50 BETWEEN 0 AND 1),
    recall          REAL NOT NULL CHECK (recall BETWEEN 0 AND 1),
    f1              REAL NOT NULL CHECK (f1 BETWEEN 0 AND 1),
    fps             REAL NOT NULL CHECK (fps > 0),
    latencia_media_s REAL CHECK (latencia_media_s IS NULL OR latencia_media_s >= 0),
    evaluado_en     TEXT NOT NULL DEFAULT (datetime('now')),
    observaciones   TEXT
);

-- ---------------------------------------------------------------------
-- Índices (consultas frecuentes: historial, filtros por estado, auditoría)
-- ---------------------------------------------------------------------
CREATE INDEX idx_evento_confirmado   ON evento (confirmado_en DESC);
CREATE INDEX idx_evento_estado       ON evento (estado, confirmado_en DESC);
CREATE INDEX idx_evento_camara       ON evento (camara_id, confirmado_en DESC);
CREATE INDEX idx_evento_expiracion   ON evento (imagen_expira_en) WHERE ruta_imagen IS NOT NULL;
CREATE INDEX idx_notificacion_evento ON notificacion (evento_id, enviada_en);
CREATE INDEX idx_usuario_rol         ON usuario (rol_id);
CREATE INDEX idx_auditoria_fecha     ON auditoria (fecha DESC);
CREATE INDEX idx_dataset_particion   ON dataset_imagen (particion, condicion);

-- ---------------------------------------------------------------------
-- Disparadores (privacidad y auditoría)
-- ---------------------------------------------------------------------
-- RNF-04: fija la fecha de expiración de la imagen según la configuración de la zona
CREATE TRIGGER trg_evento_expiracion
AFTER INSERT ON evento
WHEN NEW.ruta_imagen IS NOT NULL AND NEW.imagen_expira_en IS NULL
BEGIN
    UPDATE evento
       SET imagen_expira_en = datetime(NEW.confirmado_en,
             '+' || COALESCE((SELECT c.retencion_imagenes_dias
                                FROM configuracion c
                                JOIN camara ca ON ca.zona_id = c.zona_id
                               WHERE ca.id = NEW.camara_id), 8) || ' days')
     WHERE id = NEW.id;
END;

-- RNF-05: toda modificación de la configuración queda auditada
CREATE TRIGGER trg_auditoria_configuracion
AFTER UPDATE ON configuracion
BEGIN
    INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, detalle)
    VALUES (NEW.actualizado_por, 'actualizar', 'configuracion', NEW.id,
            'tiempo_abandono_s ' || OLD.tiempo_abandono_s || '->' || NEW.tiempo_abandono_s ||
            '; confianza_minima ' || OLD.confianza_minima || '->' || NEW.confianza_minima);
END;

-- HU-06 / RNF-05: todo cambio de estado de una alerta queda auditado
CREATE TRIGGER trg_auditoria_estado_evento
AFTER UPDATE OF estado ON evento
WHEN OLD.estado <> NEW.estado
BEGIN
    INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, detalle)
    VALUES (NEW.atendido_por, 'actualizar', 'evento', NEW.id,
            'estado ' || OLD.estado || '->' || NEW.estado);
END;

-- RNF-05: la auditoría no puede modificarse ni borrarse
CREATE TRIGGER trg_auditoria_sin_update
BEFORE UPDATE ON auditoria
BEGIN
    SELECT RAISE(ABORT, 'La auditoría es de solo inserción');
END;

CREATE TRIGGER trg_auditoria_sin_delete
BEFORE DELETE ON auditoria
BEGIN
    SELECT RAISE(ABORT, 'La auditoría es de solo inserción');
END;

-- ---------------------------------------------------------------------
-- Vistas (HU-05, HU-06, RNF-02)
-- ---------------------------------------------------------------------
CREATE VIEW v_historial_eventos AS
SELECT e.id                AS evento_id,
       e.confirmado_en,
       z.nombre            AS zona,
       ca.nombre           AS camara,
       co.nombre_mostrar   AS objeto,
       e.confianza,
       e.estado,
       u.nombre            AS atendido_por,
       e.atendido_en,
       e.ruta_imagen
  FROM evento e
  JOIN camara ca       ON ca.id = e.camara_id
  JOIN zona z          ON z.id = ca.zona_id
  JOIN clase_objeto co ON co.id = e.clase_id
  LEFT JOIN usuario u  ON u.id = e.atendido_por;

CREATE VIEW v_latencia_alertas AS
SELECT e.id AS evento_id,
       e.confirmado_en,
       MIN(n.enviada_en) AS primera_notificacion,
       ROUND((julianday(MIN(n.enviada_en)) - julianday(e.confirmado_en)) * 86400, 1) AS latencia_s,
       CASE WHEN (julianday(MIN(n.enviada_en)) - julianday(e.confirmado_en)) * 86400 < 10
            THEN 1 ELSE 0 END AS cumple_10s
  FROM evento e
  JOIN notificacion n ON n.evento_id = e.id AND n.exitosa = 1
 GROUP BY e.id;

CREATE VIEW v_metricas_operativas AS
SELECT COUNT(*)                                             AS total_eventos,
       SUM(estado = 'atendida')                             AS atendidas,
       SUM(estado = 'falso_positivo')                       AS falsos_positivos,
       SUM(estado = 'pendiente')                            AS pendientes,
       ROUND(100.0 * SUM(estado = 'falso_positivo')
             / NULLIF(SUM(estado <> 'pendiente'), 0), 1)    AS pct_falsos_positivos_sobre_revisadas
  FROM evento;
