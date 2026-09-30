/* ═══════════════════════════════════════════════════════════════════════
   LOS TEXTOS DE LOS AVISOS, EN LOS OCHO IDIOMAS
   ═══════════════════════════════════════════════════════════════════════
   Aparte del diccionario del panel a proposito, por lo mismo que pasos.js
   esta aparte: aquel es un objeto de una sola linea de 57.000 caracteres,
   y meterle textos de correo lo dejaria imposible de corregir a mano.

   Y porque un correo no se escribe como una pantalla. En el panel el
   contexto lo pone lo que hay alrededor; aqui la persona abre el correo
   tres dias despues, en el movil, entre otros cuarenta. Tiene que decir
   quien escribe, de que trata y que hacer, en ese orden y en dos lineas.

   ─────────────────────────────────────────────────────────────────────
   POR QUE HAY MENOS DE LOS QUE PARECE
   ─────────────────────────────────────────────────────────────────────
   Cuatro motivos por idioma y ni uno mas. Cada texto que se anade es un
   texto que hay que traducir seis veces y mantener seis veces, y un
   buzon que avisa de todo se ignora entero: entonces el aviso de
   'devuelto' -el unico que pide una accion- se pierde con los demas.

   El quinto, 'anuncio' (28-9-2026), es el otro que cuenta algo que
   cambia lo que hay que hacer: lo escribe el gestor cuando el SAPI
   devuelve una marca o alguien se opone al registro.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

/* Los ocho idiomas y los paises donde se hablan. Es COPIA de IDIOMA_PAIS
   del panel, y tiene que seguir siendolo: avisos/prueba-avisos.js lo lee
   del HTML y compara, asi que si alli se anade un pais y aqui no, la
   prueba se pone roja en vez de mandarle a alguien un correo en un idioma
   que no lee. */
const IDIOMA_PAIS = {
  es: 'AR BO CL CO CR CU DO EC ES GQ GT HN MX NI PA PE PR PY SV UY VE'.split(' '),
  pt: 'AO BR CV GW MZ PT ST TL'.split(' '),
  it: 'IT SM VA'.split(' '),
  ru: 'BY KG KZ RU'.split(' '),
  zh: 'CN HK MO TW'.split(' '),
  fr: 'BF BJ CD CG CI FR GA GN HT MC ML NE SN TG'.split(' '),
  ja: 'JP'.split(' '),
  en: ('AG AU BB BS BW BZ CA FJ GB GH GY IE IN JM KE LR MT MW NA NG NZ PG PH ' +
       'SG SL SZ TT TZ UG US ZA ZM ZW').split(' ')
};

/* {tramite} y {dato} se sustituyen. No hay mas variables a proposito: una
   plantilla con diez huecos es una plantilla que un dia sale con un
   "undefined" dentro delante de un inversionista. */
const TEXTOS = {
  es: {
    firma:  'Centro Internacional de Inversión Productiva',
    devuelto: {
      asunto: 'Tu solicitud necesita una corrección',
      cuerpo: 'Revisamos tu solicitud de {tramite} y hay algo que corregir antes de seguir.',
      pie:    'Entra en la Ventanilla Única, corrige lo que se indica y vuelve a enviarla.'
    },
    resuelto: {
      asunto: 'Tu trámite está resuelto',
      cuerpo: 'Tu solicitud de {tramite} quedó resuelta. El documento emitido ya está en tu bóveda.',
      pie:    'Puedes descargarlo cuando quieras desde la Ventanilla Única.'
    },
    ante_el_ente: {
      asunto: 'Tu solicitud ya está en el organismo',
      cuerpo: 'Presentamos tu solicitud de {tramite} ante el organismo que la resuelve.',
      pie:    'No tienes que hacer nada. Te escribimos en cuanto contesten.'
    },
    documento_vence: {
      asunto: 'Un documento tuyo está por vencer',
      cuerpo: 'Tu {dato} vence el {tramite}. Los organismos no aceptan documentos vencidos.',
      pie:    'Renuévalo y súbelo a tu bóveda antes de esa fecha.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'Hay una novedad en tu trámite',
      cuerpo: 'El CIIP tiene algo que contarte sobre tu solicitud:',
      pie:    'Entra en la Ventanilla Única para ver qué sigue.'
    }
  },
  en: {
    firma:  'International Centre for Productive Investment',
    devuelto: {
      asunto: 'Your application needs a correction',
      cuerpo: 'We reviewed your {tramite} application and something needs fixing before it can go on.',
      pie:    'Sign in to the One-Stop Window, fix what is flagged and send it again.'
    },
    resuelto: {
      asunto: 'Your procedure is complete',
      cuerpo: 'Your {tramite} application is complete. The issued document is already in your vault.',
      pie:    'You can download it any time from the One-Stop Window.'
    },
    ante_el_ente: {
      asunto: 'Your application is with the agency',
      cuerpo: 'We filed your {tramite} application with the agency that decides it.',
      pie:    'Nothing for you to do. We will write as soon as they answer.'
    },
    documento_vence: {
      asunto: 'A document of yours is about to expire',
      cuerpo: 'Your {dato} expires on {tramite}. Agencies do not accept expired documents.',
      pie:    'Renew it and upload it to your vault before that date.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'There is news about your application',
      cuerpo: 'CIIP has something to tell you about your application:',
      pie:    'Sign in to the One-Stop Window to see what comes next.'
    }
  },
  pt: {
    firma:  'Centro Internacional de Investimento Produtivo',
    devuelto: {
      asunto: 'O seu pedido precisa de uma correção',
      cuerpo: 'Revimos o seu pedido de {tramite} e há algo a corrigir antes de continuar.',
      pie:    'Entre no Balcão Único, corrija o que se indica e envie-o de novo.'
    },
    resuelto: {
      asunto: 'O seu trâmite está resolvido',
      cuerpo: 'O seu pedido de {tramite} ficou resolvido. O documento emitido já está no seu cofre.',
      pie:    'Pode descarregá-lo quando quiser no Balcão Único.'
    },
    ante_el_ente: {
      asunto: 'O seu pedido já está no organismo',
      cuerpo: 'Apresentámos o seu pedido de {tramite} ao organismo que o resolve.',
      pie:    'Não tem de fazer nada. Escrevemos-lhe assim que responderem.'
    },
    documento_vence: {
      asunto: 'Um documento seu está prestes a caducar',
      cuerpo: 'O seu {dato} caduca a {tramite}. Os organismos não aceitam documentos caducados.',
      pie:    'Renove-o e carregue-o no seu cofre antes dessa data.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'Há uma novidade no seu pedido',
      cuerpo: 'O CIIP tem algo a dizer-lhe sobre o seu pedido:',
      pie:    'Entre no Balcão Único para ver o que se segue.'
    }
  },
  it: {
    firma:  'Centro Internazionale per l’Investimento Produttivo',
    devuelto: {
      asunto: 'La tua domanda ha bisogno di una correzione',
      cuerpo: 'Abbiamo esaminato la tua domanda di {tramite} e c’è qualcosa da correggere prima di proseguire.',
      pie:    'Entra nello Sportello Unico, correggi quanto indicato e inviala di nuovo.'
    },
    resuelto: {
      asunto: 'La tua pratica è conclusa',
      cuerpo: 'La tua domanda di {tramite} è conclusa. Il documento rilasciato è già nel tuo archivio.',
      pie:    'Puoi scaricarlo quando vuoi dallo Sportello Unico.'
    },
    ante_el_ente: {
      asunto: 'La tua domanda è presso l’ente',
      cuerpo: 'Abbiamo presentato la tua domanda di {tramite} all’ente che la decide.',
      pie:    'Non devi fare nulla. Ti scriviamo appena rispondono.'
    },
    documento_vence: {
      asunto: 'Un tuo documento sta per scadere',
      cuerpo: 'Il tuo {dato} scade il {tramite}. Gli enti non accettano documenti scaduti.',
      pie:    'Rinnovalo e caricalo nel tuo archivio prima di quella data.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'C’è una novità sulla tua pratica',
      cuerpo: 'Il CIIP ha qualcosa da dirti sulla tua richiesta:',
      pie:    'Accedi allo Sportello Unico per vedere cosa segue.'
    }
  },
  zh: {
    firma:  '国际生产性投资中心',
    devuelto: {
      asunto: '您的申请需要修改',
      cuerpo: '我们已审阅您的{tramite}申请，有一处需要修改后才能继续。',
      pie:    '请登录一站式窗口，按提示修改后重新提交。'
    },
    resuelto: {
      asunto: '您的业务已办结',
      cuerpo: '您的{tramite}申请已办结。签发的文件已存入您的文件库。',
      pie:    '您可以随时在一站式窗口下载。'
    },
    ante_el_ente: {
      asunto: '您的申请已递交主管机关',
      cuerpo: '我们已将您的{tramite}申请递交给主管机关。',
      pie:    '您无需操作。对方答复后我们会立即通知您。'
    },
    documento_vence: {
      asunto: '您有一份文件即将到期',
      cuerpo: '您的{dato}将于{tramite}到期。主管机关不接受过期文件。',
      pie:    '请在该日期前更新并上传至您的文件库。'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: '您的申请有新进展',
      cuerpo: 'CIIP 有关于您申请的消息：',
      pie:    '请登录一站式窗口查看后续步骤。'
    }
  },
  ru: {
    firma:  'Международный центр производственных инвестиций',
    devuelto: {
      asunto: 'Ваша заявка требует исправления',
      cuerpo: 'Мы рассмотрели вашу заявку «{tramite}»: нужно кое-что исправить, прежде чем продолжить.',
      pie:    'Войдите в Единое окно, исправьте указанное и отправьте заявку снова.'
    },
    resuelto: {
      asunto: 'Ваша услуга оказана',
      cuerpo: 'Ваша заявка «{tramite}» выполнена. Выданный документ уже в вашем хранилище.',
      pie:    'Вы можете скачать его в любой момент в Едином окне.'
    },
    ante_el_ente: {
      asunto: 'Ваша заявка передана в орган',
      cuerpo: 'Мы подали вашу заявку «{tramite}» в орган, который её рассматривает.',
      pie:    'От вас ничего не требуется. Мы напишем, как только они ответят.'
    },
    documento_vence: {
      asunto: 'Срок действия вашего документа истекает',
      cuerpo: 'Ваш документ «{dato}» истекает {tramite}. Органы не принимают просроченные документы.',
      pie:    'Обновите его и загрузите в хранилище до этой даты.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'Новости по вашей заявке',
      cuerpo: 'CIIP сообщает о вашей заявке:',
      pie:    'Войдите в Единое окно, чтобы узнать, что дальше.'
    }
  },
  fr: {
    firma:  'Centre international d’investissement productif',
    devuelto: {
      asunto: 'Votre demande doit être corrigée',
      cuerpo: 'Nous avons examiné votre demande de {tramite} et un point doit être corrigé avant qu’elle puisse avancer.',
      pie:    'Connectez-vous au Guichet unique, corrigez ce qui est signalé et renvoyez-la.'
    },
    resuelto: {
      asunto: 'Votre démarche est terminée',
      cuerpo: 'Votre demande de {tramite} est terminée. Le document délivré se trouve déjà dans votre coffre-fort.',
      pie:    'Vous pouvez le télécharger à tout moment depuis le Guichet unique.'
    },
    ante_el_ente: {
      asunto: 'Votre demande est entre les mains de l’organisme',
      cuerpo: 'Nous avons déposé votre demande de {tramite} auprès de l’organisme qui en décide.',
      pie:    'Vous n’avez rien à faire. Nous vous écrirons dès qu’il aura répondu.'
    },
    documento_vence: {
      asunto: 'Un de vos documents va bientôt expirer',
      cuerpo: 'Votre {dato} expire le {tramite}. Les organismes n’acceptent pas les documents expirés.',
      pie:    'Renouvelez-le et téléversez-le dans votre coffre-fort avant cette date.'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: 'Du nouveau concernant votre demande',
      cuerpo: 'Le CIIP a une information à vous communiquer au sujet de votre demande :',
      pie:    'Connectez-vous au Guichet unique pour connaître la suite.'
    }
  },
  ja: {
    firma:  '国際生産投資センター（CIIP）',
    devuelto: {
      asunto: '申請に修正が必要です',
      cuerpo: '{tramite}の申請を確認したところ、手続きを進める前に修正が必要な点があります。',
      pie:    'ワンストップ窓口にログインし、指摘された箇所を修正して再送信してください。'
    },
    resuelto: {
      asunto: '手続きが完了しました',
      cuerpo: '{tramite}の申請が完了しました。発行された書類はすでに保管庫にあります。',
      pie:    'ワンストップ窓口からいつでもダウンロードできます。'
    },
    ante_el_ente: {
      asunto: '申請を機関に提出しました',
      cuerpo: '{tramite}の申請を、審査を行う機関に提出しました。',
      pie:    'お客様による対応は不要です。回答があり次第ご連絡します。'
    },
    documento_vence: {
      asunto: 'お手持ちの書類の有効期限が近づいています',
      cuerpo: '{dato}の有効期限は{tramite}です。各機関は期限切れの書類を受け付けません。',
      pie:    '期限までに更新し、保管庫にアップロードしてください。'
    },
    /* El anuncio que escribe el gestor -la contestacion de una marca-.
       Va entrecomillado debajo del cuerpo, como la nota de una devuelta. */
    anuncio: {
      asunto: '申請に関するお知らせがあります',
      cuerpo: 'CIIPから申請についてお知らせがあります：',
      pie:    'ワンストップ窓口にログインして、次の手順をご確認ください。'
    }
  }
};

module.exports = { TEXTOS, IDIOMA_PAIS };
