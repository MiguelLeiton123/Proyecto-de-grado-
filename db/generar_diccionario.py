"""Genera diccionario_datos.md y diccionario_datos.json leyendo la estructura real de la BD."""
import json, os, sqlite3
AQUI = os.path.dirname(os.path.abspath(__file__))
con = sqlite3.connect(os.path.join(AQUI, "deteccion_objetos.db"))

D = {
"rol": ("Perfiles de acceso del sistema.", "RNF-05", {
  "id":"Identificador del perfil.","nombre":"Nombre del perfil (administrador, seguridad, servicio_deteccion).","descripcion":"Responsabilidad del perfil."}),
"permiso": ("Matriz de permisos: qué acción puede hacer cada perfil sobre cada recurso.", "RNF-05", {
  "rol_id":"Perfil al que se concede el permiso.","recurso":"Entidad protegida.","accion":"Acción permitida (leer, crear, actualizar, eliminar)."}),
"usuario": ("Personas y cuentas técnicas que acceden al sistema.", "RNF-05, HU-04", {
  "id":"Identificador del usuario.","nombre":"Nombre visible.","correo":"Correo único de acceso.","hash_contrasena":"Hash PBKDF2-SHA256 con sal; nunca la contraseña.","rol_id":"Perfil asignado.","activo":"1 activo, 0 desactivado (no se borran usuarios).","intentos_fallidos":"Contador de intentos de acceso fallidos consecutivos.","bloqueado_hasta":"Fecha hasta la que la cuenta permanece bloqueada (5 intentos fallidos).","creado_en":"Fecha de creación."}),
"zona": ("Áreas vigiladas.", "HU-04", {
  "id":"Identificador de la zona.","nombre":"Nombre único de la zona.","descripcion":"Ubicación o detalles.","activa":"1 vigilada, 0 inactiva."}),
"camara": ("Cámaras IP asociadas a una zona.", "RNF-01, RNF-07", {
  "id":"Identificador de la cámara.","zona_id":"Zona donde está instalada.","nombre":"Nombre de la cámara dentro de la zona.","referencia_rtsp":"Nombre de la variable de entorno con la URL RTSP; no guarda credenciales.","resolucion":"Resolución de captura.","activa":"1 en uso, 0 inactiva."}),
"configuracion": ("Parámetros de detección por zona.", "HU-04, RNF-04", {
  "id":"Identificador.","zona_id":"Zona a la que aplica (una configuración por zona).","tiempo_abandono_s":"Segundos sin persona cerca para considerar abandonado un objeto (5 a 3600; defecto 60).","confianza_minima":"Confianza mínima del detector (0 a 1; defecto 0.50).","distancia_persona_px":"Distancia máxima en píxeles para considerar que una persona está cerca del objeto.","retencion_imagenes_dias":"Días de conservación de imágenes de alerta (máximo 8).","actualizado_por":"Usuario que modificó la configuración.","actualizado_en":"Fecha de la última modificación."}),
"clase_objeto": ("Clases de objeto que detecta el modelo.", "HU-01", {
  "id":"Identificador de la clase.","nombre":"Clave técnica (maletin, portatil).","nombre_mostrar":"Nombre mostrado al usuario."}),
"evento": ("Alertas de objetos abandonados confirmados.", "HU-02, HU-03, HU-05, HU-06", {
  "id":"Identificador del evento.","camara_id":"Cámara que lo detectó.","clase_id":"Tipo de objeto.","track_id":"Identificador de seguimiento del objeto (tracker).","confianza":"Confianza de la detección (0 a 1).","detectado_en":"Instante en que el objeto quedó estático.","confirmado_en":"Instante en que se cumplió el tiempo de abandono; origen del cálculo de latencia.","ruta_imagen":"Ruta de la imagen de alerta; NULL si fue purgada.","imagen_expira_en":"Fecha límite de conservación de la imagen (la calcula un disparador).","estado":"pendiente, atendida o falso_positivo.","atendido_por":"Usuario que cerró el evento.","atendido_en":"Fecha del cierre."}),
"notificacion": ("Envíos de alerta por canal.", "HU-03, RNF-02", {
  "id":"Identificador.","evento_id":"Evento notificado.","canal":"panel, telegram o correo.","enviada_en":"Instante del envío.","exitosa":"1 si se entregó, 0 si falló.","detalle":"Motivo del fallo, si aplica."}),
"auditoria": ("Registro inmutable de acciones sensibles.", "RNF-05", {
  "id":"Identificador.","usuario_id":"Usuario que realizó la acción (NULL si es anónimo).","accion":"Tipo de acción.","entidad":"Entidad afectada.","entidad_id":"Identificador del registro afectado.","detalle":"Descripción del cambio.","fecha":"Instante de la acción."}),
"dataset_imagen": ("Registro de imágenes del dataset propio y su consentimiento.", "HU-07, S-03", {
  "id":"Identificador.","ruta":"Ruta única del archivo.","particion":"entrenamiento, validacion o prueba.","condicion":"normal, sombra, oclusion o contraluz (H-07).","contiene_maletin":"1 si la imagen contiene un maletín.","contiene_portatil":"1 si contiene un portátil.","contiene_persona":"1 si aparece una persona (solo su caja; clase auxiliar para evaluar presencia del propietario).","consentimiento_ref":"Referencia del consentimiento de los participantes.","rostro_identificable":"Siempre 0: no se admiten rostros identificables.","capturada_en":"Fecha de captura."}),
"evaluacion_modelo": ("Resultados de la evaluación del modelo.", "RNF-03, RNF-01", {
  "id":"Identificador.","modelo_version":"Versión del modelo evaluado.","conjunto":"validacion o prueba.","map50":"mAP@0.5 (0 a 1).","recall":"Recall (0 a 1).","f1":"F1-Score (0 a 1).","fps":"Cuadros por segundo medidos.","latencia_media_s":"Latencia media de notificación en segundos.","evaluado_en":"Fecha de la evaluación.","observaciones":"Notas."}),
}
md = ["# Diccionario de datos\n", "Generado a partir de la estructura real de `deteccion_objetos.db`.\n"]
js = {}
for (t,) in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY rowid"):
    desc, req, cols = D[t]
    fks = {r[3]: f"{r[2]}({r[4]})" for r in con.execute(f"PRAGMA foreign_key_list({t})")}
    md.append(f"## {t}\n\n{desc} Requisitos: {req}.\n")
    md.append("| Columna | Tipo | Nulo | Clave | Defecto | Descripción |\n|---|---|---|---|---|---|")
    js[t] = {"descripcion": desc, "requisitos": req, "columnas": []}
    for cid,name,tipo,notnull,dflt,pk in con.execute(f"PRAGMA table_info({t})"):
        clave = "PK" if pk else (f"FK → {fks[name]}" if name in fks else "")
        fila = [name, tipo or "", "No" if notnull or pk else "Sí", clave, "" if dflt is None else dflt, cols.get(name,"")]
        md.append("| " + " | ".join(fila) + " |")
        js[t]["columnas"].append(dict(zip(["columna","tipo","nulo","clave","defecto","descripcion"], fila)))
    md.append("")
open(os.path.join(AQUI,"diccionario_datos.md"),"w",encoding="utf-8").write("\n".join(md))
json.dump(js, open(os.path.join(AQUI,"diccionario_datos.json"),"w",encoding="utf-8"), ensure_ascii=False, indent=1)
sin = [(t,c["columna"]) for t in js for c in js[t]["columnas"] if not c["descripcion"]]
print("columnas totales:", sum(len(v["columnas"]) for v in js.values()), "| sin descripción:", sin)
