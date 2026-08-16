/* ══════════════════════════════════════════════════════════════════════
   ██  CONFIGURACIÓN DEL PROYECTO — EL ÚNICO ARCHIVO QUE HAY QUE TOCAR  ██
   ══════════════════════════════════════════════════════════════════════

   Lo leen los dos archivos del proyecto:
       · acceso.html                        (el inicio de sesión)
       · ciip-ventanilla-unica-local.html   (el panel)

   Antes las claves estaban repetidas en los dos, y bastaba con cambiar
   una y olvidar la otra para que el panel se quedara SIN PROTECCIÓN
   en silencio. Ahora solo existen aquí.

   ─────────────────────────────────────────────────────────────────────
   DE DÓNDE SALEN LOS DOS VALORES
   ─────────────────────────────────────────────────────────────────────
   Panel de Supabase → Project Settings → API
       · Project URL        →  SUPABASE_URL
       · anon / public key  →  SUPABASE_ANON_KEY

   La clave "anon" es PÚBLICA y puede ir en el navegador: por sí sola no
   da acceso a los datos. Lo que de verdad protege son las políticas RLS
   que crea supabase-setup.sql.

   NUNCA pongas aquí la clave "service_role": esa sí lo abre todo.
   ══════════════════════════════════════════════════════════════════════ */

window.CIIP_CONFIG = {

  /* ---- rellena estos dos ---- */
  SUPABASE_URL:      'https://ugmpeldbasujuchdmzsc.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnbXBlbGRiYXN1anVjaGRtenNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4OTk3MjAsImV4cCI6MjEwMjQ3NTcyMH0.mzsSXWanfZ6AP1Ze-4Z8bL9yjlDsKrhj9K-0KOcGxEY',

  /* ---- rutas entre páginas: solo si renombras los archivos ---- */
  RUTA_PANEL:  './ciip-ventanilla-unica-local.html',
  RUTA_ACCESO: './acceso.html'

};
