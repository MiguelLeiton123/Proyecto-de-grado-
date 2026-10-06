# Evidencia de pruebas de la base de datos

Motor: SQLite 3.45.1. Pruebas sobre una copia en memoria de `deteccion_objetos.db`.

## 1. Integridad estructural

- `PRAGMA integrity_check`: **ok**
- `PRAGMA foreign_key_check`: **0 violaciones**
- Tablas (12): auditoria, camara, clase_objeto, configuracion, dataset_imagen, evaluacion_modelo, evento, notificacion, permiso, rol, usuario, zona
- Índices: 8
- Disparadores: 5
- Vistas: 3

Conteo de filas de prueba por tabla:

| Tabla | Filas |
|---|---|
| auditoria | 3 |
| camara | 2 |
| clase_objeto | 2 |
| configuracion | 1 |
| dataset_imagen | 10 |
| evaluacion_modelo | 0 |
| evento | 12 |
| notificacion | 23 |
| permiso | 33 |
| rol | 3 |
| usuario | 3 |
| zona | 1 |

## 2. Pruebas de restricciones (deben ser rechazadas)

| N.º | Intento | Requisito | Resultado |
|---|---|---|---|
| 1 | Estado de alerta inválido | RF HU-06 | Rechazada: CHECK constraint failed: estado IN ('pendiente','atendida','falso_posi |
| 2 | Alerta atendida sin usuario ni fecha | HU-06 | Rechazada: CHECK constraint failed: (estado = 'pendiente' AND atendido_por IS NUL |
| 3 | Confianza fuera de rango (1.5) | HU-01 | Rechazada: CHECK constraint failed: confianza > 0 AND confianza <= 1 |
| 4 | Segunda alerta del mismo objeto | HU-02 | Rechazada: UNIQUE constraint failed: evento.camara_id, evento.track_id, evento.de |
| 5 | Confirmación anterior a la detección | HU-02 | Rechazada: CHECK constraint failed: confirmado_en >= detectado_en |
| 6 | Evento con cámara inexistente | Integridad | Rechazada: FOREIGN KEY constraint failed |
| 7 | Tiempo de abandono de 2 s | HU-04 | Rechazada: CHECK constraint failed: tiempo_abandono_s BETWEEN 5 AND 3600 |
| 8 | Retención de imágenes de 30 días | RNF-04 | Rechazada: CHECK constraint failed: retencion_imagenes_dias BETWEEN 1 AND 8 |
| 9 | Cámara con URL RTSP (credenciales) en la BD | RNF-04/05 | Rechazada: CHECK constraint failed: referencia_rtsp NOT LIKE 'rtsp://%' |
| 10 | Imagen de dataset con rostro identificable | S-03/RNF-04 | Rechazada: CHECK constraint failed: rostro_identificable = 0 |
| 11 | Imagen de dataset sin consentimiento | S-03 | Rechazada: CHECK constraint failed: length(trim(consentimiento_ref)) > 0 |
| 12 | Contraseña en texto plano | RNF-05 | Rechazada: CHECK constraint failed: hash_contrasena LIKE 'pbkdf2_sha256$%' |
| 13 | Correo duplicado | RNF-05 | Rechazada: UNIQUE constraint failed: usuario.correo |
| 14 | Modificar un registro de auditoría | RNF-05 | Rechazada: La auditoría es de solo inserción |
| 15 | Borrar un registro de auditoría | RNF-05 | Rechazada: La auditoría es de solo inserción |

**15 de 15 intentos inválidos fueron rechazados.**

## 3. Comportamiento de disparadores

- Expiración automática de imagen (retención 8 días): evento 1 confirmado `2026-09-28 09:15:10` → expira `2026-10-06 09:15:10`.
- Cambio de configuración auditado automáticamente: `actualizar configuracion` → tiempo_abandono_s 60->45; confianza_minima 0.5->0.5.
- Cambio de estado de alerta auditado automáticamente: `actualizar evento` → estado pendiente->atendida.
- Registros de auditoría: 3 → 5.
- Inserción de una evaluación de modelo de verificación: 1 fila (se revierte; no es un resultado real).

## 4. Purga de imágenes vencidas (RNF-04), con fecha de referencia 2026-10-10

- Eventos con imagen antes: 12; después: 10; eventos conservados en el historial: 12.

## 5. Consultas de comprobación (archivo `03_consultas_comprobacion.sql`)

### C1 (HU-07): composición del dataset por partición y condición

```sql
SELECT particion, condicion, COUNT(*) AS imagenes
  FROM dataset_imagen
 GROUP BY particion, condicion
 ORDER BY particion, condicion;
```

| particion | condicion | imagenes |
|---|---|---|
| entrenamiento | contraluz | 1 |
| entrenamiento | normal | 2 |
| entrenamiento | oclusion | 2 |
| entrenamiento | sombra | 1 |
| prueba | normal | 1 |
| prueba | oclusion | 1 |
| validacion | normal | 1 |
| validacion | sombra | 1 |

### C2 (HU-02): no debe haber más de una alerta por objeto (esperado: 0 filas)

```sql
SELECT camara_id, track_id, detectado_en, COUNT(*) AS alertas
  FROM evento
 GROUP BY camara_id, track_id, detectado_en
HAVING COUNT(*) > 1;
```

_(sin filas)_

### C3 (HU-03 / RNF-02): latencia de notificación y cumplimiento del umbral de 10 s

```sql
SELECT COUNT(*)                                   AS eventos_notificados,
       SUM(cumple_10s)                            AS cumplen_menos_10s,
       ROUND(100.0 * SUM(cumple_10s) / COUNT(*),1) AS pct_cumplimiento,
       ROUND(AVG(latencia_s),1)                   AS latencia_media_s,
       MAX(latencia_s)                            AS latencia_maxima_s
  FROM v_latencia_alertas;
```

| eventos_notificados | cumplen_menos_10s | pct_cumplimiento | latencia_media_s | latencia_maxima_s |
|---|---|---|---|---|
| 12 | 11 | 91.7 | 2.8 | 12.0 |

### C3b (RNF-02): eventos que incumplen el umbral (deben revisarse en la validación)

```sql
SELECT evento_id, confirmado_en, primera_notificacion, latencia_s
  FROM v_latencia_alertas
 WHERE cumple_10s = 0;
```

| evento_id | confirmado_en | primera_notificacion | latencia_s |
|---|---|---|---|
| 12 | 2026-10-08 10:06:00 | 2026-10-08 10:06:12 | 12.0 |

### C4 (HU-04): configuración vigente por zona

```sql
SELECT z.nombre AS zona, c.tiempo_abandono_s, c.confianza_minima,
       c.distancia_persona_px, c.retencion_imagenes_dias, c.actualizado_en
  FROM configuracion c
  JOIN zona z ON z.id = c.zona_id;
```

| zona | tiempo_abandono_s | confianza_minima | distancia_persona_px | retencion_imagenes_dias | actualizado_en |
|---|---|---|---|---|---|
| Laboratorio de Cómputo 2 | 60 | 0.5 | 150 | 8 | 2026-10-05 00:27:48 |

### C5 (HU-05): historial de los 5 eventos más recientes

```sql
SELECT evento_id, confirmado_en, zona, camara, objeto, estado, atendido_por
  FROM v_historial_eventos
 ORDER BY confirmado_en DESC
 LIMIT 5;
```

| evento_id | confirmado_en | zona | camara | objeto | estado | atendido_por |
|---|---|---|---|---|---|---|
| 12 | 2026-10-08 10:06:00 | Laboratorio de Cómputo 2 | Domo entrada | Maletín | pendiente |  |
| 11 | 2026-10-08 09:31:00 | Laboratorio de Cómputo 2 | Domo esquina | Computador portátil | pendiente |  |
| 10 | 2026-10-08 08:11:00 | Laboratorio de Cómputo 2 | Domo esquina | Maletín | pendiente |  |
| 9 | 2026-10-07 16:41:10 | Laboratorio de Cómputo 2 | Domo entrada | Computador portátil | atendida | Guarda de seguridad de pruebas |
| 8 | 2026-10-07 13:06:00 | Laboratorio de Cómputo 2 | Domo esquina | Maletín | falso_positivo | Guarda de seguridad de pruebas |

### C6 (HU-06): estado de las alertas y tasa de falsos positivos

```sql
SELECT * FROM v_metricas_operativas;
```

| total_eventos | atendidas | falsos_positivos | pendientes | pct_falsos_positivos_sobre_revisadas |
|---|---|---|---|---|
| 12 | 6 | 3 | 3 | 33.3 |

### C7 (RNF-04): imágenes vencidas pendientes de purga a una fecha de referencia

```sql
SELECT COUNT(*) AS imagenes_vencidas
  FROM evento
 WHERE ruta_imagen IS NOT NULL
   AND imagen_expira_en <= '2026-10-10 00:00:00';
```

| imagenes_vencidas |
|---|
| 2 |

### C8 (RNF-05): matriz de permisos por perfil

```sql
SELECT r.nombre AS perfil, p.recurso, GROUP_CONCAT(p.accion, ',') AS acciones
  FROM permiso p
  JOIN rol r ON r.id = p.rol_id
 GROUP BY r.nombre, p.recurso
 ORDER BY r.id, p.recurso;
```

| perfil | recurso | acciones |
|---|---|---|
| administrador | auditoria | leer |
| administrador | camara | actualizar,crear,leer |
| administrador | configuracion | actualizar,crear,leer |
| administrador | dataset_imagen | actualizar,crear,leer |
| administrador | evaluacion_modelo | crear,leer |
| administrador | evento | leer |
| administrador | notificacion | leer |
| administrador | usuario | actualizar,crear,eliminar,leer |
| administrador | zona | actualizar,crear,leer |
| seguridad | camara | leer |
| seguridad | configuracion | leer |
| seguridad | evento | actualizar,leer |
| seguridad | notificacion | leer |
| seguridad | zona | leer |
| servicio_deteccion | camara | leer |
| servicio_deteccion | configuracion | leer |
| servicio_deteccion | evento | crear,leer |
| servicio_deteccion | notificacion | crear |
| servicio_deteccion | zona | leer |

### C9 (RNF-03): resultados de evaluación del modelo (vacía hasta el corte 3)

```sql
SELECT modelo_version, conjunto, map50, recall, f1, fps, latencia_media_s
  FROM evaluacion_modelo
 ORDER BY evaluado_en DESC;
```

_(sin filas)_

### C10 (RNF-05): últimos registros de auditoría

```sql
SELECT fecha, accion, entidad, entidad_id, detalle
  FROM auditoria
 ORDER BY id DESC
 LIMIT 5;
```

| fecha | accion | entidad | entidad_id | detalle |
|---|---|---|---|---|
| 2026-10-05 08:02:00 | login_fallido | usuario |  | Intento con correo inexistente |
| 2026-10-05 08:00:00 | login_ok | usuario | 2 | Inicio de sesión de prueba |
| 2026-10-05 07:55:00 | login_ok | usuario | 1 | Inicio de sesión de prueba |

### C11 (rendimiento): el historial por rango de fechas usa el índice idx_evento_confirmado

```sql
EXPLAIN QUERY PLAN
SELECT evento_id FROM v_historial_eventos
 WHERE confirmado_en BETWEEN '2026-10-05 00:00:00' AND '2026-10-07 23:59:59';
```

| id | parent | notused | detail |
|---|---|---|---|
| 6 | 0 | 0 | SEARCH e USING INDEX idx_evento_confirmado (confirmado_en>? AND confirmado_en<?) |
| 12 | 0 | 0 | SEARCH ca USING INTEGER PRIMARY KEY (rowid=?) |
| 15 | 0 | 0 | SEARCH z USING INTEGER PRIMARY KEY (rowid=?) |
| 18 | 0 | 0 | SEARCH co USING INTEGER PRIMARY KEY (rowid=?) |
