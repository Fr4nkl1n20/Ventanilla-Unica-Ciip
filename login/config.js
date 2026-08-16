/* ══════════════════════════════════════════════════════════════════════
   ██  CONFIGURACIÓN — EL ÚNICO ARCHIVO QUE HAY QUE TOCAR  ██
   ══════════════════════════════════════════════════════════════════════

   Esta carpeta es el acceso POR SÍ SOLO: no depende de ninguna otra
   página. Entras y te dice que la sesión quedó abierta, con un botón
   para cerrarla.

   ─────────────────────────────────────────────────────────────────────
   DE DÓNDE SALEN LOS DOS VALORES
   ─────────────────────────────────────────────────────────────────────
   Panel de Supabase → Project Settings → API
       · Project URL        →  SUPABASE_URL
       · anon / public key  →  SUPABASE_ANON_KEY

   La clave "anon" es PÚBLICA y puede ir en el navegador: por sí sola no
   da acceso a los datos. Lo que de verdad protege son las políticas RLS.

   NUNCA pongas aquí la clave "service_role": esa sí lo abre todo.
   ══════════════════════════════════════════════════════════════════════ */

window.CIIP_CONFIG = {

  /* ---- rellena estos dos ---- */
  SUPABASE_URL:      'https://ugmpeldbasujuchdmzsc.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnbXBlbGRiYXN1anVjaGRtenNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4OTk3MjAsImV4cCI6MjEwMjQ3NTcyMH0.mzsSXWanfZ6AP1Ze-4Z8bL9yjlDsKrhj9K-0KOcGxEY',

  /* ---- a dónde ir después de entrar ----
     VACÍO a propósito: sin panel al que saltar, el acceso se queda en su
     propia pantalla de "sesión iniciada". Es lo que hace que esta carpeta
     funcione sola.

     Si algún día la conectas con un panel, pon aquí su ruta:
         RUTA_PANEL: './panel.html'
     y el acceso volverá a redirigir al entrar. */
  RUTA_PANEL:  '',
  RUTA_ACCESO: './acceso.html'

};
