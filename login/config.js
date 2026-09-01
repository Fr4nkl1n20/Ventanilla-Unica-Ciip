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
  SUPABASE_URL:      'https://ifhdzxetixhrzqixcfbe.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaGR6eGV0aXhocnpxaXhjZmJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5OTI3OTUsImV4cCI6MjEwMjU2ODc5NX0.7e3QDtDKAYGYgIF-ZfMZJk9OXEYEo0_hpgR1BG_iT4Y',

  /* ---- a dónde ir después de entrar ----
     VACÍO a propósito: sin panel al que saltar, el acceso se queda en su
     propia pantalla de "sesión iniciada". Es lo que hace que esta carpeta
     funcione sola.

     Si algún día la conectas con un panel, pon aquí su ruta:
         RUTA_PANEL: './panel.html'
     y el acceso volverá a redirigir al entrar. */
  RUTA_PANEL:  '../ciip-ventanilla-unica-local.html',
  RUTA_ACCESO: './acceso.html'

};
