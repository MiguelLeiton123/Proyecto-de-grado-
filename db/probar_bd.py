"""Ejecuta las pruebas de la base de datos y genera evidencia_pruebas_bd.md"""
import os, re, sqlite3

AQUI = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(AQUI, "deteccion_objetos.db")
SALIDA = os.path.join(AQUI, "evidencia_pruebas_bd.md")

src = sqlite3.connect(DB)
con = sqlite3.connect(":memory:")      # copia: las pruebas no modifican la BD entregada
src.backup(con)
con.execute("PRAGMA foreign_keys = ON")
out = []
def w(s=""): out.append(s)

def tabla(cur):
    cols = [d[0] for d in cur.description]
    filas = cur.fetchall()
    if not filas:
        return "_(sin filas)_"
    t = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for f in filas:
        t.append("| " + " | ".join("" if v is None else str(v) for v in f) + " |")
    return "\n".join(t)

w("# Evidencia de pruebas de la base de datos\n")
w(f"Motor: SQLite {sqlite3.sqlite_version}. Pruebas sobre una copia en memoria de `deteccion_objetos.db`.\n")

# 1. Integridad
w("## 1. Integridad estructural\n")
ic = con.execute("PRAGMA integrity_check").fetchone()[0]
fk = con.execute("PRAGMA foreign_key_check").fetchall()
tablas = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
w(f"- `PRAGMA integrity_check`: **{ic}**")
w(f"- `PRAGMA foreign_key_check`: **{len(fk)} violaciones**")
w(f"- Tablas ({len(tablas)}): {', '.join(tablas)}")
for tipo, nombre in (("index","índices"),("trigger","disparadores"),("view","vistas")):
    n = con.execute("SELECT COUNT(*) FROM sqlite_master WHERE type=? AND name NOT LIKE 'sqlite_%'", (tipo,)).fetchone()[0]
    w(f"- {nombre.capitalize()}: {n}")
w("\nConteo de filas de prueba por tabla:\n")
w("| Tabla | Filas |\n|---|---|")
for t in tablas:
    w(f"| {t} | {con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]} |")

# 2. Pruebas negativas
w("\n## 2. Pruebas de restricciones (deben ser rechazadas)\n")
w("| N.º | Intento | Requisito | Resultado |\n|---|---|---|---|")
negativas = [
 ("Estado de alerta inválido", "HU-06",
  "UPDATE evento SET estado='archivada' WHERE id=10"),
 ("Alerta atendida sin usuario ni fecha", "HU-06",
  "UPDATE evento SET estado='atendida' WHERE id=10"),
 ("Confianza fuera de rango (1.5)", "HU-01",
  "INSERT INTO evento (camara_id,clase_id,track_id,confianza,detectado_en,confirmado_en) VALUES (1,1,99,1.5,'2026-10-09 08:00:00','2026-10-09 08:01:00')"),
 ("Segunda alerta del mismo objeto", "HU-02",
  "INSERT INTO evento (camara_id,clase_id,track_id,confianza,detectado_en,confirmado_en) VALUES (1,1,33,0.8,'2026-10-08 08:10:00','2026-10-08 08:11:00')"),
 ("Confirmación anterior a la detección", "HU-02",
  "INSERT INTO evento (camara_id,clase_id,track_id,confianza,detectado_en,confirmado_en) VALUES (1,1,98,0.8,'2026-10-09 08:05:00','2026-10-09 08:00:00')"),
 ("Evento con cámara inexistente", "Integridad",
  "INSERT INTO evento (camara_id,clase_id,track_id,confianza,detectado_en,confirmado_en) VALUES (99,1,97,0.8,'2026-10-09 08:00:00','2026-10-09 08:01:00')"),
 ("Tiempo de abandono de 2 s", "HU-04",
  "UPDATE configuracion SET tiempo_abandono_s=2 WHERE zona_id=1"),
 ("Retención de imágenes de 30 días", "RNF-04",
  "UPDATE configuracion SET retencion_imagenes_dias=30 WHERE zona_id=1"),
 ("Cámara con URL RTSP (credenciales) en la BD", "RNF-04/05",
  "INSERT INTO camara (zona_id,nombre,referencia_rtsp) VALUES (1,'Prueba','rtsp://usuario:clave@10.0.0.5/stream')"),
 ("Imagen de dataset con rostro identificable", "S-03/RNF-04",
  "INSERT INTO dataset_imagen (ruta,particion,contiene_maletin,consentimiento_ref,rostro_identificable,capturada_en) VALUES ('x.jpg','prueba',1,'CONS-9',1,'2026-10-09 10:00:00')"),
 ("Imagen de dataset sin consentimiento", "S-03",
  "INSERT INTO dataset_imagen (ruta,particion,contiene_maletin,consentimiento_ref,capturada_en) VALUES ('y.jpg','prueba',1,'','2026-10-09 10:00:00')"),
 ("Contraseña en texto plano", "RNF-05",
  "INSERT INTO usuario (nombre,correo,hash_contrasena,rol_id) VALUES ('X','x@prueba.local','1234',2)"),
 ("Correo duplicado", "RNF-05",
  "INSERT INTO usuario (nombre,correo,hash_contrasena,rol_id) VALUES ('X','admin@prueba.local','pbkdf2_sha256$1$aa$bb',2)"),
 ("Modificar un registro de auditoría", "RNF-05",
  "UPDATE auditoria SET detalle='alterado' WHERE id=1"),
 ("Borrar un registro de auditoría", "RNF-05",
  "DELETE FROM auditoria WHERE id=1"),
]
ok_neg = 0
for i,(desc,req,sql) in enumerate(negativas,1):
    con.execute("SAVEPOINT t")
    try:
        con.execute(sql); res = "NO RECHAZADA (fallo de la prueba)"
    except sqlite3.Error as e:
        res = f"Rechazada: {str(e)[:70]}"; ok_neg += 1
    con.execute("ROLLBACK TO t"); con.execute("RELEASE t")
    w(f"| {i} | {desc} | {req} | {res} |")
w(f"\n**{ok_neg} de {len(negativas)} intentos inválidos fueron rechazados.**")

# 3. Comportamiento de disparadores
w("\n## 3. Comportamiento de disparadores\n")
con.execute("SAVEPOINT d")
exp = con.execute("SELECT confirmado_en, imagen_expira_en FROM evento WHERE id=1").fetchone()
w(f"- Expiración automática de imagen (retención 8 días): evento 1 confirmado `{exp[0]}` → expira `{exp[1]}`.")
n0 = con.execute("SELECT COUNT(*) FROM auditoria").fetchone()[0]
con.execute("UPDATE configuracion SET tiempo_abandono_s=45, actualizado_por=1 WHERE zona_id=1")
a = con.execute("SELECT accion, entidad, detalle FROM auditoria ORDER BY id DESC LIMIT 1").fetchone()
w(f"- Cambio de configuración auditado automáticamente: `{a[0]} {a[1]}` → {a[2]}.")
con.execute("UPDATE evento SET estado='atendida', atendido_por=2, atendido_en='2026-10-08 08:20:00' WHERE id=10")
a = con.execute("SELECT accion, entidad, detalle FROM auditoria ORDER BY id DESC LIMIT 1").fetchone()
w(f"- Cambio de estado de alerta auditado automáticamente: `{a[0]} {a[1]}` → {a[2]}.")
n1 = con.execute("SELECT COUNT(*) FROM auditoria").fetchone()[0]
w(f"- Registros de auditoría: {n0} → {n1}.")
con.execute("INSERT INTO evaluacion_modelo (modelo_version,conjunto,map50,recall,f1,fps,latencia_media_s,observaciones) VALUES ('PRUEBA-ESTRUCTURA','prueba',0.5,0.5,0.5,12,3.0,'Fila de verificación; se revierte')")
c = con.execute("SELECT COUNT(*) FROM evaluacion_modelo").fetchone()[0]
w(f"- Inserción de una evaluación de modelo de verificación: {c} fila (se revierte; no es un resultado real).")
con.execute("ROLLBACK TO d"); con.execute("RELEASE d")

# 4. Purga de imágenes
w("\n## 4. Purga de imágenes vencidas (RNF-04), con fecha de referencia 2026-10-10\n")
antes = con.execute("SELECT COUNT(*) FROM evento WHERE ruta_imagen IS NOT NULL").fetchone()[0]
purga = open(os.path.join(AQUI, "04_purga_imagenes.sql"), encoding="utf-8").read().replace("datetime('now')", "'2026-10-10 00:00:00'")
con.execute("SAVEPOINT p")
con.execute(purga.strip().rstrip(";"))
despues = con.execute("SELECT COUNT(*) FROM evento WHERE ruta_imagen IS NOT NULL").fetchone()[0]
total = con.execute("SELECT COUNT(*) FROM evento").fetchone()[0]
w(f"- Eventos con imagen antes: {antes}; después: {despues}; eventos conservados en el historial: {total}.")
con.execute("ROLLBACK TO p"); con.execute("RELEASE p")

# 5. Consultas de comprobación
w("\n## 5. Consultas de comprobación (archivo `03_consultas_comprobacion.sql`)\n")
sql = open(os.path.join(AQUI, "03_consultas_comprobacion.sql"), encoding="utf-8").read()
bloques = re.split(r"\n(?=-- C\d+b? )", sql)
for b in bloques:
    m = re.match(r"-- (C\d+b?) (.*)", b.strip())
    if not m: continue
    titulo = m.group(0)[3:]
    cuerpo = "\n".join(l for l in b.splitlines() if not l.startswith("--")).strip()
    cur = con.execute(cuerpo.rstrip(";"))
    w(f"### {titulo}\n")
    w("```sql\n" + cuerpo + "\n```\n")
    w(tabla(cur) + "\n")

open(SALIDA, "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out[:40]))
print("...")
print("Pruebas negativas rechazadas:", ok_neg, "/", len(negativas))
