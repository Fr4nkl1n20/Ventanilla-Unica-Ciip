// Candado antes de subir: bloquea `git push` si el verificador no aprobó el commit actual.
// El verificador escribe el SHA de HEAD en .git/verificado-ok cuando su veredicto es SUBIR.
// Si HEAD cambia después de la revisión (otro commit, amend), hay que revisar de nuevo.
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

let entrada = '';
process.stdin.on('data', (t) => (entrada += t));
process.stdin.on('end', () => {
  let datos = {};
  try { datos = JSON.parse(entrada || '{}'); } catch (e) { return; }
  const orden = String((datos.tool_input && datos.tool_input.command) || '');
  if (!/\bgit\b[^\n;|&]*\bpush\b/.test(orden)) return;

  const carpeta = datos.cwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const git = (...args) => execFileSync('git', args, { cwd: carpeta, encoding: 'utf8' }).trim();
  let head = '', marca = '';
  try {
    head = git('rev-parse', 'HEAD');
    const comun = path.resolve(carpeta, git('rev-parse', '--git-common-dir'));
    marca = fs.readFileSync(path.join(comun, 'verificado-ok'), 'utf8').trim().split(/\s+/)[0];
  } catch (e) { /* sin marca: se bloquea */ }

  if (head && marca === head) return;

  const motivo = 'Falta la revisión del verificador para el commit ' + (head ? head.slice(0, 7) : '(desconocido)') +
    '. Envía al agente verificador con solo el cambio pendiente (git log y git diff ciip/main..HEAD); ' +
    'si su veredicto es SUBIR, él deja el SHA en .git/verificado-ok y el push queda libre.';
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: motivo
    }
  }));
});
