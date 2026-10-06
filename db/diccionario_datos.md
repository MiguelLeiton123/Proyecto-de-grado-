# Diccionario de datos

Generado a partir de la estructura real de `deteccion_objetos.db`.

## rol

Perfiles de acceso del sistema. Requisitos: RNF-05.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador del perfil. |
| nombre | TEXT | No |  |  | Nombre del perfil (administrador, seguridad, servicio_deteccion). |
| descripcion | TEXT | No |  |  | Responsabilidad del perfil. |

## permiso

Matriz de permisos: qué acción puede hacer cada perfil sobre cada recurso. Requisitos: RNF-05.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| rol_id | INTEGER | No | PK |  | Perfil al que se concede el permiso. |
| recurso | TEXT | No | PK |  | Entidad protegida. |
| accion | TEXT | No | PK |  | Acción permitida (leer, crear, actualizar, eliminar). |

## usuario

Personas y cuentas técnicas que acceden al sistema. Requisitos: RNF-05, HU-04.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador del usuario. |
| nombre | TEXT | No |  |  | Nombre visible. |
| correo | TEXT | No |  |  | Correo único de acceso. |
| hash_contrasena | TEXT | No |  |  | Hash PBKDF2-SHA256 con sal; nunca la contraseña. |
| rol_id | INTEGER | No | FK → rol(id) |  | Perfil asignado. |
| activo | INTEGER | No |  | 1 | 1 activo, 0 desactivado (no se borran usuarios). |
| intentos_fallidos | INTEGER | No |  | 0 | Contador para bloqueo por intentos fallidos. |
| creado_en | TEXT | No |  | datetime('now') | Fecha de creación. |

## zona

Áreas vigiladas. Requisitos: HU-04.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador de la zona. |
| nombre | TEXT | No |  |  | Nombre único de la zona. |
| descripcion | TEXT | Sí |  |  | Ubicación o detalles. |
| activa | INTEGER | No |  | 1 | 1 vigilada, 0 inactiva. |

## camara

Cámaras IP asociadas a una zona. Requisitos: RNF-01, RNF-07.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador de la cámara. |
| zona_id | INTEGER | No | FK → zona(id) |  | Zona donde está instalada. |
| nombre | TEXT | No |  |  | Nombre de la cámara dentro de la zona. |
| referencia_rtsp | TEXT | No |  |  | Nombre de la variable de entorno con la URL RTSP; no guarda credenciales. |
| resolucion | TEXT | No |  | '1920x1080' | Resolución de captura. |
| activa | INTEGER | No |  | 1 | 1 en uso, 0 inactiva. |

## configuracion

Parámetros de detección por zona. Requisitos: HU-04, RNF-04.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador. |
| zona_id | INTEGER | No | FK → zona(id) |  | Zona a la que aplica (una configuración por zona). |
| tiempo_abandono_s | INTEGER | No |  | 60 | Segundos sin persona cerca para considerar abandonado un objeto (5 a 3600; defecto 60). |
| confianza_minima | REAL | No |  | 0.50 | Confianza mínima del detector (0 a 1; defecto 0.50). |
| distancia_persona_px | INTEGER | No |  | 150 | Distancia máxima en píxeles para considerar que una persona está cerca del objeto. |
| retencion_imagenes_dias | INTEGER | No |  | 8 | Días de conservación de imágenes de alerta (máximo 8). |
| actualizado_por | INTEGER | Sí | FK → usuario(id) |  | Usuario que modificó la configuración. |
| actualizado_en | TEXT | No |  | datetime('now') | Fecha de la última modificación. |

## clase_objeto

Clases de objeto que detecta el modelo. Requisitos: HU-01.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador de la clase. |
| nombre | TEXT | No |  |  | Clave técnica (maletin, portatil). |
| nombre_mostrar | TEXT | No |  |  | Nombre mostrado al usuario. |

## evento

Alertas de objetos abandonados confirmados. Requisitos: HU-02, HU-03, HU-05, HU-06.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador del evento. |
| camara_id | INTEGER | No | FK → camara(id) |  | Cámara que lo detectó. |
| clase_id | INTEGER | No | FK → clase_objeto(id) |  | Tipo de objeto. |
| track_id | INTEGER | No |  |  | Identificador de seguimiento del objeto (tracker). |
| confianza | REAL | No |  |  | Confianza de la detección (0 a 1). |
| detectado_en | TEXT | No |  |  | Instante en que el objeto quedó estático. |
| confirmado_en | TEXT | No |  |  | Instante en que se cumplió el tiempo de abandono; origen del cálculo de latencia. |
| ruta_imagen | TEXT | Sí |  |  | Ruta de la imagen de alerta; NULL si fue purgada. |
| imagen_expira_en | TEXT | Sí |  |  | Fecha límite de conservación de la imagen (la calcula un disparador). |
| estado | TEXT | No |  | 'pendiente' | pendiente, atendida o falso_positivo. |
| atendido_por | INTEGER | Sí | FK → usuario(id) |  | Usuario que cerró el evento. |
| atendido_en | TEXT | Sí |  |  | Fecha del cierre. |

## notificacion

Envíos de alerta por canal. Requisitos: HU-03, RNF-02.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador. |
| evento_id | INTEGER | No | FK → evento(id) |  | Evento notificado. |
| canal | TEXT | No |  |  | panel, telegram o correo. |
| enviada_en | TEXT | No |  |  | Instante del envío. |
| exitosa | INTEGER | No |  |  | 1 si se entregó, 0 si falló. |
| detalle | TEXT | Sí |  |  | Motivo del fallo, si aplica. |

## auditoria

Registro inmutable de acciones sensibles. Requisitos: RNF-05.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador. |
| usuario_id | INTEGER | Sí | FK → usuario(id) |  | Usuario que realizó la acción (NULL si es anónimo). |
| accion | TEXT | No |  |  | Tipo de acción. |
| entidad | TEXT | No |  |  | Entidad afectada. |
| entidad_id | INTEGER | Sí |  |  | Identificador del registro afectado. |
| detalle | TEXT | Sí |  |  | Descripción del cambio. |
| fecha | TEXT | No |  | datetime('now') | Instante de la acción. |

## dataset_imagen

Registro de imágenes del dataset propio y su consentimiento. Requisitos: HU-07, S-03.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador. |
| ruta | TEXT | No |  |  | Ruta única del archivo. |
| particion | TEXT | No |  |  | entrenamiento, validacion o prueba. |
| condicion | TEXT | No |  | 'normal' | normal, sombra, oclusion o contraluz (H-07). |
| contiene_maletin | INTEGER | No |  | 0 | 1 si la imagen contiene un maletín. |
| contiene_portatil | INTEGER | No |  | 0 | 1 si contiene un portátil. |
| consentimiento_ref | TEXT | No |  |  | Referencia del consentimiento de los participantes. |
| rostro_identificable | INTEGER | No |  | 0 | Siempre 0: no se admiten rostros identificables. |
| capturada_en | TEXT | No |  |  | Fecha de captura. |

## evaluacion_modelo

Resultados de la evaluación del modelo. Requisitos: RNF-03, RNF-01.

| Columna | Tipo | Nulo | Clave | Defecto | Descripción |
|---|---|---|---|---|---|
| id | INTEGER | No | PK |  | Identificador. |
| modelo_version | TEXT | No |  |  | Versión del modelo evaluado. |
| conjunto | TEXT | No |  |  | validacion o prueba. |
| map50 | REAL | No |  |  | mAP@0.5 (0 a 1). |
| recall | REAL | No |  |  | Recall (0 a 1). |
| f1 | REAL | No |  |  | F1-Score (0 a 1). |
| fps | REAL | No |  |  | Cuadros por segundo medidos. |
| latencia_media_s | REAL | Sí |  |  | Latencia media de notificación en segundos. |
| evaluado_en | TEXT | No |  | datetime('now') | Fecha de la evaluación. |
| observaciones | TEXT | Sí |  |  | Notas. |
