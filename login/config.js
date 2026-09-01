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

  /* ---- rellena estos dos ----
     Proyecto "Ventanilla Unica - Produccion" (fbxdwryppfctuwlnjjqr),
     creado el 1 de septiembre de 2026, con las 21 tablas ya puestas. */
  SUPABASE_URL:      'https://fbxdwryppfctuwlnjjqr.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZieGR3cnlwcGZjdHV3bG5qanFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODY0MzcsImV4cCI6MjEwMzg2MjQzN30.3pu7IrjE5Lgu3J9csZUHyE_kY1DA-czgb5Z8G3_kfyw',

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
