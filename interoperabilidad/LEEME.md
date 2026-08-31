# La capa de interoperabilidad, adelantada

Esta carpeta es la capa 3 de la arquitectura empezada **antes de que ningún
organismo conteste**. No conecta con nadie: conecta con un simulador que cumple
el contrato que le vamos a proponer al SENIAT.

Parece un rodeo y no lo es. Lo caro de un conector no es mandar datos —eso son
veinte líneas—, es **decidir qué hacer con cada respuesta**, y eso se puede
acordar, escribir y probar hoy. Cuando el ente conteste, lo que cambia es la
dirección y las credenciales.

Es lo mismo que ya se hace un piso más arriba: el panel entero se prueba contra
`pruebas/supabase-mentira.js` sin tocar la base de verdad.

---

## Probarlo

Doble clic en **`PROBAR-CONECTOR.bat`**, o desde la consola:

```
node interoperabilidad/prueba.js
```

Salen 28 pruebas con `PASA` o `FALLA`. No hace falta instalar nada más que
Node, no se toca ninguna red y no se habla con ningún organismo: el simulador
se levanta y se apaga solo, en esta máquina.

Para verlo funcionando por tu cuenta:

```
node interoperabilidad/simulador.js
```

y luego, contra `http://127.0.0.1:8710`, con la cabecera `X-Simular` para
forzar cada fallo.

---

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `contrato-rif-empresa.md` | **Lo importante.** Qué se manda, qué vuelve y qué significa cada respuesta. Es lo que se lleva a la reunión con el SENIAT |
| `simulador.js` | Un SENIAT de mentira que cumple ese contrato, incluidos sus fallos |
| `conector-rif.js` | El conector. Traduce un trámite de la VUI a expediente, y la respuesta a un estado del panel |
| `prueba.js` | Comprueba que cada respuesta lleva al estado que debe |
| `trabajador.js` | **Quien vacía la cola.** Coge la acción que devuelve el conector y la ejecuta: mueve el trámite, guarda el número del ente, reprograma o alerta |
| `prueba-trabajador.js` | 44 pruebas de eso, con un depósito de mentira que apunta todo lo que se le pide |

---

## Lo único que hay que entender

El conector **no decide nada más que una cosa**: a qué estado pasa el trámite.
No escribe en la base, no manda correos, no reintenta por su cuenta. Devuelve
una acción y quien lo llame la ejecuta. Por eso se prueba entero sin base de
datos, y por eso se muda a un servicio de NestJS sin tocarle una línea.

Son seis acciones, y las seis salen de la tabla del contrato:

| Acción | El trámite pasa a |
|---|---|
| `presentado` | `ante_el_ente` |
| `devolver` | `devuelto`, con la nota del organismo |
| `resuelto` | `resuelto`, y el documento emitido entra en la bóveda |
| `esperar` | no se toca; se vuelve a preguntar |
| `reintentar` | no se toca; se manda otra vez con la misma llave |
| `alertar` | no se toca; **es problema del CIIP**, no del inversionista |

### La distinción que sostiene todo

*No llegó* y *llegó pero lo rechazan* se parecen desde fuera y piden lo
contrario. Confundirlas es presentar cuatro veces el mismo expediente, o dejar
al inversionista esperando algo que hace semanas que está rechazado.

Por eso el simulador sabe fingir un organismo **mudo** —que ni contesta ni
cierra la conexión—: es el caso peor y el que no se puede ensayar contra un
ente de verdad.

### Por qué el `id` del trámite es la llave de idempotencia

Si la red se cae después de que ellos reciban pero antes de que nos contesten,
no sabemos si entró. Con la misma `Idempotency-Key`, reintentar es seguro: el
ente devuelve el mismo número de expediente en vez de abrir uno nuevo. Sin
eso, la única opción prudente sería no reintentar nunca, y entonces cada corte
de red deja un trámite atascado a mano.

---

## Lo que esto NO es

- **No es la API del SENIAT.** Ellos no han dicho todavía qué exponen, ni si
  exponen algo. El contrato es lo que necesitamos, escrito para preguntárselo.
- **No conecta con nada.** No hay backend, no hay servidor con IP fija, no hay
  credenciales. Nada de esto sale de tu máquina.
- **Ya no espera a que alguien lo llame.** `trabajador.js` ejecuta la acción, y
  `supabase-cola.sql` guarda qué hay que hacer y cuándo. La cola la llena un
  trigger, no la aplicación: un trámite que llega a `en_revision` deja ahí su
  `presentar` sin que nadie se acuerde de encolarlo.

  Entra en `en_revision` y no en `enviado` porque lo manda la escalera de
  estados, que sólo deja pasar a `ante_el_ente` desde ahí. O sea: **lo que se
  manda a un organismo lo ha visto antes una persona.** No es una limitación
  que haya que rodear, es la política correcta escrita en un sitio.

- **Sigue sin hablar con nadie.** El trabajador presenta contra el simulador,
  no contra el SENIAT. Lo de abajo no ha cambiado.

## Las tres piezas, y por qué son tres

| | Sabe |
|---|---|
| `supabase-cola.sql` | **qué** hay que hacer y **cuándo** se puede volver a intentar |
| `conector-rif.js` | **qué significa** lo que contestó el organismo |
| `trabajador.js` | **qué hacer** con esa decisión |

Cada una se prueba sola y ninguna sabe cómo funcionan las otras dos. El
conector se prueba sin base de datos; el trabajador, sin base de datos y sin
red de verdad; la cola, en un Postgres de usar y tirar con `PROBAR-SQL.bat`.

## Lo que falta para que sea real

1. **Convenio con el SENIAT** y respuesta a las seis preguntas del final del
   contrato. Lo primero y lo más lento, y no depende de nosotros.
2. **Un backend con IP fija** donde vivir. No sirve serverless: los organismos
   autorizan direcciones.
3. **Credenciales** que ellos emitan para esa dirección.
4. Si su API resulta distinta a esta propuesta, **un traductor** entre su forma
   y ésta. El conector no se toca.
