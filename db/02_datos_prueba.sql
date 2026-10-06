-- =====================================================================
-- Datos de prueba (FICTICIOS) para verificar el esquema y las consultas.
-- No corresponden a mediciones reales ni a personas reales.
-- Contraseña de todos los usuarios de prueba: Prueba#2026 (solo entorno de pruebas)
-- =====================================================================
PRAGMA foreign_keys = ON;

INSERT INTO rol (id, nombre, descripcion) VALUES
 (1,'administrador','Configura el sistema, gestiona usuarios y consulta el historial'),
 (2,'seguridad','Recibe alertas y marca su estado'),
 (3,'servicio_deteccion','Cuenta técnica del módulo de detección; solo registra eventos y notificaciones');

INSERT INTO permiso (rol_id, recurso, accion) VALUES
 (1,'usuario','leer'),(1,'usuario','crear'),(1,'usuario','actualizar'),(1,'usuario','eliminar'),
 (1,'zona','leer'),(1,'zona','crear'),(1,'zona','actualizar'),
 (1,'camara','leer'),(1,'camara','crear'),(1,'camara','actualizar'),
 (1,'configuracion','leer'),(1,'configuracion','crear'),(1,'configuracion','actualizar'),
 (1,'evento','leer'),(1,'notificacion','leer'),(1,'auditoria','leer'),
 (1,'evaluacion_modelo','leer'),(1,'evaluacion_modelo','crear'),
 (1,'dataset_imagen','leer'),(1,'dataset_imagen','crear'),(1,'dataset_imagen','actualizar'),
 (2,'evento','leer'),(2,'evento','actualizar'),(2,'notificacion','leer'),
 (2,'zona','leer'),(2,'camara','leer'),(2,'configuracion','leer'),
 (3,'evento','crear'),(3,'evento','leer'),(3,'notificacion','crear'),
 (3,'configuracion','leer'),(3,'camara','leer'),(3,'zona','leer');

INSERT INTO usuario (id, nombre, correo, hash_contrasena, rol_id) VALUES
 (1,'Administrador de pruebas','admin@prueba.local',
  'pbkdf2_sha256$200000$a1b2c3d4e5f60718$cd094912c95eb2d17923f0847764bc9da90decf77e7fd21f8a8a6bdbef7c867d',1),
 (2,'Guarda de seguridad de pruebas','seguridad@prueba.local',
  'pbkdf2_sha256$200000$0f1e2d3c4b5a6978$94b7aee16c5df7870bdd6c37ed5e1e683048a1882174f0166d0cd3ef3d60a34c',2),
 (3,'Servicio de detección','servicio@prueba.local',
  'pbkdf2_sha256$200000$99aa88bb77cc66dd$5de5b89192c623de175a358e27463d1ef9fbe47192a4ac3ea36baa7a2116f66d',3);

INSERT INTO zona (id, nombre, descripcion) VALUES
 (1,'Laboratorio de Cómputo 2','Área controlada de pruebas, Edificio Principal');

INSERT INTO camara (id, zona_id, nombre, referencia_rtsp, resolucion) VALUES
 (1,1,'Domo esquina','RTSP_LAB2_CAM1','1920x1080'),
 (2,1,'Domo entrada','RTSP_LAB2_CAM2','1920x1080');

INSERT INTO configuracion (zona_id, tiempo_abandono_s, confianza_minima, distancia_persona_px,
                           retencion_imagenes_dias, actualizado_por)
VALUES (1, 60, 0.50, 150, 8, 1);

INSERT INTO clase_objeto (id, nombre, nombre_mostrar) VALUES
 (1,'maletin','Maletín'),(2,'portatil','Computador portátil');

INSERT INTO evento (camara_id, clase_id, track_id, confianza, detectado_en, confirmado_en,
                    ruta_imagen, estado, atendido_por, atendido_en) VALUES
 (1,1,12,0.91,'2026-09-28 09:14:10','2026-09-28 09:15:10','alertas/2026-09-28/ev1.jpg','atendida',2,'2026-09-28 09:19:40'),
 (1,2, 7,0.88,'2026-09-28 14:02:05','2026-09-28 14:03:05','alertas/2026-09-28/ev2.jpg','falso_positivo',2,'2026-09-28 14:05:00'),
 (2,1, 3,0.79,'2026-10-05 08:30:00','2026-10-05 08:31:00','alertas/2026-10-05/ev3.jpg','atendida',2,'2026-10-05 08:36:12'),
 (1,2,15,0.93,'2026-10-05 10:12:30','2026-10-05 10:13:30','alertas/2026-10-05/ev4.jpg','atendida',2,'2026-10-05 10:17:00'),
 (1,1,21,0.66,'2026-10-05 15:45:00','2026-10-05 15:46:00','alertas/2026-10-05/ev5.jpg','falso_positivo',2,'2026-10-05 15:48:20'),
 (2,1, 4,0.84,'2026-10-06 09:00:20','2026-10-06 09:01:20','alertas/2026-10-06/ev6.jpg','atendida',2,'2026-10-06 09:04:00'),
 (1,2, 9,0.90,'2026-10-06 11:20:00','2026-10-06 11:21:00','alertas/2026-10-06/ev7.jpg','atendida',2,'2026-10-06 11:24:30'),
 (1,1,30,0.72,'2026-10-07 13:05:00','2026-10-07 13:06:00','alertas/2026-10-07/ev8.jpg','falso_positivo',2,'2026-10-07 13:08:00'),
 (2,2, 6,0.87,'2026-10-07 16:40:10','2026-10-07 16:41:10','alertas/2026-10-07/ev9.jpg','atendida',2,'2026-10-07 16:44:00');
INSERT INTO evento (camara_id, clase_id, track_id, confianza, detectado_en, confirmado_en, ruta_imagen) VALUES
 (1,1,33,0.81,'2026-10-08 08:10:00','2026-10-08 08:11:00','alertas/2026-10-08/ev10.jpg'),
 (1,2,35,0.95,'2026-10-08 09:30:00','2026-10-08 09:31:00','alertas/2026-10-08/ev11.jpg'),
 (2,1, 8,0.77,'2026-10-08 10:05:00','2026-10-08 10:06:00','alertas/2026-10-08/ev12.jpg');

-- Notificaciones: segundos transcurridos desde la confirmación del abandono.
-- El evento 12 simula una falla del panel y un envío tardío por Telegram (12 s).
WITH v(ev, canal, seg, ok, det) AS (VALUES
 (1,'panel',2,1,NULL),(1,'telegram',4,1,NULL),
 (2,'panel',2,1,NULL),(2,'telegram',5,1,NULL),
 (3,'panel',1,1,NULL),(3,'telegram',3,1,NULL),
 (4,'panel',2,1,NULL),(4,'telegram',3,1,NULL),
 (5,'panel',3,1,NULL),(5,'telegram',6,1,NULL),
 (6,'panel',2,1,NULL),(6,'telegram',5,0,'Tiempo de espera agotado'),
 (7,'panel',1,1,NULL),(7,'telegram',4,1,NULL),
 (8,'panel',2,1,NULL),(8,'telegram',5,1,NULL),
 (9,'panel',3,1,NULL),(9,'telegram',7,1,NULL),
 (10,'panel',2,1,NULL),(10,'telegram',4,1,NULL),
 (11,'panel',2,1,NULL),
 (12,'panel',3,0,'Panel sin conexión'),(12,'telegram',12,1,NULL))
INSERT INTO notificacion (evento_id, canal, enviada_en, exitosa, detalle)
SELECT v.ev, v.canal, datetime(e.confirmado_en, '+' || v.seg || ' seconds'), v.ok, v.det
  FROM v JOIN evento e ON e.id = v.ev;

INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, detalle, fecha) VALUES
 (1,'login_ok','usuario',1,'Inicio de sesión de prueba','2026-10-05 07:55:00'),
 (2,'login_ok','usuario',2,'Inicio de sesión de prueba','2026-10-05 08:00:00'),
 (NULL,'login_fallido','usuario',NULL,'Intento con correo inexistente','2026-10-05 08:02:00');

INSERT INTO dataset_imagen (ruta, particion, condicion, contiene_maletin, contiene_portatil,
                            consentimiento_ref, capturada_en) VALUES
 ('dataset/entrenamiento/img_0001.jpg','entrenamiento','normal',1,0,'CONS-001','2026-10-02 10:40:00'),
 ('dataset/entrenamiento/img_0002.jpg','entrenamiento','sombra',1,0,'CONS-001','2026-10-02 10:41:00'),
 ('dataset/entrenamiento/img_0003.jpg','entrenamiento','oclusion',1,1,'CONS-001','2026-10-02 10:42:00'),
 ('dataset/entrenamiento/img_0004.jpg','entrenamiento','contraluz',0,1,'CONS-001','2026-10-02 10:43:00'),
 ('dataset/entrenamiento/img_0005.jpg','entrenamiento','normal',0,1,'CONS-002','2026-10-02 11:10:00'),
 ('dataset/entrenamiento/img_0006.jpg','entrenamiento','oclusion',1,0,'CONS-002','2026-10-02 11:11:00'),
 ('dataset/validacion/img_0007.jpg','validacion','normal',1,1,'CONS-002','2026-10-02 11:12:00'),
 ('dataset/validacion/img_0008.jpg','validacion','sombra',0,1,'CONS-002','2026-10-02 11:13:00'),
 ('dataset/prueba/img_0009.jpg','prueba','oclusion',1,0,'CONS-003','2026-10-02 12:00:00'),
 ('dataset/prueba/img_0010.jpg','prueba','normal',1,1,'CONS-003','2026-10-02 12:01:00');
