-- =====================================================================
-- Consultas de comprobación del diseño (cada una referencia su requisito)
-- =====================================================================

-- C1 (HU-07): composición del dataset por partición y condición
SELECT particion, condicion, COUNT(*) AS imagenes
  FROM dataset_imagen
 GROUP BY particion, condicion
 ORDER BY particion, condicion;

-- C2 (HU-02): no debe haber más de una alerta por objeto (esperado: 0 filas)
SELECT camara_id, track_id, detectado_en, COUNT(*) AS alertas
  FROM evento
 GROUP BY camara_id, track_id, detectado_en
HAVING COUNT(*) > 1;

-- C3 (HU-03 / RNF-02): latencia de notificación y cumplimiento del umbral de 10 s
SELECT COUNT(*)                                   AS eventos_notificados,
       SUM(cumple_10s)                            AS cumplen_menos_10s,
       ROUND(100.0 * SUM(cumple_10s) / COUNT(*),1) AS pct_cumplimiento,
       ROUND(AVG(latencia_s),1)                   AS latencia_media_s,
       MAX(latencia_s)                            AS latencia_maxima_s
  FROM v_latencia_alertas;

-- C3b (RNF-02): eventos que incumplen el umbral (deben revisarse en la validación)
SELECT evento_id, confirmado_en, primera_notificacion, latencia_s
  FROM v_latencia_alertas
 WHERE cumple_10s = 0;

-- C4 (HU-04): configuración vigente por zona
SELECT z.nombre AS zona, c.tiempo_abandono_s, c.confianza_minima,
       c.distancia_persona_px, c.retencion_imagenes_dias, c.actualizado_en
  FROM configuracion c
  JOIN zona z ON z.id = c.zona_id;

-- C5 (HU-05): historial de los 5 eventos más recientes
SELECT evento_id, confirmado_en, zona, camara, objeto, estado, atendido_por
  FROM v_historial_eventos
 ORDER BY confirmado_en DESC
 LIMIT 5;

-- C6 (HU-06): estado de las alertas y tasa de falsos positivos
SELECT * FROM v_metricas_operativas;

-- C7 (RNF-04): imágenes vencidas pendientes de purga a una fecha de referencia
-- (en producción se usa datetime('now'))
SELECT COUNT(*) AS imagenes_vencidas
  FROM evento
 WHERE ruta_imagen IS NOT NULL
   AND imagen_expira_en <= '2026-10-10 00:00:00';

-- C8 (RNF-05): matriz de permisos por perfil
SELECT r.nombre AS perfil, p.recurso, GROUP_CONCAT(p.accion, ',') AS acciones
  FROM permiso p
  JOIN rol r ON r.id = p.rol_id
 GROUP BY r.nombre, p.recurso
 ORDER BY r.id, p.recurso;

-- C9 (RNF-03): resultados de evaluación del modelo (vacía hasta el corte 3)
SELECT modelo_version, conjunto, map50, recall, f1, fps, latencia_media_s
  FROM evaluacion_modelo
 ORDER BY evaluado_en DESC;

-- C10 (RNF-05): últimos registros de auditoría
SELECT fecha, accion, entidad, entidad_id, detalle
  FROM auditoria
 ORDER BY id DESC
 LIMIT 5;

-- C11 (rendimiento): el historial por rango de fechas usa el índice idx_evento_confirmado
EXPLAIN QUERY PLAN
SELECT evento_id FROM v_historial_eventos
 WHERE confirmado_en BETWEEN '2026-10-05 00:00:00' AND '2026-10-07 23:59:59';
